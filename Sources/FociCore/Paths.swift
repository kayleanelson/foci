import Foundation

public func expandingTilde(_ path: String, home: String) -> String {
  if path == "~" { return home }
  if path.hasPrefix("~/") { return home + path.dropFirst() }
  return path
}

/// Expanded, standardized, no trailing slash: the form two paths are compared in.
public func normalizedPath(_ path: String, home: String) -> String {
  URL(fileURLWithPath: expandingTilde(path, home: home)).standardizedFileURL.path
}
