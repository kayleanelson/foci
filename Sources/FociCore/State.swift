public struct State: Codable, Equatable, Sendable {
  public var current: String?
  public var followFocus: Bool

  public init(current: String? = nil, followFocus: Bool = false) {
    self.current = current
    self.followFocus = followFocus
  }
}
