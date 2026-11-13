import AppKit
import FociCore
import SwiftUI

@main
struct FociMenuApp: App {
  @State private var model = MenuModel()

  init() {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  var body: some Scene {
    MenuBarExtra {
      MenuContent(model: model)
    } label: {
      Image(systemName: model.menuBarSymbol)
    }
  }
}

struct MenuContent: View {
  let model: MenuModel

  var body: some View {
    if let config = model.config {
      ForEach(config.profileNames, id: \.self) { name in
        Toggle(
          isOn: Binding(get: { model.state.current == name }, set: { _ in model.switchTo(name) })
        ) {
          Label(name.capitalized, systemImage: model.symbol(for: name))
        }
        .disabled(model.busy)
      }
    } else if let error = model.configError {
      Text(error)
    }

    if !model.problems.isEmpty {
      Divider()
      ForEach(model.problems, id: \.self) { Text("⚠︎ \($0)") }
    }

    Divider()
    Toggle(
      "Follow Focus",
      isOn: Binding(get: { model.state.followFocus }, set: { model.setFollowFocus($0) }))
    Toggle(
      "Launch at Login",
      isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchesAtLogin($0) }))
    Button("Edit Config…") { model.openConfig() }
    Divider()
    Button("Quit Foci") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }
}
