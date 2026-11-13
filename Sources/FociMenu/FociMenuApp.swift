import AppKit
import FociCore
import SwiftUI

@main
struct FociMenuApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @State private var model = MenuModel()

  init() {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  var body: some Scene {
    MenuBarExtra {
      MenuContent(model: model)
    } label: {
      MenuBarLabel(symbol: model.menuBarSymbol)
    }

    Window("Foci Settings", id: Self.settingsWindow) {
      SettingsView(model: model)
    }
    .windowResizability(.contentMinSize)
    .defaultSize(width: 720, height: 800)
    .defaultLaunchBehavior(.suppressed)
  }

  static let settingsWindow = "settings"
}

/// Opening Foci while it runs (Finder, Spotlight) shows Settings rather than nothing: a menu
/// bar app has no window to bring forward, and its icon may be hidden (e.g. by Bartender).
final class AppDelegate: NSObject, NSApplicationDelegate {
  static let reopened = Notification.Name("local.foci.reopened")

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    NotificationCenter.default.post(name: Self.reopened, object: nil)
    return false
  }
}

/// The menu bar label is the one view alive for the app's whole life, so it is where a reopen
/// can reach `openWindow`.
struct MenuBarLabel: View {
  let symbol: String
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Image(systemName: symbol)
      .onReceive(NotificationCenter.default.publisher(for: AppDelegate.reopened)) { _ in
        openWindow(id: FociMenuApp.settingsWindow)
        NSApplication.shared.activate()
      }
  }
}

struct MenuContent: View {
  let model: MenuModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    if let config = model.config {
      ForEach(config.profileNames, id: \.self) { name in
        Toggle(
          isOn: Binding(get: { model.state.current == name }, set: { _ in model.switchTo(name) })
        ) {
          Label(displayName(of: name), systemImage: model.symbol(for: name))
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
    Button("Settings…") {
      openWindow(id: FociMenuApp.settingsWindow)
      NSApplication.shared.activate()
    }
    .keyboardShortcut(",")
    Divider()
    Button("Quit Foci") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }
}
