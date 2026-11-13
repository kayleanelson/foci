import Testing

@testable import FociCore

@Suite struct AppPlanTests {
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
      let plan = try config.appPlan(switchingTo: target)
      #expect(Set(plan.quit).isDisjoint(with: config.profiles[target]!.apps))
    }
  }

  @Test(arguments: configs)
  func plansOnlyNameAppsFromTheConfig(config: Config) throws {
    let known = Set(config.profiles.values.flatMap(\.apps))
    for target in config.profileNames {
      let plan = try config.appPlan(switchingTo: target)
      #expect(Set(plan.quit + plan.launch).isSubset(of: known))
    }
  }

  @Test(arguments: configs)
  func plansHaveNoDuplicates(config: Config) throws {
    for target in config.profileNames {
      let plan = try config.appPlan(switchingTo: target)
      #expect(plan.quit.count == Set(plan.quit).count)
      #expect(plan.launch.count == Set(plan.launch).count)
    }
  }

  @Test func quitsOtherProfilesAppsAndLaunchesOwn() throws {
    let plan = try Self.configs[0].appPlan(switchingTo: "personal")
    #expect(plan == AppPlan(quit: ["slack", "outlook"], launch: ["messages", "shared"]))
  }
}
