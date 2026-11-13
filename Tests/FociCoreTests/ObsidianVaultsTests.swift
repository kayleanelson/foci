import Foundation
import Testing

@testable import FociCore

@Suite struct ObsidianVaultsTests {
  static let config = Data(
    """
    {"vaults": {
      "a1": {"path": "/Users/k/Work Vault", "ts": 1, "open": true},
      "b2": {"path": "/Users/k/Personal Vault", "ts": 2},
      "c3": {"path": "/Users/k/Old", "ts": 3, "open": true}
    }, "frame": {"x": 1}, "updateDisabled": true}
    """.utf8)

  func transformed(_ path: String) throws -> [String: Any] {
    let data = try ObsidianVaults.openingOnly(vaultAt: path, in: Self.config)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
  }

  func openVaults(_ root: [String: Any]) -> [String] {
    (root["vaults"] as! [String: [String: Any]])
      .filter { $0.value["open"] as? Bool == true }.map(\.key)
  }

  @Test(arguments: ["/Users/k/Personal Vault", "/Users/k/Personal Vault/", "/Users/k/Work Vault"])
  func exactlyTheTargetVaultIsOpen(path: String) throws {
    let open = openVaults(try transformed(path))
    #expect(open.count == 1)
    #expect(open == [path.contains("Work") ? "a1" : "b2"])
  }

  @Test func unregisteredVaultLeavesNoneOpen() throws {
    #expect(openVaults(try transformed("/Users/k/New")).isEmpty)
  }

  @Test func otherKeysAndVaultsAreKept() throws {
    let root = try transformed("/Users/k/Personal Vault")
    #expect(Set(root.keys) == ["vaults", "frame", "updateDisabled"])
    let vaults = root["vaults"] as! [String: [String: Any]]
    #expect(Set(vaults.keys) == ["a1", "b2", "c3"])
    #expect(vaults["c3"]?["ts"] as? Int == 3)
  }

  @Test func openURLEncodesSpaces() {
    #expect(
      ObsidianVaults.openURL(forVaultAt: "/Users/k/Work Vault").absoluteString
        == "obsidian://open?path=/Users/k/Work%20Vault")
  }
}
