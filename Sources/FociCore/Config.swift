import Foundation

public struct Profile: Codable, Equatable, Sendable {
  public static let defaultSymbol = "person.crop.circle"

  public var symbol: String?
  public var wallpaper: String?
  public var obsidianVault: String?
  public var apps: [String]

  public init(
    symbol: String? = nil, wallpaper: String? = nil, obsidianVault: String? = nil,
    apps: [String] = []
  ) {
    self.symbol = symbol
    self.wallpaper = wallpaper
    self.obsidianVault = obsidianVault
    self.apps = apps
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
    wallpaper = try container.decodeIfPresent(String.self, forKey: .wallpaper)
    obsidianVault = try container.decodeIfPresent(String.self, forKey: .obsidianVault)
    apps = try container.decodeIfPresent([String].self, forKey: .apps) ?? []
  }
}

public struct Config: Codable, Equatable, Sendable {
  public var profiles: [String: Profile]

  public init(profiles: [String: Profile]) {
    self.profiles = profiles
  }

  public static func decode(_ data: Data) throws -> Config {
    let config = try JSONDecoder().decode(Config.self, from: data)
    guard !config.profiles.isEmpty else { throw FociError.noProfiles }
    return config
  }

  public static let starter = Config(profiles: [
    "work": Profile(symbol: "briefcase.fill"), "personal": Profile(symbol: "house.fill"),
  ])

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }

  public var profileNames: [String] { profiles.keys.sorted() }

  /// The profile's name as configured, matched without case: a Shortcuts automation written
  /// with "work" keeps working after the profile is renamed "Work". Settings keeps names
  /// unique without case, so the match is never ambiguous.
  public func canonicalName(_ name: String) throws -> String {
    guard
      let match = profiles.keys.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
    else { throw FociError.unknownProfile(name, known: profileNames) }
    return match
  }

  public func profile(_ name: String) throws -> Profile {
    guard let profile = profiles[name] else {
      throw FociError.unknownProfile(name, known: profileNames)
    }
    return profile
  }
}

public enum FociError: Error, Equatable, CustomStringConvertible {
  case noProfiles
  case unknownProfile(String, known: [String])

  public var description: String {
    switch self {
    case .noProfiles:
      "config.json defines no profiles"
    case .unknownProfile(let name, let known):
      "no profile named \"\(name)\" (known: \(known.joined(separator: ", ")))"
    }
  }
}
