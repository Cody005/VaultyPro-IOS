import Foundation
import justhtml

/// Result of scraping a URL for display metadata. Value type so it crosses actor boundaries safely.
struct FetchedMetadata: Sendable {
    var url: String
    var title: String?
    var description: String?
    var imageURL: String?
    var siteName: String?
    var faviconURL: String?
    var sourceDomain: String?
    var contentType: ContentType
    var platform: SourcePlatform
    var fullText: String?
    var rawHTML: String?
    var estimatedReadTime: Int?
}

/// Scrapes OpenGraph metadata, resolves YouTube/oEmbed, and prepares a `FetchedMetadata`.
actor MetadataFetcher {
    static let shared = MetadataFetcher()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.httpShouldSetCookies = true
        return config.urlSession
    }()

    // Social sites gate generic clients (JS shells, bot-walls) but serve rich OpenGraph
    // cards to known crawlers. We pick a User-Agent per platform, with a fallback.
    nonisolated static let browserUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
    nonisolated static let crawlerUA = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"
    nonisolated static let twitterUA = "Twitterbot/1.0"
    nonisolated static let linkedInUA = "LinkedInBot/1.0 (compatible; Mozilla/5.0; Apache-HttpClient +http://www.linkedin.com)"

    nonisolated static func userAgent(for platform: SourcePlatform) -> String {
        switch platform {
        case .twitter:                     return twitterUA
        case .linkedin:                    return linkedInUA
        case .reddit, .instagram, .tiktok, .facebook, .threads, .pinterest: return crawlerUA
        default:                           return browserUA
        }
    }

    /// Detects bot-wall / JS-shell interstitials so we can retry with a different UA.
    nonisolated static func looksBlocked(_ html: String) -> Bool {
        if html.count < 512 { return true }
        let lower = html.prefix(4000).lowercased()
        return lower.contains("please wait")
            || lower.contains("verifying you are human")
            || lower.contains("verify you are human")
            || lower.contains("/cdn-cgi/challenge")
            || lower.contains("captcha-delivery")
    }

    func fetch(urlString: String) async -> FetchedMetadata {
        guard let url = urlString.normalizedURL else {
            return FetchedMetadata(url: urlString, contentType: .note, platform: .other)
        }

        let platform = Self.detectPlatform(url)
        let domain = url.prettyDomain
        var meta = FetchedMetadata(
            url: url.absoluteString,
            sourceDomain: domain,
            contentType: .link,
            platform: platform
        )
        meta.faviconURL = url.faviconURL?.absoluteString

        // YouTube → use thumbnail + oEmbed title (no HTML scrape needed).
        if platform == .youtube, let videoID = Self.youTubeVideoID(url) {
            meta.contentType = .video
            meta.imageURL = "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg"
            if let oembed = await fetchOEmbed(for: url) {
                meta.title = oembed.title
                meta.imageURL = oembed.thumbnailURL ?? meta.imageURL
                meta.siteName = oembed.providerName
            }
            return meta
        }

        // X/Twitter serves only a JS shell to crawlers now (no OG tags). Its public
        // syndication endpoint needs no auth (any non-empty token works) and returns the
        // author, tweet text, and media — everything we need for a rich card.
        if platform == .twitter {
            await applyTwitterSyndication(&meta, url: url)
            if meta.title == nil { await applyTwitterOEmbed(&meta, url: url) }
            if meta.title?.isEmpty ?? true { meta.title = domain }
            return meta
        }

        // Fetch with the platform's preferred UA, retrying with the alternate UA if the
        // first response is missing or looks like a bot-wall / JS shell.
        let primaryUA = Self.userAgent(for: platform)
        let fallbackUA = primaryUA == Self.browserUA ? Self.crawlerUA : Self.browserUA
        var html = await fetchHTML(url, userAgent: primaryUA)
        if html == nil || Self.looksBlocked(html!) {
            if let alt = await fetchHTML(url, userAgent: fallbackUA) { html = alt }
        }

        if let html, let doc = try? JustHTML(html) {
            meta.rawHTML = html
            meta.title = ogContent(doc, "og:title") ?? ogContent(doc, "twitter:title") ?? pageTitle(doc)
            meta.description = ogContent(doc, "og:description") ?? ogContent(doc, "twitter:description") ?? metaName(doc, "description")
            meta.imageURL = ogContent(doc, "og:image") ?? ogContent(doc, "twitter:image") ?? firstImage(doc, base: url)
            meta.siteName = ogContent(doc, "og:site_name") ?? domain

            let plain = bodyText(doc)
            meta.fullText = plain
            let words = plain.split { $0 == " " || $0 == "\n" }.count
            meta.estimatedReadTime = max(1, words / 200)
            meta.contentType = Self.detectContentType(url: url, html: html, platform: platform)
        }

        if meta.title?.isEmpty ?? true { meta.title = domain }
        return meta
    }

    func downloadImageData(from urlString: String?) async -> Data? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        if let data = try? await session.data(from: url).0, !data.isEmpty {
            return data
        }
        return nil
    }

    // MARK: - HTML / oEmbed

    private func fetchHTML(_ url: URL, userAgent: String) async -> String? {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        guard let (data, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode)
        else { return nil }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private struct TwitterOEmbed: Decodable {
        let authorName: String?
        let html: String?
        enum CodingKeys: String, CodingKey {
            case authorName = "author_name"
            case html
        }
        var tweetText: String? {
            guard let html, let doc = try? JustHTML(html),
                  let p = (try? doc.query("p"))?.first?.toText()
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !p.isEmpty
            else { return nil }
            return p
        }
    }

    private struct TweetResult: Decodable {
        let text: String?
        let user: TweetUser?
        let mediaDetails: [TweetMedia]?
        struct TweetUser: Decodable {
            let name: String?
            let screenName: String?
            let profileImageURL: String?
            enum CodingKeys: String, CodingKey {
                case name
                case screenName = "screen_name"
                case profileImageURL = "profile_image_url_https"
            }
        }
        struct TweetMedia: Decodable {
            let type: String?
            let mediaURL: String?
            enum CodingKeys: String, CodingKey {
                case type
                case mediaURL = "media_url_https"
            }
        }
    }

    /// Extracts the numeric tweet id from a `.../status/<id>` (or `/statuses/`) URL.
    nonisolated static func tweetID(_ url: URL) -> String? {
        let parts = url.pathComponents
        guard let i = parts.firstIndex(where: { $0 == "status" || $0 == "statuses" }),
              i + 1 < parts.count else { return nil }
        let digits = parts[i + 1].prefix { $0.isNumber }
        return digits.isEmpty ? nil : String(digits)
    }

    private func applyTwitterSyndication(_ meta: inout FetchedMetadata, url: URL) async {
        guard let id = Self.tweetID(url),
              let endpoint = URL(string: "https://cdn.syndication.twimg.com/tweet-result?id=\(id)&lang=en&token=a"),
              let data = try? await session.data(from: endpoint).0,
              let tweet = try? JSONDecoder().decode(TweetResult.self, from: data)
        else { return }

        let text = tweet.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let author = tweet.user?.name {
            meta.title = (text?.isEmpty == false) ? "\(author) on X: \(text!)" : "\(author) on X"
        } else if let text, !text.isEmpty {
            meta.title = text
        }
        if meta.description == nil, let text, !text.isEmpty { meta.description = text }
        meta.siteName = "X"

        if let media = tweet.mediaDetails?.first {
            if let img = media.mediaURL { meta.imageURL = img }
            if media.type == "video" || media.type == "animated_gif" { meta.contentType = .video }
        } else if meta.imageURL == nil, let avatar = tweet.user?.profileImageURL {
            meta.imageURL = avatar
        }
    }

    private func applyTwitterOEmbed(_ meta: inout FetchedMetadata, url: URL) async {
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let endpoint = URL(string: "https://publish.twitter.com/oembed?url=\(encoded)&omit_script=true&dnt=true"),
              let data = try? await session.data(from: endpoint).0,
              let oembed = try? JSONDecoder().decode(TwitterOEmbed.self, from: data)
        else { return }
        let text = oembed.tweetText
        if let author = oembed.authorName {
            meta.title = text.map { "\(author) on X: \($0)" } ?? "\(author) on X"
        } else if let text {
            meta.title = text
        }
        if meta.description == nil { meta.description = text }
    }

    private struct OEmbed: Decodable {
        let title: String?
        let thumbnailURL: String?
        let providerName: String?
        enum CodingKeys: String, CodingKey {
            case title
            case thumbnailURL = "thumbnail_url"
            case providerName = "provider_name"
        }
    }

    private func fetchOEmbed(for url: URL) async -> OEmbed? {
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let endpoint = URL(string: "https://www.youtube.com/oembed?url=\(encoded)&format=json"),
              let data = try? await session.data(from: endpoint).0
        else { return nil }
        return try? JSONDecoder().decode(OEmbed.self, from: data)
    }

    // MARK: - Parsing helpers (justhtml)

    private func ogContent(_ doc: JustHTML, _ property: String) -> String? {
        // OpenGraph tags use `property`; some sites mirror them on `name`.
        let nodes = (try? doc.query("meta[property=\"\(property)\"]")) ?? []
        let fallback = (try? doc.query("meta[name=\"\(property)\"]")) ?? []
        let content = (nodes.first ?? fallback.first)?.attrs["content"]
        return content.flatMap { $0.isEmpty ? nil : $0 }
    }

    private func metaName(_ doc: JustHTML, _ name: String) -> String? {
        let nodes = (try? doc.query("meta[name=\"\(name)\"]")) ?? []
        let content = nodes.first?.attrs["content"]
        return content.flatMap { $0.isEmpty ? nil : $0 }
    }

    private func pageTitle(_ doc: JustHTML) -> String? {
        let title = (try? doc.query("title"))?.first?.toText().trimmingCharacters(in: .whitespacesAndNewlines)
        return title.flatMap { $0.isEmpty ? nil : $0 }
    }

    private func bodyText(_ doc: JustHTML) -> String {
        ((try? doc.query("body"))?.first)?.toText() ?? ""
    }

    private func firstImage(_ doc: JustHTML, base: URL) -> String? {
        guard let src = (try? doc.query("img[src]"))?.first?.attrs["src"], !src.isEmpty else { return nil }
        return Self.resolveURL(src, base: base)
    }

    /// Resolves a possibly-relative URL against the page's base URL.
    nonisolated static func resolveURL(_ href: String, base: URL) -> String {
        if href.hasPrefix("http://") || href.hasPrefix("https://") { return href }
        if href.hasPrefix("//") { return (base.scheme ?? "https") + ":" + href }
        return URL(string: href, relativeTo: base)?.absoluteString ?? href
    }

    // MARK: - Detection (nonisolated, pure)

    nonisolated static func detectPlatform(_ url: URL) -> SourcePlatform {
        let host = url.host()?.lowercased() ?? ""
        if host.contains("instagram.com") { return .instagram }
        if host.contains("twitter.com") || host.contains("x.com") { return .twitter }
        if host.contains("tiktok.com") { return .tiktok }
        if host.contains("youtube.com") || host.contains("youtu.be") { return .youtube }
        if host.contains("reddit.com") { return .reddit }
        if host.contains("spotify.com") { return .spotify }
        if host.contains("vimeo.com") { return .vimeo }
        if host.contains("linkedin.com") || host.contains("lnkd.in") { return .linkedin }
        if host.contains("bsky.app") || host.contains("bsky.social") { return .bluesky }
        if host.contains("threads.net") || host.contains("threads.com") { return .threads }
        if host.contains("facebook.com") || host.contains("fb.watch") { return .facebook }
        if host.contains("pinterest.com") || host.contains("pin.it") { return .pinterest }
        return .other
    }

    nonisolated static func detectContentType(url: URL, html: String?, platform: SourcePlatform) -> ContentType {
        let host = url.host()?.lowercased() ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") || host.contains("vimeo.com") { return .video }
        if host.contains("spotify.com") || host.contains("podcasts.apple.com") { return .audio }
        switch platform {
        case .instagram, .twitter, .tiktok, .reddit, .linkedin, .bluesky, .facebook, .threads, .pinterest:
            return .link
        default: break
        }
        let lowerPath = url.lastPathComponent.lowercased()
        if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains((lowerPath as NSString).pathExtension) { return .image }
        if let html, html.contains("<article") || html.contains("\"articleBody\"") || html.contains("og:type\" content=\"article") {
            return .article
        }
        return .link
    }

    nonisolated static func youTubeVideoID(_ url: URL) -> String? {
        let host = url.host()?.lowercased() ?? ""
        if host.contains("youtu.be") {
            return url.pathComponents.dropFirst().first
        }
        if host.contains("youtube.com") {
            if url.path.hasPrefix("/shorts/") { return url.pathComponents.last }
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "v" })?.value
        }
        return nil
    }
}

private extension URLSessionConfiguration {
    var urlSession: URLSession { URLSession(configuration: self) }
}
