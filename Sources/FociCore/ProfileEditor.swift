import Foundation

/// The rules for editing profiles from the settings window. Pure: the caller saves the
/// resulting config and state, and moves the Dock file after a rename.
public struct ProfileEditor: Sendable {
  public private(set) var config: Config
  public private(set) var state: State

  public init(config: Config, state: State) {
    self.config = config
    self.state = state
  }

  /// Names become file names (`docks/<name>.plist`) on a case-insensitive disk, so they are
  /// compared without case and may not contain `/` or start with `.`.
  public func validName(_ raw: String, replacing old: String? = nil) throws -> String {
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw ProfileEditError.emptyName }
    guard !name.contains("/"), !name.hasPrefix(".") else {
      throw ProfileEditError.invalidName(name)
    }
    let taken = config.profiles.keys.filter { $0 != old }
    guard !taken.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
      throw ProfileEditError.nameTaken(name)
    }
    return name
  }

  @discardableResult
  public mutating func addProfile() -> String {
    let name =
      (1...).lazy.map { $0 == 1 ? "New Profile" : "New Profile \($0)" }
      .first { (try? validName($0)) != nil }!
    config.profiles[name] = Profile()
    return name
  }

  @discardableResult
  public mutating func rename(_ old: String, to raw: String) throws -> String {
    let profile = try config.profile(old)
    let new = try validName(raw, replacing: old)
    guard new != old else { return old }
    config.profiles[old] = nil
    config.profiles[new] = profile
    if state.current == old { state.current = new }
    state.wallpapers[new] = state.wallpapers.removeValue(forKey: old)
    return new
  }

  public mutating func remove(_ name: String) throws {
    _ = try config.profile(name)
    guard config.profiles.count > 1 else { throw ProfileEditError.lastProfile }
    guard state.current != name else { throw ProfileEditError.currentProfile(name) }
    config.profiles[name] = nil
    state.wallpapers[name] = nil
  }

  public mutating func update(_ name: String, _ change: (inout Profile) -> Void) throws {
    var profile = try config.profile(name)
    change(&profile)
    config.profiles[name] = profile
  }

  /// Clears the wallpaper saved on leaving the profile, so the one chosen here takes effect.
  public mutating func setWallpaper(_ path: String?, for name: String) throws {
    try update(name) { $0.wallpaper = path }
    state.wallpapers[name] = nil
  }

  public mutating func addApps(_ bundleIDs: [String], to name: String) throws {
    try update(name) { $0.apps = ($0.apps + bundleIDs).uniqued() }
  }

  public mutating func removeApp(_ bundleID: String, from name: String) throws {
    try update(name) { $0.apps.removeAll { $0 == bundleID } }
  }
}

public enum ProfileEditError: Error, Equatable, CustomStringConvertible {
  case emptyName
  case invalidName(String)
  case nameTaken(String)
  case lastProfile
  case currentProfile(String)

  public var description: String {
    switch self {
    case .emptyName: "A profile needs a name."
    case .invalidName(let name): "\"\(name)\" can't contain / or start with a dot."
    case .nameTaken(let name): "There's already a profile called \"\(name)\"."
    case .lastProfile: "Foci needs at least one profile."
    case .currentProfile(let name): "Switch away from \(name) before removing it."
    }
  }
}

extension State {
  /// The wallpaper saved when the profile was last left, else the configured one.
  public func wallpaper(for profile: String, in config: Config) -> String? {
    wallpapers[profile] ?? config.profiles[profile]?.wallpaper
  }
}

/// "work" reads as "Work" in the menu; names with capitals of their own are left alone.
public func displayName(of profile: String) -> String {
  profile.prefix(1).uppercased() + profile.dropFirst()
}
