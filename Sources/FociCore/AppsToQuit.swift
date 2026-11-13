extension Config {
  /// Apps that belong to another profile but not the target; apps in both, or in none, are
  /// never touched. Uses every other profile rather than only the current one, so the answer
  /// is the same whether or not the current profile is known.
  public func appsToQuit(switchingTo target: String) throws -> [String] {
    let keep = Set(try profile(target).apps)
    let others = profiles.filter { $0.key != target }.sorted { $0.key < $1.key }
    return others.flatMap(\.value.apps).filter { !keep.contains($0) }.uniqued()
  }
}

extension Sequence where Element: Hashable {
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}
