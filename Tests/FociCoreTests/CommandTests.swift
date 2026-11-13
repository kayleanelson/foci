import Testing

@testable import FociCore

@Suite struct CommandTests {
  @Test(arguments: [
    ([], Command.help),
    (["status"], .status),
    (["switch", "work"], .switchTo(SwitchRequest(target: "work"))),
    (["switch", "work", "--force"], .switchTo(SwitchRequest(target: "work", force: true))),
    (
      ["switch", "work", "--source", "focus", "--force"],
      .switchTo(SwitchRequest(target: "work", source: .focus, force: true))
    ),
    (["capture-dock"], .captureDock(profile: nil)),
    (["capture-dock", "work"], .captureDock(profile: "work")),
    (["follow-focus", "on"], .followFocus(true)),
    (["follow-focus", "off"], .followFocus(false)),
  ])
  func parses(arguments: [String], expected: Command) throws {
    #expect(try Command.parse(arguments) == expected)
  }

  @Test(arguments: [
    ["switch"], ["switch", "--force"], ["switch", "work", "--source"],
    ["switch", "work", "--source", "calendar"], ["switch", "work", "--frce"],
    ["status", "extra"], ["help", "x"], ["--help", "x"], ["capture-dock", "a", "b"],
    ["follow-focus", "yes"], ["swich", "work"],
  ])
  func rejectsMalformedInput(arguments: [String]) {
    #expect(throws: CommandError.usage) { try Command.parse(arguments) }
  }

  @Test func focusIsNeverTheDefaultSource() throws {
    #expect(try Command.parse(["switch", "work"]) == .switchTo(SwitchRequest(target: "work")))
    #expect(SwitchRequest(target: "work").source == .manual)
  }
}
