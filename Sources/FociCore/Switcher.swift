import Foundation

/// Everything a switch does to the machine. The real one is `MacSystem`; tests use a fake.
@MainActor
public protocol System {
  func isRunning(_ bundleID: String) -> Bool
  func displayName(of bundleID: String) -> String
  /// Asks the app to quit and waits; false if it is still running at the deadline.
  func quit(_ bundleID: String) async -> Bool
  func setWallpaper(_ path: String) throws
  func readDockPrefs() throws -> [String: Any]
  func writeDockPrefs(_ prefs: [String: Any]) throws
  func readObsidianConfig() throws -> Data
  func writeObsidianConfig(_ data: Data) throws
  func open(_ url: URL) throws
}

@MainActor
public protocol Store {
  func loadState() throws -> State
  func saveState(_ state: State) throws
  func loadDock(for profile: String) throws -> Data?
  func saveDock(_ data: Data, for profile: String) throws
}

public enum Source: String, Sendable {
  case manual, focus
}

public struct SwitchRequest: Equatable, Sendable {
  public var target: String
  public var source: Source
  public var force: Bool

  public init(target: String, source: Source = .manual, force: Bool = false) {
    self.target = target
    self.source = source
    self.force = force
  }
}

public struct SwitchReport: Equatable, Sendable {
  public enum Outcome: Equatable, Sendable {
    case switched
    case skipped(String)
  }

  public var outcome: Outcome
  public var problems: [String] = []
}

@MainActor
public struct Switcher {
  let config: Config
  let system: System
  let store: Store
  let home: String

  public init(config: Config, system: System, store: Store, home: String) {
    self.config = config
    self.system = system
    self.store = store
    self.home = home
  }

  /// Each step's failure is recorded and the switch carries on, so one stubborn app never
  /// leaves the desktop half-switched.
  public func run(_ request: SwitchRequest) async throws -> SwitchReport {
    let target = request.target
    let incoming = try config.profile(target)
    var state = try store.loadState()

    if request.source == .focus && !state.followFocus {
      return SwitchReport(outcome: .skipped("Follow Focus is off"))
    }
    if state.current == target && !request.force {
      return SwitchReport(outcome: .skipped("already in \(target)"))
    }

    var problems: [String] = []
    func attempt(_ step: String, _ body: () async throws -> Void) async {
      do { try await body() } catch { problems.append("\(step): \(error)") }
    }

    let outgoing = state.current.flatMap { config.profiles[$0] }
    let appsToQuit = try config.appsToQuit(switchingTo: target)
    let obsidian = ObsidianVaults.bundleID
    let vault = incoming.obsidianVault.map { normalizedPath($0, home: home) }
    let changesVault =
      vault != nil && vault != outgoing?.obsidianVault.map { normalizedPath($0, home: home) }
    let obsidianWasRunning = system.isRunning(obsidian)

    if let current = state.current {
      await attempt("Saving the \(current) Dock") {
        let snapshot = DockLayout.snapshot(of: try system.readDockPrefs())
        try store.saveDock(DockLayout.encode(snapshot), for: current)
      }
    }

    let toQuit = (appsToQuit + (changesVault ? [obsidian] : [])).uniqued()
    var quitFailed: Set<String> = []
    for app in toQuit where system.isRunning(app) {
      if await !system.quit(app) {
        quitFailed.insert(app)
        problems.append("\(system.displayName(of: app)) didn't quit")
      }
    }

    if let wallpaper = incoming.wallpaper {
      await attempt("Wallpaper") { try system.setWallpaper(expandingTilde(wallpaper, home: home)) }
    }

    await attempt("Dock") {
      guard let saved = try store.loadDock(for: target) else { return }
      try system.writeDockPrefs(
        DockLayout.applying(try DockLayout.decode(saved), to: try system.readDockPrefs()))
    }

    // Obsidian rewrites obsidian.json when it quits, so edit it only once Obsidian is gone.
    if changesVault, let vault, !quitFailed.contains(obsidian) {
      await attempt("Obsidian") {
        try system.writeObsidianConfig(
          ObsidianVaults.openingOnly(vaultAt: vault, in: try system.readObsidianConfig()))
        if obsidianWasRunning && !appsToQuit.contains(obsidian) {
          try system.open(ObsidianVaults.openURL(forVaultAt: vault))
        }
      }
    }

    state.current = target
    try store.saveState(state)
    return SwitchReport(outcome: .switched, problems: problems)
  }
}
