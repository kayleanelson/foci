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
}
