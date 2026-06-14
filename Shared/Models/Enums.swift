import SwiftUI

/// The kind of content a saved item represents.
enum ContentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case article, video, audio, image, link, note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .article: return "Article"
        case .video:   return "Video"
        case .audio:   return "Audio"
        case .image:   return "Image"
        case .link:    return "Link"
        case .note:    return "Note"
        }
    }

    /// Plural label used for filter chips.
    var pluralTitle: String {
        switch self {
        case .article: return "Articles"
        case .video:   return "Videos"
        case .audio:   return "Audio"
        case .image:   return "Images"
        case .link:    return "Links"
        case .note:    return "Notes"
        }
    }

    var systemImage: String {
        switch self {
        case .article: return "doc.richtext"
        case .video:   return "play.rectangle.fill"
        case .audio:   return "waveform"
        case .image:   return "photo.fill"
        case .link:    return "link"
        case .note:    return "note.text"
        }
    }

    var tint: Color {
        switch self {
        case .article: return .typeArticle
        case .video:   return .typeVideo
        case .audio:   return .typeAudio
        case .image:   return .typeImage
        case .link:    return .typeLink
        case .note:    return .typeNote
        }
    }
}

/// The platform a piece of content originated from.
enum SourcePlatform: String, Codable, CaseIterable, Sendable {
    case instagram, twitter, tiktok, youtube, reddit, spotify, vimeo, linkedin, bluesky, facebook, threads, pinterest, mastodon, safari, other

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .twitter:   return "X"
        case .tiktok:    return "TikTok"
        case .youtube:   return "YouTube"
        case .reddit:    return "Reddit"
        case .spotify:   return "Spotify"
        case .vimeo:     return "Vimeo"
        case .linkedin:  return "LinkedIn"
        case .bluesky:   return "Bluesky"
        case .facebook:  return "Facebook"
        case .threads:   return "Threads"
        case .pinterest: return "Pinterest"
        case .mastodon:  return "Mastodon"
        case .safari:    return "Safari"
        case .other:     return "Web"
        }
    }

    var systemImage: String {
        switch self {
        case .instagram: return "camera.fill"
        case .twitter:   return "bird.fill"
        case .tiktok:    return "music.note"
        case .youtube:   return "play.rectangle.fill"
        case .reddit:    return "bubble.left.and.bubble.right.fill"
        case .spotify:   return "music.note.list"
        case .vimeo:     return "v.square.fill"
        case .linkedin:  return "briefcase.fill"
        case .bluesky:   return "cloud.fill"
        case .facebook:  return "f.square.fill"
        case .threads:   return "at"
        case .pinterest: return "pin.fill"
        case .mastodon:  return "number.square.fill"
        case .safari:    return "safari.fill"
        case .other:     return "globe"
        }
    }
}
