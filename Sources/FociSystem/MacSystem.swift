import AppKit
import FociCore

@MainActor
public struct MacSystem: System {
  static let dockDomain = "com.apple.dock"

  let home: URL
  let quitTimeout: Duration

  public init(
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    quitTimeout: Duration = .seconds(20)
  ) {
    self.home = home
    self.quitTimeout = quitTimeout
  }

  var obsidianConfigURL: URL {
    home.appending(path: "Library/Application Support/obsidian/obsidian.json")
  }

  public func isRunning(_ bundleID: String) -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
  }

  public func displayName(of bundleID: String) -> String {
    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
      let name = app.localizedName
    {
      return name
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
      return bundleID
    }
    return FileManager.default.displayName(atPath: url.path)
  }

  /// Polls the process IDs rather than `isTerminated`, which only updates while a run loop is
  /// spinning; the CLI has none.
  public func quit(_ bundleID: String) async -> Bool {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    let pids = apps.map(\.processIdentifier)
    for app in apps { app.terminate() }
    let deadline = ContinuousClock.now + quitTimeout
    while pids.contains(where: { kill($0, 0) == 0 }) {
      if ContinuousClock.now >= deadline { return false }
      try? await Task.sleep(for: .milliseconds(200))
    }
    return true
  }

  public func currentWallpaper() throws -> String? {
    (NSScreen.main ?? NSScreen.screens.first).flatMap {
      NSWorkspace.shared.desktopImageURL(for: $0)?.path
    }
  }

  /// macOS only exposes the current Space of each display; other Spaces keep their wallpaper.
  public func setWallpaper(_ path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else {
      throw MacSystemError.fileNotFound(path)
    }
    let url = URL(fileURLWithPath: path)
    for screen in NSScreen.screens {
      try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
    }
  }

  public func readDockPrefs() throws -> [String: Any] {
    guard let prefs = UserDefaults.standard.persistentDomain(forName: Self.dockDomain) else {
      throw MacSystemError.dockPrefsUnreadable
    }
    return prefs
  }

  public func writeDockPrefs(_ prefs: [String: Any]) throws {
    UserDefaults.standard.setPersistentDomain(prefs, forName: Self.dockDomain)
    CFPreferencesAppSynchronize(Self.dockDomain as CFString)
    let restart = try Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
    restart.waitUntilExit()
  }

  public func readObsidianConfig() throws -> Data {
    try Data(contentsOf: obsidianConfigURL)
  }

  public func writeObsidianConfig(_ data: Data) throws {
    try data.write(to: obsidianConfigURL, options: .atomic)
  }

  public func open(_ url: URL) throws {
    guard NSWorkspace.shared.open(url) else { throw MacSystemError.couldNotOpen(url) }
  }
}

public enum MacSystemError: Error, CustomStringConvertible {
  case fileNotFound(String)
  case dockPrefsUnreadable
  case couldNotOpen(URL)

  public var description: String {
    switch self {
    case .fileNotFound(let path): "\(path) doesn't exist"
    case .dockPrefsUnreadable: "couldn't read com.apple.dock preferences"
    case .couldNotOpen(let url): "couldn't open \(url.absoluteString)"
    }
  }
}
