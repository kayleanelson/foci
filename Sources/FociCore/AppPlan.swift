public struct AppPlan: Equatable, Sendable {
  public var quit: [String]
  public var launch: [String]
}

extension Config {
  /// Quits apps that belong to another profile but not the target; apps in both, or in none,
  /// are never touched. Uses every other profile rather than only the current one, so the
  /// plan is the same whether or not the current profile is known.
  public func appPlan(switchingTo target: String) throws -> AppPlan {
    let incoming = try profile(target)
    let keep = Set(incoming.apps)
    let others = profiles.filter { $0.key != target }.sorted { $0.key < $1.key }
    return AppPlan(
      quit: others.flatMap(\.value.apps).filter { !keep.contains($0) }.uniqued(),
      launch: incoming.apps.uniqued()
    )
  }
}

extension Sequence where Element: Hashable {
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}
