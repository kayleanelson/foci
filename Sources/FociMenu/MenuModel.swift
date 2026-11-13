import AppKit
import FociCore
import FociSystem
import Observation
import ServiceManagement

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

  /// First run: copies the bundled example config into place to edit.
  func openConfig() {
    if config == nil, !FileManager.default.fileExists(atPath: store.configURL.path),
      let example = Bundle.main.url(forResource: "config.example", withExtension: "json")
    {
      record {
        try FileManager.default.createDirectory(
          at: store.directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: example, to: store.configURL)
      }
    }
    NSWorkspace.shared.activateFileViewerSelecting([store.configURL])
  }

  private func record(_ action: () throws -> Void) {
    do { try action() } catch { problems = ["\(error)"] }
  }
}
