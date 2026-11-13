import Foundation

@testable import FociCore

struct FakeError: Error, CustomStringConvertible {
  var description: String { "boom" }
}

@MainActor
final class FakeSystem: System {
  var running: Set<String>
  var refusesToQuit: Set<String> = []
  var failing: Set<String> = []
  var dock: [String: Any] = ["persistent-apps": ["current"], "tilesize": 48]
  var obsidianConfig = Data(
    #"{"vaults":{"w":{"path":"/Users/k/Work","open":true},"p":{"path":"/Users/k/Home"}}}"#.utf8)
  private(set) var log: [String] = []

  init(running: Set<String> = []) {
    self.running = running
  }

  private func record(_ call: String) throws {
    log.append(call)
    if failing.contains(where: call.hasPrefix) { throw FakeError() }
  }

  func isRunning(_ bundleID: String) -> Bool { running.contains(bundleID) }
  func displayName(of bundleID: String) -> String { bundleID }

  func quit(_ bundleID: String) async -> Bool {
    log.append("quit \(bundleID)")
    if refusesToQuit.contains(bundleID) { return false }
    running.remove(bundleID)
    return true
  }

  func setWallpaper(_ path: String) throws { try record("wallpaper \(path)") }

  func readDockPrefs() throws -> [String: Any] {
    try record("readDock")
    return dock
  }

  func writeDockPrefs(_ prefs: [String: Any]) throws {
    try record("writeDock")
    dock = prefs
  }

  func readObsidianConfig() throws -> Data {
    try record("readObsidian")
    return obsidianConfig
  }

  func writeObsidianConfig(_ data: Data) throws {
    try record("writeObsidian")
    obsidianConfig = data
  }

  func open(_ url: URL) throws {
    try record("open \(url.absoluteString)")
    if url.scheme == "obsidian" { running.insert(ObsidianVaults.bundleID) }
  }

  /// Calls that change something, in order: the part of the log a switch is judged by.
  var effects: [String] { log.filter { !$0.hasPrefix("read") } }
}

@MainActor
final class MemoryStore: Store {
  var state: State
  var docks: [String: Data] = [:]

  init(state: State = State()) {
    self.state = state
  }

  func loadState() throws -> State { state }
  func saveState(_ state: State) throws { self.state = state }
  func loadDock(for profile: String) throws -> Data? { docks[profile] }
  func saveDock(_ data: Data, for profile: String) throws { docks[profile] = data }
}
