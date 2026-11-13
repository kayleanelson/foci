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
        "quit slack", "quit md.obsidian", "wallpaper /Users/k/home.heic", "writeDock",
        "writeObsidian", "open obsidian://open?path=/Users/k/Home",
        "launch messages", "launch shared",
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

  @Test func profileWithNoSavedDockKeepsTheCurrentDock() async throws {
    let system = FakeSystem()
    _ = try await run(SwitchRequest(target: "personal"), system: system, store: MemoryStore())
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
    system.failing = ["wallpaper", "writeDock", "launch messages"]
    let store = MemoryStore(state: State(current: "work"))
    store.docks["personal"] = try DockLayout.encode(["persistent-apps": []])

    let report = try await run(SwitchRequest(target: "personal"), system: system, store: store)

    #expect(report.outcome == .switched)
    #expect(report.problems == ["Wallpaper: boom", "Dock: boom", "Opening messages: boom"])
    #expect(system.effects.contains("launch shared"))
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
