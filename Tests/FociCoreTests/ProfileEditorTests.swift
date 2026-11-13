import Foundation
import Testing

@testable import FociCore

@Suite struct ProfileEditorTests {
  let editor = ProfileEditor(
    config: Config(profiles: [
      "work": Profile(symbol: "briefcase.fill", wallpaper: "~/w.png", apps: ["slack"]),
      "personal": Profile(apps: ["photos"]),
    ]),
    state: State(current: "work", wallpapers: ["work": "/saved.png", "personal": "/p.png"]))

  @Test(arguments: ["", "  ", "a/b", ".hidden", "personal", "PERSONAL", " Personal "])
  func rejectsNamesThatCannotBeAProfile(name: String) {
    #expect(throws: ProfileEditError.self) { try editor.validName(name) }
  }

  @Test func trimsNames() throws {
    #expect(try editor.validName("  Study ") == "Study")
  }

  @Test func renameCarriesEverythingKeyedByTheName() throws {
    var editor = editor
    let new = try editor.rename("work", to: "Work")
    #expect(new == "Work")
    #expect(editor.config.profileNames == ["Work", "personal"])
    #expect(editor.config.profiles["Work"]?.apps == ["slack"])
    #expect(editor.state.current == "Work")
    #expect(editor.state.wallpapers == ["Work": "/saved.png", "personal": "/p.png"])
  }

  @Test func renameToItsOwnNameChangesNothing() throws {
    var editor = editor
    #expect(try editor.rename("work", to: " work ") == "work")
    #expect(editor.config == self.editor.config)
    #expect(editor.state == self.editor.state)
  }

  @Test func renameOntoAnotherProfileFails() {
    var editor = editor
    #expect(throws: ProfileEditError.nameTaken("Personal")) {
      try editor.rename("work", to: "Personal")
    }
  }

  @Test func addedProfilesGetDistinctNames() {
    var editor = editor
    let names = (0..<3).map { _ in editor.addProfile() }
    #expect(names == ["New Profile", "New Profile 2", "New Profile 3"])
    #expect(editor.config.profiles.count == 5)
  }

  @Test func removingDropsTheProfileAndItsSavedWallpaper() throws {
    var editor = editor
    try editor.remove("personal")
    #expect(editor.config.profileNames == ["work"])
    #expect(editor.state.wallpapers["personal"] == nil)
  }

  @Test func cannotRemoveTheCurrentOrTheLastProfile() throws {
    var editor = editor
    #expect(throws: ProfileEditError.currentProfile("work")) { try editor.remove("work") }
    try editor.remove("personal")
    #expect(throws: ProfileEditError.lastProfile) { try editor.remove("work") }
  }

  @Test func choosingAWallpaperReplacesTheSavedOne() throws {
    var editor = editor
    try editor.setWallpaper("~/new.png", for: "work")
    #expect(editor.state.wallpaper(for: "work", in: editor.config) == "~/new.png")
  }

  @Test func addingAppsNeverDuplicates() throws {
    var editor = editor
    try editor.addApps(["slack", "zoom", "zoom"], to: "work")
    #expect(editor.config.profiles["work"]?.apps == ["slack", "zoom"])
    try editor.removeApp("slack", from: "work")
    #expect(editor.config.profiles["work"]?.apps == ["zoom"])
  }

  @Test func editingAnUnknownProfileFails() {
    var editor = editor
    #expect(throws: FociError.self) { try editor.update("nope") { _ in } }
    #expect(throws: FociError.self) { try editor.rename("nope", to: "x") }
  }

  @Test(arguments: [("work", "Work"), ("YCRC", "YCRC"), ("new profile", "New profile")])
  func displayNames(name: String, shown: String) {
    #expect(displayName(of: name) == shown)
  }
}

@Suite struct ConfigEncodingTests {
  @Test(arguments: [Config.starter, Config(profiles: ["w": Profile(wallpaper: "~/a b/c.png")])])
  func savedConfigLoadsBackUnchanged(config: Config) throws {
    #expect(try Config.decode(config.encoded()) == config)
  }

  @Test func savedConfigOmitsUnsetFieldsAndKeepsPathsReadable() throws {
    let json = String(
      decoding: try Config(profiles: ["w": Profile(wallpaper: "~/a/b.png")]).encoded(),
      as: UTF8.self)
    #expect(!json.contains("obsidianVault"))
    #expect(json.contains("~/a/b.png"))
  }
}
