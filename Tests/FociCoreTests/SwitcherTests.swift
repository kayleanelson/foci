import Foundation
import Testing

@testable import FociCore

@MainActor
@Suite struct SwitcherTests {
  let config = Config(profiles: [
    "work": Profile(
      wallpaper: "~/work.heic", obsidianVault: "~/Work", apps: ["slack", "shared"]),
    "personal": Profile(
      wallpaper: "~/home.heic", obsidianVault: "~/Home/", apps: ["messages", "shared"]),
  ])

  func run(
    _ request: SwitchRequest, system: FakeSystem, store: MemoryStore
  ) async throws -> SwitchReport {
    try await Switcher(config: config, system: system, store: store, home: "/Users/k")
      .run(request)
  }

  func dockApp(_ id: String) -> [String: Any] {
    ["tile-data": ["bundle-identifier": id]]
  }

  func dockApps(_ prefs: [String: Any]) -> [String] {
    (prefs["persistent-apps"] as! [[String: Any]]).compactMap {
      ($0["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
    }
  }

  func openVaults(_ data: Data) throws -> Set<String> {
    let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let vaults = root["vaults"] as! [String: [String: Any]]
    return Set(vaults.filter { $0.value["open"] as? Bool == true }.keys)
  }

  @Test func fullSwitchRunsStepsInOrder() async throws {
    let system = FakeSystem(running: ["slack", "shared", ObsidianVaults.bundleID])
    let store = MemoryStore(state: State(current: "work"))
    store.docks["personal"] = try DockLayout.encode(["persistent-apps": ["saved"]])

    let report = try await run(SwitchRequest(target: "personal"), system: system, store: store)

    #expect(report == SwitchReport(outcome: .switched))
    #expect(
      system.effects == [
        "wallpaper /Users/k/home.heic", "writeDock", "quit slack", "quit md.obsidian",
        "writeObsidian", "open obsidian://open?path=/Users/k/Home",
      ])
    #expect(store.state.current == "personal")
    #expect(try openVaults(system.obsidianConfig) == ["p"])
  }

  @Test func leavingAProfileSavesItsDockAndRestoresTheIncomingOne() async throws {
    let system = FakeSystem()
    let store = MemoryStore(state: State(current: "work"))
    store.docks["personal"] = try DockLayout.encode(["persistent-apps": ["saved"]])

    _ = try await run(SwitchRequest(target: "personal"), system: system, store: store)

    let savedWork = try DockLayout.decode(store.docks["work"]!)
    #expect(savedWork["persistent-apps"] as? [String] == ["current"])
    #expect(savedWork["tilesize"] == nil)
    #expect(system.dock["persistent-apps"] as? [String] == ["saved"])
    #expect(system.dock["tilesize"] as? Int == 48)
  }

  @Test func profileWithNoSavedDockKeepsTheCurrentDockApartFromOtherProfilesApps() async throws {
    let system = FakeSystem()
    system.dock = ["persistent-apps": [dockApp("slack"), dockApp("shared"), dockApp("finder")]]
    _ = try await run(
      SwitchRequest(target: "personal"), system: system,
      store: MemoryStore(state: State(current: "work")))
    #expect(dockApps(system.dock) == ["shared", "finder"])
  }

  @Test(arguments: [nil, ["slack", "messages", "shared"]] as [[String]?])
  func otherProfilesOnlyAppsNeverSurviveIntoTheDock(saved: [String]?) async throws {
    let system = FakeSystem()
    system.dock = ["persistent-apps": [dockApp("slack"), dockApp("messages")]]
    let store = MemoryStore(state: State(current: "work"))
    if let saved {
      store.docks["personal"] = try DockLayout.encode(["persistent-apps": saved.map(dockApp)])
    }
    _ = try await run(SwitchRequest(target: "personal"), system: system, store: store)
    let otherOnly = Set(config.profiles["work"]!.apps).subtracting(
      config.profiles["personal"]!.apps)
    #expect(Set(dockApps(system.dock)).isDisjoint(with: otherOnly))
  }

  @Test func dockWithNothingToChangeIsNotRewritten() async throws {
    let system = FakeSystem()
    system.dock = ["persistent-apps": [dockApp("finder")]]
    _ = try await run(
      SwitchRequest(target: "personal"), system: system,
      store: MemoryStore(state: State(current: "work")))
    #expect(!system.effects.contains("writeDock"))
  }

  @Test func focusRequestDoesNothingWhileFollowFocusIsOff() async throws {
    let system = FakeSystem(running: ["slack"])
    let store = MemoryStore(state: State(current: "work", followFocus: false))

    let report = try await run(
      SwitchRequest(target: "personal", source: .focus, force: true), system: system, store: store)

    #expect(report.outcome == .skipped("Follow Focus is off"))
    #expect(system.log.isEmpty)
    #expect(store.state.current == "work")
  }

  @Test func focusRequestSwitchesWhenFollowFocusIsOn() async throws {
    let store = MemoryStore(state: State(current: "work", followFocus: true))
    let report = try await run(
      SwitchRequest(target: "personal", source: .focus), system: FakeSystem(), store: store)
    #expect(report.outcome == .switched)
  }

  @Test func switchingToTheCurrentProfileDoesNothingUnlessForced() async throws {
    let system = FakeSystem()
    let store = MemoryStore(state: State(current: "work"))

    let report = try await run(SwitchRequest(target: "work"), system: system, store: store)
    #expect(report.outcome == .skipped("already in work"))
    #expect(system.log.isEmpty)

    let forced = try await run(
      SwitchRequest(target: "work", force: true), system: system, store: store)
    #expect(forced.outcome == .switched)
  }

  @Test func oneFailingStepDoesNotStopTheRest() async throws {
    let system = FakeSystem(running: ["slack"])
    system.failing = ["wallpaper", "writeDock", "writeObsidian"]
    let store = MemoryStore(state: State(current: "work"))
    store.docks["personal"] = try DockLayout.encode(["persistent-apps": []])

    let report = try await run(SwitchRequest(target: "personal"), system: system, store: store)

    #expect(report.outcome == .switched)
    #expect(report.problems == ["Wallpaper: boom", "Dock: boom", "Obsidian: boom"])
    #expect(store.state.current == "personal")
  }

  @Test func obsidianThatRefusesToQuitKeepsItsConfig() async throws {
    let system = FakeSystem(running: [ObsidianVaults.bundleID])
    system.refusesToQuit = [ObsidianVaults.bundleID]
    let store = MemoryStore(state: State(current: "work"))

    let report = try await run(SwitchRequest(target: "personal"), system: system, store: store)

    #expect(report.problems == ["md.obsidian didn't quit"])
    #expect(!system.effects.contains("writeObsidian"))
  }

  @Test func obsidianNotRunningGetsTheVaultSetButIsNotOpened() async throws {
    let system = FakeSystem()
    _ = try await run(
      SwitchRequest(target: "personal"), system: system,
      store: MemoryStore(state: State(current: "work")))
    #expect(system.effects.contains("writeObsidian"))
    #expect(!system.effects.contains { $0.hasPrefix("open ") })
    #expect(try openVaults(system.obsidianConfig) == ["p"])
  }

  @Test func sameVaultInBothProfilesLeavesObsidianAlone() async throws {
    let shared = Config(profiles: [
      "work": Profile(obsidianVault: "~/Notes"), "personal": Profile(obsidianVault: "~/Notes/"),
    ])
    let system = FakeSystem(running: [ObsidianVaults.bundleID])
    _ = try await Switcher(
      config: shared, system: system, store: MemoryStore(state: State(current: "work")),
      home: "/Users/k"
    ).run(SwitchRequest(target: "personal"))
    #expect(!system.log.contains { $0.contains("bsidian") })
  }

  @Test func appsThatAreNotRunningAreNotAskedToQuit() async throws {
    let system = FakeSystem()
    _ = try await run(
      SwitchRequest(target: "personal"), system: system,
      store: MemoryStore(state: State(current: "work")))
    #expect(!system.log.contains { $0.hasPrefix("quit") })
  }

  nonisolated static let runningSets: [Set<String>] = [
    [], ["slack"], ["messages", "shared"], [ObsidianVaults.bundleID],
    ["slack", "messages", "shared", "other", ObsidianVaults.bundleID],
  ]

  @Test(arguments: runningSets)
  func aSwitchNeverStartsAnAppThatWasNotRunning(running: Set<String>) async throws {
    for (from, to) in [("work", "personal"), ("personal", "work"), (nil, "work")] {
      let system = FakeSystem(running: running)
      _ = try await run(
        SwitchRequest(target: to), system: system, store: MemoryStore(state: State(current: from)))
      #expect(system.running.isSubset(of: running))
    }
  }

  @Test func wallpaperAndDockChangeBeforeAnyAppIsAskedToQuit() async throws {
    let system = FakeSystem(running: ["slack", ObsidianVaults.bundleID])
    let store = MemoryStore(state: State(current: "work"))
    store.docks["personal"] = try DockLayout.encode(["persistent-apps": ["saved"]])
    _ = try await run(SwitchRequest(target: "personal"), system: system, store: store)
    let firstQuit = system.effects.firstIndex { $0.hasPrefix("quit") }!
    #expect(system.effects.firstIndex { $0.hasPrefix("wallpaper") }! < firstQuit)
    #expect(system.effects.firstIndex(of: "writeDock")! < firstQuit)
  }

  @Test func appsQuitSideBySideAndASlowOneHoldsUpNoOther() async throws {
    let system = FakeSystem(running: ["slack", "outlook", ObsidianVaults.bundleID])
    system.quitDelays = ["slack": .milliseconds(100)]
    let busier = Config(profiles: [
      "work": Profile(obsidianVault: "~/Work", apps: ["slack", "outlook"]),
      "personal": Profile(obsidianVault: "~/Home"),
    ])
    _ = try await Switcher(
      config: busier, system: system, store: MemoryStore(state: State(current: "work")),
      home: "/Users/k"
    ).run(SwitchRequest(target: "personal"))

    let log = system.log
    let slackDone = log.firstIndex(of: "quitted slack")!
    #expect(log.firstIndex(of: "quit outlook")! < slackDone)
    #expect(log.firstIndex(of: "quit md.obsidian")! < slackDone)
    #expect(log.firstIndex(of: "writeObsidian")! < slackDone)
  }

  @Test func leavingAProfileSavesItsWallpaper() async throws {
    let system = FakeSystem()
    system.wallpaper = "/Users/k/picked-by-hand.png"
    let store = MemoryStore(state: State(current: "work"))
    _ = try await run(SwitchRequest(target: "personal"), system: system, store: store)
    #expect(store.state.wallpapers["work"] == "/Users/k/picked-by-hand.png")
  }

  @Test func savedWallpaperWinsOverTheConfigs() async throws {
    let system = FakeSystem()
    let store = MemoryStore(
      state: State(current: "work", wallpapers: ["personal": "/Users/k/saved.png"]))
    _ = try await run(SwitchRequest(target: "personal"), system: system, store: store)
    #expect(system.wallpaper == "/Users/k/saved.png")
  }

  @Test func returningRestoresTheWallpaperAProfileWasLeftWith() async throws {
    let system = FakeSystem()
    system.wallpaper = "/Users/k/work-by-hand.png"
    let store = MemoryStore(state: State(current: "work"))
    _ = try await run(SwitchRequest(target: "personal"), system: system, store: store)
    #expect(system.wallpaper == "/Users/k/home.heic")
    _ = try await run(SwitchRequest(target: "work"), system: system, store: store)
    #expect(system.wallpaper == "/Users/k/work-by-hand.png")
  }

  @Test func configWallpaperIsUsedWhenNoneIsSaved() async throws {
    let system = FakeSystem()
    _ = try await run(SwitchRequest(target: "work"), system: system, store: MemoryStore())
    #expect(system.wallpaper == "/Users/k/work.heic")
  }

  @Test func wallpaperIsSavedBeforeTheNewOneIsSet() async throws {
    let system = FakeSystem()
    let store = MemoryStore(state: State(current: "work"))
    _ = try await run(SwitchRequest(target: "personal"), system: system, store: store)
    #expect(store.state.wallpapers["work"] == "/Users/k/current.png")
    #expect(
      system.log.firstIndex(of: "readWallpaper")! < system.log.firstIndex {
        $0.hasPrefix("wallpaper")
      }!)
  }

  @Test func unreadableWallpaperDoesNotStopTheSwitch() async throws {
    let system = FakeSystem()
    system.failing = ["readWallpaper"]
    let store = MemoryStore(state: State(current: "work"))
    let report = try await run(SwitchRequest(target: "personal"), system: system, store: store)
    #expect(report.problems == ["Saving the work wallpaper: boom"])
    #expect(system.wallpaper == "/Users/k/home.heic")
    #expect(store.state.current == "personal")
  }

  @Test func unknownTargetChangesNothing() async throws {
    let system = FakeSystem()
    let store = MemoryStore(state: State(current: "work"))
    await #expect(throws: FociError.self) {
      try await run(SwitchRequest(target: "nope"), system: system, store: store)
    }
    #expect(system.log.isEmpty)
    #expect(store.state.current == "work")
  }
}
