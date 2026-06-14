import Foundation

extension URL {
    /// Cleaned host without "www." prefix.
    var prettyDomain: String? {
        guard let host = host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Google favicon service URL for this domain.
    var faviconURL: URL? {
        guard let host = host() else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
    }
}

extension String {
    /// Builds a URL from a possibly-incomplete user string, defaulting to https.
    var normalizedURL: URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }

    /// Finds the first web URL embedded anywhere in the string (e.g. a link shared
    /// alongside descriptive text, as LinkedIn and other apps do). Returns `nil`
    /// when there is no link to extract.
    var firstDetectedURL: URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        let match = detector.firstMatch(in: self, options: [], range: range)
        guard let url = match?.url, let scheme = url.scheme,
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}
