import Testing

@testable import FociCore

@Suite struct AppsToQuitTests {
  static let configs: [Config] = [
    Config(profiles: [
      "work": Profile(apps: ["slack", "outlook", "shared"]),
      "personal": Profile(apps: ["messages", "shared"]),
    ]),
    Config(profiles: [
      "work": Profile(apps: ["a", "a", "b"]),
      "personal": Profile(apps: []),
      "study": Profile(apps: ["b", "c"]),
    ]),
    Config(profiles: ["solo": Profile(apps: ["x"])]),
  ]

  @Test(arguments: configs)
  func appInTheTargetProfileIsNeverQuit(config: Config) throws {
    for target in config.profileNames {
      let quit = try config.appsToQuit(switchingTo: target)
      #expect(Set(quit).isDisjoint(with: config.profiles[target]!.apps))
    }
  }

  @Test(arguments: configs)
  func onlyAppsFromTheConfigAreQuit(config: Config) throws {
    let known = Set(config.profiles.values.flatMap(\.apps))
    for target in config.profileNames {
      #expect(Set(try config.appsToQuit(switchingTo: target)).isSubset(of: known))
    }
  }

  @Test(arguments: configs)
  func noAppIsListedTwice(config: Config) throws {
    for target in config.profileNames {
      let quit = try config.appsToQuit(switchingTo: target)
      #expect(quit.count == Set(quit).count)
    }
  }

  @Test func quitsOnlyTheOtherProfilesOwnApps() throws {
    #expect(try Self.configs[0].appsToQuit(switchingTo: "personal") == ["slack", "outlook"])
  }
}
