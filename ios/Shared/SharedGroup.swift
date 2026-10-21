import Foundation

/// Resigning services may substitute their own provisioned groups. Resolve an
/// accessible group from the installed profile instead of assuming our default.
enum SharedGroup {
  static func container() -> (identifier: String, url: URL)? {
    var candidates = [String]()
    if let configured = Bundle.main.object(forInfoDictionaryKey: "YIClassAppGroup") as? String {
      candidates.append(configured)
    }
    if let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
       let data = try? Data(contentsOf: profile), data.count < 5_000_000,
       let start = data.range(of: Data("<?xml".utf8)),
       let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
       let root = (try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], options: [], format: nil)) as? [String: Any],
       let entitlements = root["Entitlements"] as? [String: Any],
       let groups = entitlements["com.apple.security.application-groups"] as? [String] {
      candidates.append(contentsOf: groups.sorted())
    }
    for group in candidates where group.hasPrefix("group.") {
      if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
        return (group, url.appendingPathComponent("YIClass", isDirectory: true))
      }
    }
    return nil
  }
}
