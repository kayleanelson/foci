import AppKit
import FociCore
import FociSystem
import Observation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
@Observable
final class MenuModel {
  static let defaultSymbol = "person.crop.circle"

  private let store = FileStore()
  private(set) var config: Config?
  private(set) var configError: String?
  private(set) var state = State()
  private(set) var problems: [String] = []
  private(set) var busy = false
  private(set) var settingsError: String?
  @ObservationIgnored private var configWatcher: DispatchSourceFileSystemObject?

  init() {
    reload()
    watchConfigDirectory()
    DistributedNotificationCenter.default().addObserver(
      forName: FileStore.stateChanged, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.reload() }
    }
  }

  /// Watches the directory, not the file: editors save by replacing the file, which would
  /// orphan a watch on the old one.
  private func watchConfigDirectory() {
    try? FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
    let descriptor = open(store.directory.path, O_EVTONLY)
    guard descriptor >= 0 else { return }
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: .write, queue: .main)
    source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.reload() } }
    source.setCancelHandler { close(descriptor) }
    source.resume()
    configWatcher = source
  }

  func reload() {
    do {
      config = try store.loadConfig()
      configError = nil
    } catch {
      config = nil
      configError = "\(error)"
    }
    state = (try? store.loadState()) ?? State()
  }

  func symbol(for profile: String?) -> String {
    profile.flatMap { config?.profiles[$0]?.symbol } ?? Self.defaultSymbol
  }

  var menuBarSymbol: String { busy ? "arrow.triangle.2.circlepath" : symbol(for: state.current) }

  func switchTo(_ profile: String) {
    guard let config, !busy, profile != state.current else { return }
    busy = true
    problems = []
    Task {
      defer {
        busy = false
        reload()
      }
      do {
        let switcher = Switcher(
          config: config, system: MacSystem(), store: store,
          home: FileManager.default.homeDirectoryForCurrentUser.path)
        problems = try await switcher.run(SwitchRequest(target: profile)).problems
      } catch {
        problems = ["\(error)"]
      }
    }
  }

  func setFollowFocus(_ on: Bool) {
    state.followFocus = on
    record { try store.saveState(state) }
  }

  var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

  func setLaunchesAtLogin(_ on: Bool) {
    record { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
  }

  private func record(_ action: () throws -> Void) {
    do { try action() } catch { problems = ["\(error)"] }
  }

  // MARK: Settings

  var profileNames: [String] { config?.profileNames ?? [] }

  /// A config.json that exists but won't load is hers to fix; editing would overwrite it.
  var canEditSettings: Bool { config != nil || !store.hasConfig }

  @discardableResult
  private func edit<Result>(_ change: (inout ProfileEditor) throws -> Result) -> Result? {
    guard canEditSettings else { return nil }
    var editor = ProfileEditor(config: config ?? .starter, state: state)
    do {
      let result = try change(&editor)
      try store.saveConfig(editor.config)
      if editor.state != state { try store.saveState(editor.state) }
      config = editor.config
      state = editor.state
      settingsError = nil
      return result
    } catch {
      settingsError = "\(error)"
      return nil
    }
  }

  private func noteSettingsError(_ action: () throws -> Void) {
    do { try action() } catch { settingsError = "\(error)" }
  }

  func createStarterProfiles() { edit { _ in } }

  func addProfile() -> String? { edit { $0.addProfile() } }

  func renameProfile(_ old: String, to new: String) -> String? {
    guard let renamed = edit({ try $0.rename(old, to: new) }) else { return nil }
    if renamed != old { noteSettingsError { try store.moveDock(from: old, to: renamed) } }
    return renamed
  }

  func removeProfile(_ name: String) {
    guard edit({ try $0.remove(name) }) != nil else { return }
    noteSettingsError { try store.removeDock(for: name) }
  }

  func setSymbol(_ symbol: String, for name: String) {
    edit { try $0.update(name) { $0.symbol = symbol } }
  }

  func wallpaper(for name: String) -> String? {
    config.flatMap { state.wallpaper(for: name, in: $0) }
  }

  /// Applied at once when it's the current profile's, so the choice is visible.
  func chooseWallpaper(for name: String) {
    guard let url = choose([.image]).first else { return }
    guard edit({ try $0.setWallpaper(tildePath(url), for: name) }) != nil,
      state.current == name
    else { return }
    noteSettingsError { try MacSystem().setWallpaper(url.path) }
  }

  func chooseVault(for name: String) {
    guard let url = choose([], directories: true).first else { return }
    edit { try $0.update(name) { $0.obsidianVault = tildePath(url) } }
  }

  func clearVault(for name: String) {
    edit { try $0.update(name) { $0.obsidianVault = nil } }
  }

  func addApps(to name: String) {
    let ids = choose(
      [.applicationBundle], multiple: true, startingIn: URL(filePath: "/Applications")
    )
    .compactMap { Bundle(url: $0)?.bundleIdentifier }
    guard !ids.isEmpty else { return }
    edit { try $0.addApps(ids, to: name) }
  }

  func removeApp(_ bundleID: String, from name: String) {
    edit { try $0.removeApp(bundleID, from: name) }
  }

  func appName(_ bundleID: String) -> String { MacSystem().displayName(of: bundleID) }

  func appIcon(_ bundleID: String) -> NSImage? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map {
      NSWorkspace.shared.icon(forFile: $0.path)
    }
  }

  private func tildePath(_ url: URL) -> String {
    (url.path as NSString).abbreviatingWithTildeInPath
  }

  private func choose(
    _ types: [UTType], directories: Bool = false, multiple: Bool = false, startingIn: URL? = nil
  ) -> [URL] {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = types
    panel.canChooseDirectories = directories
    panel.canChooseFiles = !directories
    panel.allowsMultipleSelection = multiple
    panel.directoryURL = startingIn
    NSApplication.shared.activate()
    return panel.runModal() == .OK ? panel.urls : []
  }
}
