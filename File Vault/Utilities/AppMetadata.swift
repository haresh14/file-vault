import Foundation

enum AppMetadata {
    static var versionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version?.nilIfBlank, build?.nilIfBlank) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), .none):
            return version
        default:
            return "Unknown"
        }
    }

    static var privacyPolicyURL: URL? {
        configuredHTTPSURL(forInfoDictionaryKey: "PrivacyPolicyURL")
    }

    static var supportURL: URL? {
        configuredHTTPSURL(forInfoDictionaryKey: "SupportURL")
    }

    private static func configuredHTTPSURL(forInfoDictionaryKey key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let text = value.nilIfBlank,
              !text.contains("$("),
              let url = URL(string: text),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        return url
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
