import FociCore
import Foundation
import Testing

@testable import FociSystem

@MainActor
@Suite struct FileStoreTests {
  let store = FileStore(
    directory: FileManager.default.temporaryDirectory.appending(path: "foci-\(UUID())"))

  @Test func missingStateIsTheDefault() throws {
    #expect(try store.loadState() == State())
  }

  @Test func stateAndDocksRoundTrip() throws {
    try store.saveState(State(current: "work", followFocus: true))
    try store.saveDock(Data("dock".utf8), for: "work")
    #expect(try store.loadState() == State(current: "work", followFocus: true))
    #expect(try store.loadDock(for: "work") == Data("dock".utf8))
    #expect(try store.loadDock(for: "personal") == nil)
  }

  @Test func missingConfigSaysWhereToPutIt() {
    #expect {
      try store.loadConfig()
    } throws: { error in
      "\(error)".contains(store.configURL.path) && "\(error)".contains("config.example.json")
    }
  }

  @Test func savedConfigLoadsBack() throws {
    #expect(!store.hasConfig)
    try store.saveConfig(.starter)
    #expect(store.hasConfig)
    #expect(try store.loadConfig() == .starter)
  }

  @Test func dockFollowsARenameAndGoesWithARemoval() throws {
    try store.saveDock(Data("dock".utf8), for: "work")
    try store.moveDock(from: "work", to: "Work")
    #expect(try store.loadDock(for: "Work") == Data("dock".utf8))
    try store.removeDock(for: "Work")
    #expect(try store.loadDock(for: "Work") == nil)
  }

  @Test func profilesWithoutADockRenameAndRemoveQuietly() throws {
    try store.moveDock(from: "none", to: "other")
    try store.removeDock(for: "none")
  }
}
