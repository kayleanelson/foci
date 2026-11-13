import Testing

@testable import FociCore

@Suite struct MenuBarIconTests {
  let config = Config(profiles: [
    "work": Profile(symbol: "briefcase.fill"), "personal": Profile(),
  ])

  @Test func noConfigShowsFoci() {
    #expect(MenuBarIcon(config: nil, current: nil, busy: false) == .foci)
  }

  @Test func noCurrentProfileShowsFoci() {
    #expect(MenuBarIcon(config: config, current: nil, busy: false) == .foci)
  }

  /// A profile renamed or removed since the switch leaves a name in state that no longer
  /// matches anything.
  @Test func staleCurrentProfileShowsFoci() {
    #expect(MenuBarIcon(config: config, current: "gone", busy: false) == .foci)
    #expect(MenuBarIcon(config: nil, current: "work", busy: false) == .foci)
  }

  @Test func currentProfileShowsItsSymbol() {
    #expect(MenuBarIcon(config: config, current: "work", busy: false) == .symbol("briefcase.fill"))
  }

  @Test func currentProfileWithoutSymbolShowsTheDefault() {
    #expect(
      MenuBarIcon(config: config, current: "personal", busy: false)
        == .symbol(Profile.defaultSymbol))
  }

  @Test(arguments: [nil, "work", "gone"])
  func switchingWinsOverEverything(current: String?) {
    #expect(MenuBarIcon(config: config, current: current, busy: true) == .switching)
    #expect(MenuBarIcon(config: nil, current: current, busy: true) == .switching)
  }
}
