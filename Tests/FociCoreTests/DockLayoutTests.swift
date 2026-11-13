import Foundation
import Testing

@testable import FociCore

@Suite struct DockLayoutTests {
  static var prefs: [String: Any] {
    [
      "persistent-apps": [
        [
          "tile-data": [
            "file-label": "Slack", "file-data": ["_CFURLString": "file:///A/Slack.app/"],
          ]
        ]
      ],
      "persistent-others": [
        ["tile-data": ["file-label": "Downloads"], "tile-type": "directory-tile"]
      ],
      "tilesize": 48,
      "orientation": "left",
      "recent-apps": ["x"],
    ]
  }

  @Test func snapshotHoldsOnlyLayoutKeys() {
    #expect(Set(DockLayout.snapshot(of: Self.prefs).keys) == Set(DockLayout.keys))
  }

  @Test func applyingNeverChangesNonLayoutKeys() {
    let other: [String: Any] = [
      "persistent-apps": [], "persistent-others": [], "tilesize": 99, "autohide": true,
    ]
    let result = DockLayout.applying(other, to: Self.prefs)
    for (key, value) in Self.prefs where !DockLayout.keys.contains(key) {
      #expect(
        NSDictionary(dictionary: result).object(forKey: key) as? NSObject == value as? NSObject)
    }
    #expect(result["autohide"] == nil)
  }

  @Test func snapshotSurvivesEncodeAndRestore() throws {
    let saved = try DockLayout.encode(DockLayout.snapshot(of: Self.prefs))
    let emptied = DockLayout.applying(
      ["persistent-apps": [], "persistent-others": []], to: Self.prefs)
    let restored = DockLayout.applying(try DockLayout.decode(saved), to: emptied)
    #expect(NSDictionary(dictionary: restored).isEqual(to: Self.prefs))
  }

  @Test func layoutKeyMissingFromSnapshotIsKept() {
    let result = DockLayout.applying(["persistent-apps": []], to: Self.prefs)
    #expect((result["persistent-others"] as? [Any])?.count == 1)
  }
}

@Suite struct DockRemovalTests {
  static func app(_ id: String) -> [String: Any] {
    ["tile-data": ["bundle-identifier": id, "file-label": id], "tile-type": "file-tile"]
  }
  static var spacer: [String: Any] {
    ["tile-data": [:] as [String: Any], "tile-type": "spacer-tile"]
  }

  static var prefs: [String: Any] {
    [
      "persistent-apps": [app("slack"), spacer, app("photos"), app("zoom")],
      "persistent-others": [app("slack")],
      "tilesize": 48,
    ]
  }

  func appIDs(_ prefs: [String: Any]) -> [String] {
    (prefs["persistent-apps"] as! [[String: Any]]).map {
      ($0["tile-data"] as! [String: Any])["bundle-identifier"] as? String ?? "spacer"
    }
  }

  @Test func removesOnlyTheNamedApps() {
    let result = DockLayout.removingApps(["slack", "zoom", "absent"], from: Self.prefs)
    #expect(appIDs(result) == ["spacer", "photos"])
  }

  @Test func onlyTouchesPersistentApps() {
    let result = DockLayout.removingApps(["slack"], from: Self.prefs)
    #expect((result["persistent-others"] as? [Any])?.count == 1)
    #expect(result["tilesize"] as? Int == 48)
  }

  @Test func removingNothingChangesNothing() {
    let result = DockLayout.removingApps([], from: Self.prefs)
    #expect(NSDictionary(dictionary: result).isEqual(to: Self.prefs))
  }
}
