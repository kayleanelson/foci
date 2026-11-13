public enum Command: Equatable, Sendable {
  case status
  case switchTo(SwitchRequest)
  case captureDock(profile: String?)
  case followFocus(Bool)
  case help

  public static let usage = """
    usage: foci status
           foci switch <profile> [--force] [--source focus]
           foci capture-dock [<profile>]
           foci follow-focus on|off
    """

  public static func parse(_ arguments: [String]) throws -> Command {
    guard let verb = arguments.first else { return .help }
    let rest = Array(arguments.dropFirst())
    switch verb {
    case "status" where rest.isEmpty:
      return .status
    case "capture-dock" where rest.count <= 1:
      return .captureDock(profile: rest.first)
    case "follow-focus" where rest == ["on"] || rest == ["off"]:
      return .followFocus(rest == ["on"])
    case "switch":
      guard let target = rest.first, !target.hasPrefix("-") else { throw CommandError.usage }
      return .switchTo(try parseSwitch(target: target, options: rest.dropFirst()))
    case "help", "-h", "--help":
      guard rest.isEmpty else { throw CommandError.usage }
      return .help
    default:
      throw CommandError.usage
    }
  }

  private static func parseSwitch(target: String, options: ArraySlice<String>) throws
    -> SwitchRequest
  {
    var request = SwitchRequest(target: target)
    var options = options.makeIterator()
    while let option = options.next() {
      switch option {
      case "--force":
        request.force = true
      case "--source":
        guard let value = options.next(), let source = Source(rawValue: value) else {
          throw CommandError.usage
        }
        request.source = source
      default:
        throw CommandError.usage
      }
    }
    return request
  }
}

public enum CommandError: Error, Equatable {
  case usage
}
