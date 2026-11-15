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
      MenuBarLabel(icon: model.menuBarIcon)
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
  let icon: MenuBarIcon
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    image
      .onReceive(NotificationCenter.default.publisher(for: AppDelegate.reopened)) { _ in
        openWindow.settings()
      }
  }

  private var image: Image {
    switch icon {
    case .symbol(let name): Image(systemName: name)
    // `swift run` has no asset catalog; only the bundled app carries the glyph.
    case .foci:
      NSImage(named: "MenuBarIcon").map(Image.init(nsImage:)) ?? Image(systemName: "circle.circle")
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
      "Launch at Login",
      isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchesAtLogin($0) }))
    Button("Settings…") { openWindow.settings() }
      .keyboardShortcut(",")
    Divider()
    Button("Quit Foci") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }
}

extension OpenWindowAction {
  /// Since macOS 14, `activate()` only asks: the app in front can keep its place, and an
  /// accessory app's window then opens behind it. Ordering the window front regardless
  /// shows it either way; activation, when granted, also gives it the keyboard.
  @MainActor func settings() {
    NSApplication.shared.activate()
    callAsFunction(id: FociMenuApp.settingsWindow)
    // SwiftUI creates the window after this turn of the run loop.
    DispatchQueue.main.async {
      guard
        let window = NSApplication.shared.windows.first(where: {
          $0.identifier?.rawValue.hasPrefix(FociMenuApp.settingsWindow) == true
        })
      else { return }
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
    }
  }
}
