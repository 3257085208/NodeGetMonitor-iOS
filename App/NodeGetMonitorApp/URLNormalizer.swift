import Foundation

enum URLNormalizer {
    static func normalize(_ input: String) -> URL? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "https://" + value
        }

        guard var components = URLComponents(string: value), components.host != nil else {
            return nil
        }

        if components.path.isEmpty {
            components.path = "/"
        }

        return components.url
    }

    static func defaultName(for url: URL) -> String {
        url.host ?? url.absoluteString
    }
}
