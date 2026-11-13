import Foundation
import Testing

@testable import FociCore

@Suite struct ConfigTests {
  @Test func missingOptionalKeysDecodeToDefaults() throws {
    let config = try Config.decode(Data(#"{"profiles": {"work": {}}}"#.utf8))
    #expect(config.profiles["work"] == Profile())
  }

  @Test func emptyProfilesIsAnError() {
    #expect(throws: FociError.noProfiles) {
      try Config.decode(Data(#"{"profiles": {}}"#.utf8))
    }
  }

  @Test func unknownProfileNamesTheKnownOnes() {
    let config = Config(profiles: ["work": Profile(), "personal": Profile()])
    #expect(throws: FociError.unknownProfile("wrk", known: ["personal", "work"])) {
      try config.profile("wrk")
    }
  }

  @Test func exampleConfigDecodes() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().appending(path: "../../config.example.json")
    let config = try Config.decode(Data(contentsOf: url))
    #expect(config.profileNames == ["personal", "work"])
  }
}

@Suite struct PathTests {
  @Test(arguments: [
    ("~", "/Users/k"),
    ("~/Vault", "/Users/k/Vault"),
    ("~/Vault/", "/Users/k/Vault"),
    ("/Users/k/Vault/../Vault", "/Users/k/Vault"),
    ("/abs/path", "/abs/path"),
  ])
  func normalizes(input: String, expected: String) {
    #expect(normalizedPath(input, home: "/Users/k") == expected)
  }

  @Test func tildeInsideAPathIsLiteral() {
    #expect(expandingTilde("/a/~/b", home: "/Users/k") == "/a/~/b")
  }
}
