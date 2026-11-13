public struct State: Codable, Equatable, Sendable {
  public var current: String?
  public var followFocus: Bool
  /// Each profile's wallpaper as it was when last left. Overrides the config's.
  public var wallpapers: [String: String]

  public init(
    current: String? = nil, followFocus: Bool = false, wallpapers: [String: String] = [:]
  ) {
    self.current = current
    self.followFocus = followFocus
    self.wallpapers = wallpapers
  }

  /// Every key is optional, so a state.json written before a field existed still loads.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    current = try container.decodeIfPresent(String.self, forKey: .current)
    followFocus = try container.decodeIfPresent(Bool.self, forKey: .followFocus) ?? false
    wallpapers = try container.decodeIfPresent([String: String].self, forKey: .wallpapers) ?? [:]
  }
}
