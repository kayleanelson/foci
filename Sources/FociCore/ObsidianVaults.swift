import Foundation

/// Obsidian reopens every vault marked `"open": true` in its `obsidian.json` on launch, and
/// has no URL to close one. So switching vaults means quitting Obsidian, leaving only the
/// target marked open, and relaunching.
public enum ObsidianVaults {
  public static let bundleID = "md.obsidian"

  public static func openingOnly(vaultAt path: String, in data: Data) throws -> Data {
    guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ObsidianVaultsError.unreadable
    }
    let target = URL(fileURLWithPath: path).standardizedFileURL.path
    let vaults = root["vaults"] as? [String: Any] ?? [:]
    root["vaults"] = vaults.mapValues { value -> Any in
      guard var vault = value as? [String: Any] else { return value }
      let vaultPath = (vault["path"] as? String).map {
        URL(fileURLWithPath: $0).standardizedFileURL.path
      }
      if vaultPath == target { vault["open"] = true } else { vault.removeValue(forKey: "open") }
      return vault
    }
    return try JSONSerialization.data(withJSONObject: root)
  }

  public static func openURL(forVaultAt path: String) -> URL {
    var components = URLComponents()
    components.scheme = "obsidian"
    components.host = "open"
    components.queryItems = [URLQueryItem(name: "path", value: path)]
    return components.url!
  }
}

public enum ObsidianVaultsError: Error {
  case unreadable
}
