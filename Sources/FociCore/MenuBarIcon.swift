/// What the menu bar shows: the current profile's symbol, or Foci's own glyph while no
/// profile is current, which includes before any profile exists.
public enum MenuBarIcon: Equatable, Sendable {
  case foci
  case symbol(String)

  public static let switching = MenuBarIcon.symbol("arrow.triangle.2.circlepath")

  public init(config: Config?, current: String?, busy: Bool) {
    if busy {
      self = .switching
    } else if let current, let profile = config?.profiles[current] {
      self = .symbol(profile.symbol ?? Profile.defaultSymbol)
    } else {
      self = .foci
    }
  }
}
