import FociCore
import Foundation

/// The tool's own files under `~/Library/Application Support/foci/`. `config.json` there is
/// the user's and is only ever read.
@MainActor
public struct FileStore: Store {
  public let directory: URL

  public init(
    directory: URL = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Application Support/foci")
  ) {
    self.directory = directory
  }

  /// Posted machine-wide on every state save, so the menu bar app reflects switches the CLI
  /// makes (a Focus automation, say).
  public static let stateChanged = Notification.Name("local.foci.stateChanged")

  public var configURL: URL { directory.appending(path: "config.json") }
  var stateURL: URL { directory.appending(path: "state.json") }
  func dockURL(for profile: String) -> URL { directory.appending(path: "docks/\(profile).plist") }

  public func loadConfig() throws -> Config {
    guard FileManager.default.fileExists(atPath: configURL.path) else {
      throw FileStoreError.noConfig(configURL.path)
    }
    return try Config.decode(Data(contentsOf: configURL))
  }

  public func loadState() throws -> State {
    guard let data = try? Data(contentsOf: stateURL) else { return State() }
    return try JSONDecoder().decode(State.self, from: data)
  }

  public func saveState(_ state: State) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try write(encoder.encode(state), to: stateURL)
    DistributedNotificationCenter.default().postNotificationName(
      Self.stateChanged, object: nil, deliverImmediately: true)
  }

  public func loadDock(for profile: String) throws -> Data? {
    try? Data(contentsOf: dockURL(for: profile))
  }

  public func saveDock(_ data: Data, for profile: String) throws {
    try write(data, to: dockURL(for: profile))
  }

  private func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }
}

public enum FileStoreError: Error, CustomStringConvertible {
  case noConfig(String)

  public var description: String {
    switch self {
    case .noConfig(let path):
      "no config at \(path) — copy config.example.json there and edit it"
    }
  }
}
