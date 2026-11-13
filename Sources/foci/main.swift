import FociCore
import FociSystem
import Foundation

func fail(_ message: String, code: Int32) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(code)
}

@MainActor
func execute(_ command: Command) async throws -> Int32 {
  let store = FileStore()
  switch command {
  case .help:
    print(Command.usage)
  case .status:
    let config = try store.loadConfig()
    let state = try store.loadState()
    print("current:      \(state.current ?? "none")")
    print("follow focus: \(state.followFocus ? "on" : "off")")
    print("profiles:     \(config.profileNames.joined(separator: ", "))")
  case .followFocus(let on):
    var state = try store.loadState()
    state.followFocus = on
    try store.saveState(state)
    print("follow focus \(on ? "on" : "off")")
  case .captureDock(let profile):
    let config = try store.loadConfig()
    guard let name = try profile ?? store.loadState().current else {
      fail("no current profile; name one: foci capture-dock <profile>", code: 64)
    }
    _ = try config.profile(name)
    let snapshot = DockLayout.snapshot(of: try MacSystem().readDockPrefs())
    try store.saveDock(DockLayout.encode(snapshot), for: name)
    print("saved the current Dock as \(name)'s")
  case .switchTo(let request):
    let switcher = Switcher(
      config: try store.loadConfig(), system: MacSystem(), store: store,
      home: FileManager.default.homeDirectoryForCurrentUser.path)
    let report = try await switcher.run(request)
    switch report.outcome {
    case .switched: print("switched to \(request.target)")
    case .skipped(let reason): print("skipped: \(reason)")
    }
    for problem in report.problems { print("  ! \(problem)") }
    return report.problems.isEmpty ? 0 : 1
  }
  return 0
}

let command: Command
do {
  command = try Command.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
  fail(Command.usage, code: 64)
}

// A spinning run loop keeps AppKit's workspace state current.
Task { @MainActor in
  do {
    exit(try await execute(command))
  } catch {
    fail("foci: \(error)", code: 1)
  }
}
RunLoop.main.run()
