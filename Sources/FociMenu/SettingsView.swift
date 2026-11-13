import AppKit
import FociCore
import SwiftUI

private enum SidebarItem: Hashable {
  case general
  case profile(String)
}

struct SettingsView: View {
  let model: MenuModel
  @State private var selection: SidebarItem?

  var body: some View {
    Group {
      if model.canEditSettings && model.config == nil {
        ContentUnavailableView {
          Label("No profiles yet", systemImage: "person.2")
        } actions: {
          Button("Create Work and Personal") {
            model.createStarterProfiles()
            selection = .profile("work")
          }
        }
      } else if !model.canEditSettings {
        ContentUnavailableView(
          "config.json couldn't be read", systemImage: "exclamationmark.triangle",
          description: Text(model.configError ?? ""))
      } else {
        content
      }
    }
    .frame(minWidth: 640, minHeight: 460)
    .disabled(model.busy)
  }

  private var selectedProfile: String? {
    if case .profile(let name) = selection { name } else { nil }
  }

  private var content: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Label("General", systemImage: "gearshape").tag(SidebarItem.general)
        Section("Profiles") {
          ForEach(model.profileNames, id: \.self) { name in
            Label(displayName(of: name), systemImage: model.symbol(for: name))
              .tag(SidebarItem.profile(name))
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        HStack(spacing: 2) {
          Button("Add Profile", systemImage: "plus") {
            selection = model.addProfile().map(SidebarItem.profile)
          }
          Button("Remove Profile", systemImage: "minus") {
            if let selectedProfile { model.removeProfile(selectedProfile) }
            selection = model.state.current.map(SidebarItem.profile)
          }
          .disabled(selectedProfile == nil)
          Spacer()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(8)
      }
      .navigationSplitViewColumnWidth(min: 160, ideal: 180)
    } detail: {
      if selection == .general {
        GeneralSettings(model: model)
      } else if let name = selectedProfile, let profile = model.config?.profiles[name] {
        ProfileDetail(
          model: model, name: name, profile: profile,
          onRename: { selection = .profile($0) }
        )
        .id(name)
      } else {
        Text("Select a profile").foregroundStyle(.secondary)
      }
    }
    .onAppear {
      selection =
        selection ?? (model.state.current ?? model.profileNames.first).map(SidebarItem.profile)
    }
  }
}

private struct GeneralSettings: View {
  let model: MenuModel

  private var command: String {
    Bundle.main.bundlePath + "/Contents/Resources/foci switch <profile> --source focus"
  }

  var body: some View {
    Form {
      Section {
        Toggle(
          "Follow Focus",
          isOn: Binding(get: { model.state.followFocus }, set: { model.setFollowFocus($0) }))
      } footer: {
        VStack(alignment: .leading, spacing: 6) {
          Text(
            "When on, turning on a Focus switches profile. Off by default, so a scheduled "
              + "Focus never switches you in the middle of late work or on a holiday.")
          Text(
            "Each Focus needs a Shortcuts automation (When Turning On, Run Immediately) with a "
              + "Run Shell Script action:")
          Text(command).font(.caption.monospaced()).textSelection(.enabled)
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let error = model.settingsError {
        Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
      }
    }
    .formStyle(.grouped)
  }
}

private struct ProfileDetail: View {
  static let symbols = [
    "briefcase.fill", "house.fill", "building.2.fill", "graduationcap.fill",
    "laptopcomputer", "book.fill", "paintbrush.fill", "hammer.fill",
    "flask.fill", "gamecontroller.fill", "heart.fill", "star.fill",
    "leaf.fill", "moon.fill", "sun.max.fill", "person.crop.circle",
  ]

  let model: MenuModel
  let name: String
  let profile: Profile
  let onRename: (String) -> Void
  @State private var draftName = ""
  @FocusState private var editingName: Bool

  var body: some View {
    Form {
      Section {
        TextField("Name", text: $draftName)
          .focused($editingName)
          .onSubmit(commitName)
          .onChange(of: editingName) { if !editingName { commitName() } }
        LabeledContent("Icon") { symbolGrid }
      }

      Section("Wallpaper") { wallpaperRow }

      Section("Obsidian vault") {
        LabeledContent {
          HStack {
            if profile.obsidianVault != nil {
              Button("Clear") { model.clearVault(for: name) }
            }
            Button("Choose…") { model.chooseVault(for: name) }
          }
        } label: {
          Text(profile.obsidianVault.map { ($0 as NSString).lastPathComponent } ?? "None")
          if let vault = profile.obsidianVault {
            Text(vault).truncationMode(.middle)
          }
        }
      }

      Section {
        ForEach(profile.apps, id: \.self) { bundleID in appRow(bundleID) }
        Button("Add Apps…") { model.addApps(to: name) }
      } header: {
        Text("Apps to Quit on Switch")
      } footer: {
        Text(
          "Quit when you switch to another profile. Not related to the Dock, which is "
            + "remembered as you arrange it. Apps listed in more than one profile are left alone."
        )
        .foregroundStyle(.secondary)
      }

      if let error = model.settingsError {
        Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
      }
    }
    .formStyle(.grouped)
    .onAppear { draftName = name }
  }

  private func commitName() {
    draftName =
      model.renameProfile(name, to: draftName).map { new in
        if new != name { onRename(new) }
        return new
      } ?? name
  }

  private var symbolGrid: some View {
    let selected = profile.symbol ?? MenuModel.defaultSymbol
    return LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 8), spacing: 6) {
      ForEach(Self.symbols, id: \.self) { symbol in
        Button {
          model.setSymbol(symbol, for: name)
        } label: {
          Image(systemName: symbol)
            .frame(width: 28, height: 28)
            .background(
              symbol == selected ? Color.accentColor.opacity(0.25) : .clear,
              in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(symbol)
      }
    }
  }

  private var wallpaperRow: some View {
    let path = model.wallpaper(for: name)
    let fullPath = path.map { ($0 as NSString).expandingTildeInPath }
    return HStack(spacing: 12) {
      Group {
        if let fullPath, let image = NSImage(contentsOfFile: fullPath) {
          Image(nsImage: image).resizable().scaledToFill()
        } else {
          Rectangle().fill(.quaternary)
        }
      }
      .frame(width: 128, height: 80)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      VStack(alignment: .leading) {
        Text(path.map { ($0 as NSString).lastPathComponent } ?? "None")
          .lineLimit(1).truncationMode(.middle)
        if name == model.state.current {
          Text("Changes apply now.").font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      Button("Choose…") { model.chooseWallpaper(for: name) }
    }
  }

  private func appRow(_ bundleID: String) -> some View {
    HStack {
      if let icon = model.appIcon(bundleID) {
        Image(nsImage: icon).resizable().frame(width: 20, height: 20)
      } else {
        Image(systemName: "questionmark.app.dashed").frame(width: 20, height: 20)
      }
      VStack(alignment: .leading) {
        Text(model.appName(bundleID))
        if model.appIcon(bundleID) == nil {
          Text("Not installed").font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      Button("Remove", systemImage: "minus.circle.fill") {
        model.removeApp(bundleID, from: name)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
    }
  }
}
