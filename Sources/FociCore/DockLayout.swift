import Foundation

/// The parts of `com.apple.dock` that make up the Dock's contents. Everything else (size,
/// position, magnification) is shared by all profiles and left alone.
public enum DockLayout {
  public static let keys = ["persistent-apps", "persistent-others"]

  public static func snapshot(of prefs: [String: Any]) -> [String: Any] {
    prefs.filter { keys.contains($0.key) }
  }

  public static func applying(_ snapshot: [String: Any], to prefs: [String: Any]) -> [String: Any] {
    prefs.merging(snapshot.filter { keys.contains($0.key) }) { _, saved in saved }
  }

  public static func encode(_ snapshot: [String: Any]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: snapshot, format: .xml, options: 0)
  }

  public static func decode(_ data: Data) throws -> [String: Any] {
    guard
      let snapshot = try PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any]
    else { throw DockLayoutError.notADictionary }
    return snapshot
  }
}

public enum DockLayoutError: Error {
  case notADictionary
}
