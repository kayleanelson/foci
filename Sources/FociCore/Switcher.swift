import Foundation

/// Everything a switch does to the machine. The real one is `MacSystem`; tests use a fake.
@MainActor
public protocol System: Sendable {
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
public protocol Store: Sendable {
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

    // The visible changes come first: quitting takes as long as the slowest app.
    if let current = state.current {
      await attempt("Saving the \(current) Dock") { try saveDock(as: current) }
    }
    if let wallpaper = incoming.wallpaper {
      await attempt("Wallpaper") { try system.setWallpaper(expandingTilde(wallpaper, home: home)) }
    }
    await attempt("Dock") { try restoreDock(for: target, removing: appsToQuit) }
    state.current = target
    await attempt("Saving state") { try store.saveState(state) }

    let newVault = changesVault ? vault : nil
    let reopenObsidian = obsidianWasRunning && !appsToQuit.contains(obsidian)
    let quitting = (appsToQuit + (newVault != nil ? [obsidian] : [])).uniqued()
      .filter(system.isRunning)
    if let newVault, !quitting.contains(obsidian) {
      problems += moveObsidian(to: newVault, reopen: false)
    }

    problems += await quit(quitting, movingObsidianTo: newVault, reopen: reopenObsidian)
    return SwitchReport(outcome: .switched, problems: problems)
  }

  /// Side by side, so an app slow to quit holds up no other, and Obsidian moves to the new
  /// vault as soon as it has gone.
  private func quit(_ apps: [String], movingObsidianTo vault: String?, reopen: Bool) async
    -> [String]
  {
    // Every quit starts before any is awaited. (A task group here trips the compiler's
    // region-isolation checker in Swift 6.4.)
    let quits = apps.map { app in
      Task { @MainActor in
        guard await system.quit(app) else { return ["\(system.displayName(of: app)) didn't quit"] }
        guard app == ObsidianVaults.bundleID, let vault else { return [String]() }
        return moveObsidian(to: vault, reopen: reopen)
      }
    }
    var problems: [String] = []
    for quit in quits { problems += await quit.value }
    return problems
  }

  /// Obsidian rewrites obsidian.json when it quits, so this runs only once Obsidian is gone.
  private func moveObsidian(to vault: String, reopen: Bool) -> [String] {
    do {
      try system.writeObsidianConfig(
        ObsidianVaults.openingOnly(vaultAt: vault, in: try system.readObsidianConfig()))
      if reopen { try system.open(ObsidianVaults.openURL(forVaultAt: vault)) }
      return []
    } catch {
      return ["Obsidian: \(error)"]
    }
  }

  private func saveDock(as profile: String) throws {
    let snapshot = DockLayout.snapshot(of: try system.readDockPrefs())
    try store.saveDock(DockLayout.encode(snapshot), for: profile)
  }

  /// Stripping runs on saved Docks too, so a Dock saved before an app was added to another
  /// profile can't bring that app back.
  private func restoreDock(for profile: String, removing apps: [String]) throws {
    let current = try system.readDockPrefs()
    var dock = current
    if let saved = try store.loadDock(for: profile) {
      dock = DockLayout.applying(try DockLayout.decode(saved), to: dock)
    }
    dock = DockLayout.removingApps(Set(apps), from: dock)
    if !NSDictionary(dictionary: dock).isEqual(to: current) { try system.writeDockPrefs(dock) }
  }
}
