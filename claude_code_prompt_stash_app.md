# Claude Code Prompt — "Stash" iOS App

> Paste this entire prompt into Claude Code to scaffold the project.

> **Implementation note (updated):** This spec was implemented and **shipped as "VaultyPro"** (the brand the owner chose). The codebase in this repo reflects that. Two things were updated from the original draft after a toolchain review:
> - **HTML parsing uses [`swift-justhtml`](https://github.com/kylehowells/swift-justhtml)** (pure-Swift, zero-dependency, HTML5-spec compliant) instead of SwiftSoup — see `MetadataFetcher`/`ContentParser`.
> - **App Group is `group.com.vaultypro.app`** (placeholder; change to `group.<YOURTEAMID>.vaultypro` when signing). CloudKit is opt-in via `AppConfig.cloudKitEnabled` so the app runs unsigned in the Simulator.
> Built and verified on **Xcode 26.5 / iOS 26 Simulator (iPhone 17 Pro Max)** with Swift 6 strict concurrency. See `README.md`.

---

## Project Overview

Build a **production-ready iOS 26 app called "Stash"** — a premium save-it-later / read-watch-listen-later app. Users share content to it from any app (Instagram, X/Twitter, TikTok, YouTube, Safari, Reddit, newsletters, etc.) and Stash captures everything: URLs, metadata, thumbnails, titles, descriptions, video embeds, audio, article text. It's a universal content inbox.

This is **App Store bound**. Every screen, component, and interaction must be production-quality. Think Readwise Reader meets Raindrop.io — but native iOS 26 with Liquid Glass.

---

## Tech Stack

- **Language:** Swift 6 (strict concurrency)
- **UI Framework:** SwiftUI (iOS 26 SDK, Xcode 26)
- **Design Language:** iOS 26 Liquid Glass — use `.glassEffect()` modifier, `GlassEffectContainer`, and native `glassBackground` material. Navigation bars, tab bars, and floating buttons get Liquid Glass automatically. Do NOT fight the system; embrace it.
- **Persistence:** SwiftData + CloudKit (iCloud sync across devices)
- **Networking:** Swift async/await, URLSession
- **Metadata fetching:** OpenGraph scraping + YouTube Data API v3 for videos
- **Share Extension:** `ShareViewController` with SwiftUI overlay (App Group shared container)
- **Minimum Deployment:** iOS 26.0 (iPhone 11 / A13 Bionic+)
- **Architecture:** MVVM + `@Observable` macro (no ObservableObject)

---

## App Features — Full Scope

### 1. Share Extension (most critical feature)
- Appears in the iOS Share Sheet from ANY app
- Accepts: URLs, plain text, images, files, videos
- On share, immediately show a beautiful Liquid Glass overlay sheet:
  - Thumbnail preview (fetched or extracted)
  - Editable title field (pre-filled from metadata)
  - Tag chips picker (existing tags + create new)
  - Collection selector (dropdown)
  - "Save" button — saves instantly and dismisses
- The extension and main app share a SwiftData store via App Group (`group.com.yourapp.stash`)
- Handle edge cases: YouTube URLs extract video ID and fetch thumbnail via `https://img.youtube.com/vi/{id}/maxresdefault.jpg`; Instagram/TikTok/X posts save URL + any available OG metadata; plain text saves as a note card

### 2. Main App — Tab Structure (iOS 26 tab bar with Liquid Glass)

**Tab 1: Home (Inbox)**
- Hero header with greeting and saved-today count
- Horizontal filter chips: All · Articles · Videos · Audio · Images · Links · Notes
- Two layout modes: Card Grid (masonry-style, 2-col) and List view
- Each card shows: thumbnail, source favicon + domain, title (2 lines max), time saved, type badge, read/unread indicator
- Swipe left on card: Archive · Delete
- Swipe right on card: Mark read · Add to collection
- Pull to refresh
- "Quick Add" floating button (Liquid Glass pill) for manually pasting a URL

**Tab 2: Collections**
- User-created collections (like folders/playlists)
- Default smart collections auto-created: "Unread", "Videos", "Articles", "Saved Today", "Favorites"
- Grid of collection cards with cover mosaic (4 latest thumbnails tiled)
- Long-press to rename/delete/reorder

**Tab 3: Search**
- Full-text search across titles, descriptions, URLs, tags, notes
- Recent searches list
- Filter bar: by type, by collection, by date range, by read status
- Results in card list, highlight matching terms

**Tab 4: Profile / Settings**
- iCloud sync status + last sync time
- Storage used (breakdown by type)
- Import: from Raindrop.io (JSON), Instapaper (HTML), Pinboard (XML)
- Export: JSON, CSV
- Appearance: System / Light / Dark
- App icon picker (3 variants)
- Subscription status (Stash Free vs Stash Pro)

### 3. Content Detail View
- Full-screen immersive reader for articles (parsed with swift-justhtml)
- Video player for YouTube embeds (WKWebView with YouTube iframe API)
- Image viewer with pinch-zoom
- Audio player bar (for podcast/audio links)
- Action bar at bottom: Mark Read · Favorite · Share · Copy URL · Open in Browser · Add Note · Move to Collection · Archive · Delete
- Reader settings: font size slider, font choice (System / Serif / Mono), line spacing, background (White / Sepia / Dark)
- Notes field below content (user can annotate)
- Highlights: tap-hold on article text to highlight in yellow/blue/green/pink

### 4. Onboarding (first launch only)
- 3-screen carousel (SwiftUI TabView with `.tabViewStyle(.page)`)
- Screen 1: App intro, hero animation of the Stash icon
- Screen 2: "Share from anywhere" — show the iOS share sheet flow with arrow annotation
- Screen 3: iCloud sync opt-in + notification permission request
- Skip button always visible

---

## Data Model (SwiftData)

```swift
@Model
class StashItem {
    var id: UUID
    var url: String?
    var title: String
    var itemDescription: String?
    var thumbnailURL: String?
    var thumbnailData: Data?          // cached locally
    var faviconURL: String?
    var sourceDomain: String?
    var contentType: ContentType      // article, video, audio, image, link, note
    var rawHTML: String?              // for article reader
    var fullText: String?             // stripped plain text for search
    var savedAt: Date
    var readAt: Date?
    var isFavorite: Bool
    var isArchived: Bool
    var tags: [String]
    var userNote: String?
    var highlights: [Highlight]
    var collection: Collection?
    var readingProgress: Double       // 0.0–1.0
    var estimatedReadTime: Int?       // minutes
    var platform: SourcePlatform?     // instagram, twitter, youtube, tiktok, etc.
}

@Model
class Collection {
    var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var createdAt: Date
    var isSmart: Bool
    var smartFilter: String?          // NSPredicate string for smart collections
    var sortOrder: Int
    @Relationship(deleteRule: .nullify) var items: [StashItem]
}

@Model
class Highlight {
    var id: UUID
    var text: String
    var colorHex: String
    var createdAt: Date
    var itemID: UUID
}

enum ContentType: String, Codable, CaseIterable {
    case article, video, audio, image, link, note
}

enum SourcePlatform: String, Codable {
    case instagram, twitter, tiktok, youtube, reddit, safari, other
}
```

---

## Design System — NON-NEGOTIABLE

> This is the heart of the brief. Generic AI-style design is rejected. Every pixel must feel intentional.

### Color Palette
Use a **deep navy + warm amber + soft cream** palette with semantic roles:

```swift
extension Color {
    // Primaries
    static let stashNavy    = Color(hex: "#0D1B2A")   // deep navy — primary BG in dark
    static let stashAmber   = Color(hex: "#F4A261")   // warm amber — accent / CTAs
    static let stashCream   = Color(hex: "#F8F4EE")   // warm cream — primary BG in light
    
    // Semantic
    static let stashSurface = Color(hex: "#1A2A3A")   // card surface dark
    static let stashMuted   = Color(hex: "#6B7C93")   // secondary text
    static let stashGreen   = Color(hex: "#52B788")   // success / read indicator
    static let stashRed     = Color(hex: "#E76F51")   // delete / destructive
    
    // Type badges
    static let typeArticle  = Color(hex: "#4ECDC4")
    static let typeVideo    = Color(hex: "#FF6B6B")
    static let typeAudio    = Color(hex: "#A8DADC")
    static let typeImage    = Color(hex: "#C77DFF")
    static let typeLink     = Color(hex: "#F4A261")
    static let typeNote     = Color(hex: "#95D5B2")
}
```

### Typography
```swift
// Title — SF Pro Display, weight .bold, size 28
// Section header — SF Pro Rounded, weight .semibold, size 17
// Card title — SF Pro Text, weight .medium, size 15
// Metadata — SF Pro Text, weight .regular, size 12, opacity 0.6
// Badge — SF Pro Text, weight .semibold, size 10, all caps
```

### Card Design
Each StashItem card is a standalone, rich component:
- Rounded corners: `cornerRadius(20)`
- Thumbnail: `aspectRatio(16/9)`, fills top of card, with a subtle gradient overlay fading to card background
- Source row: 16pt favicon circle + domain name in muted text + "· Xm ago" time
- Title: max 2 lines, truncated with `.lineLimit(2)`
- Type badge: pill shape, colored by type, bottom-left of thumbnail
- Read indicator: small green dot (unread = amber dot) top-right corner
- Shadow: `shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)`
- Unread cards have a subtle left border accent in amber

### Empty States
Every empty state must have:
- A large SF Symbol icon (size 64) with a soft gradient tint
- A headline (e.g. "Nothing saved yet")
- A subtext line (e.g. "Tap Share → Stash from any app to save something")
- An optional CTA button

### Loading States
- Skeleton shimmer cards using `redacted(.placeholder)` + shimmer animation overlay
- Show 6 skeleton cards on initial load

### Animations
- Card appear: `.transition(.move(edge: .bottom).combined(with: .opacity))` with staggered delay
- Tab switch: default iOS 26 morphing tab bar
- Share extension appear: `.transition(.move(edge: .bottom))` spring animation
- Delete: swipe-to-delete with red background reveal
- Liquid Glass buttons on floating elements: use `.glassEffect()` from iOS 26 SDK

---

## File / Folder Structure

```
Stash/
├── StashApp.swift
├── ContentView.swift              # Root TabView
│
├── Models/
│   ├── StashItem.swift
│   ├── Collection.swift
│   ├── Highlight.swift
│   └── Enums.swift
│
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── CollectionsViewModel.swift
│   ├── SearchViewModel.swift
│   └── DetailViewModel.swift
│
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── StashCardView.swift        # card component
│   │   ├── CardGridView.swift
│   │   ├── CardListView.swift
│   │   └── FilterChipsView.swift
│   ├── Collections/
│   │   ├── CollectionsView.swift
│   │   └── CollectionDetailView.swift
│   ├── Search/
│   │   └── SearchView.swift
│   ├── Detail/
│   │   ├── ItemDetailView.swift
│   │   ├── ArticleReaderView.swift
│   │   ├── VideoPlayerView.swift
│   │   └── ReaderSettingsSheet.swift
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/
│       ├── TypeBadgeView.swift
│       ├── SkeletonCardView.swift
│       ├── EmptyStateView.swift
│       ├── TagChipView.swift
│       └── QuickAddView.swift
│
├── Services/
│   ├── MetadataFetcher.swift          # OG scraping, YouTube API
│   ├── ContentParser.swift            # HTML → plain text (swift-justhtml)
│   ├── CloudKitSyncMonitor.swift
│   ├── ImportService.swift            # Raindrop/Instapaper/Pinboard parsers
│   └── ExportService.swift
│
├── Extensions/
│   ├── Color+Hex.swift
│   ├── Date+Relative.swift
│   ├── URL+Domain.swift
│   └── View+Shimmer.swift
│
└── ShareExtension/
    ├── ShareViewController.swift
    ├── ShareView.swift                # SwiftUI share sheet UI
    └── Info.plist
```

---

## Key Implementation Notes

### Metadata Fetching (`MetadataFetcher.swift`)
```swift
// For every URL saved:
// 1. Fetch the page HTML (async)
// 2. Parse <meta property="og:title">, og:description, og:image, og:site_name
// 3. If YouTube URL: extract videoId, build thumbnail URL, fetch title from oEmbed
//    GET https://www.youtube.com/oembed?url={url}&format=json
// 4. If Twitter/X: parse og:title (usually "Name on X: ...")
// 5. Fallback: use <title> tag and first <img> found
// 6. Download thumbnail to Data and cache in SwiftData
// 7. Estimate reading time: wordCount / 200 words-per-minute
```

### Share Extension App Group
```swift
// In both app and extension targets, add capability:
// App Groups: group.com.YOURTEAMID.stash
//
// In ShareView.swift:
let modelContainer = try! ModelContainer(
    for: StashItem.self, Collection.self, Highlight.self,
    configurations: ModelConfiguration(
        url: FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.YOURTEAMID.stash")!
            .appendingPathComponent("stash.store")
    )
)
```

### SwiftData + CloudKit
```swift
// In StashApp.swift:
.modelContainer(for: [StashItem.self, Collection.self, Highlight.self],
    configurations: ModelConfiguration(cloudKitDatabase: .automatic))
```

### iOS 26 Liquid Glass
```swift
// Floating Quick Add button:
Button { showQuickAdd = true } label: {
    Label("Save", systemImage: "plus")
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
}
.glassEffect()  // iOS 26 automatic Liquid Glass

// Navigation bar: leave default — it auto-adopts Liquid Glass when compiled with iOS 26 SDK

// Tab bar: leave default TabView — it auto-adopts Liquid Glass

// Custom glass card surface (NOT for content cards — only chrome/controls):
.background(.regularMaterial)
```

### Content Type Detection
```swift
func detectContentType(url: URL, html: String?) -> ContentType {
    let host = url.host?.lowercased() ?? ""
    if host.contains("youtube.com") || host.contains("youtu.be") || host.contains("vimeo.com") { return .video }
    if host.contains("spotify.com") || host.contains("podcasts.apple.com") { return .audio }
    if host.contains("instagram.com") || host.contains("twitter.com") || host.contains("x.com") || host.contains("tiktok.com") { return .link }
    if let html, html.contains("<article") || html.contains("article:") { return .article }
    return .link
}
```

---

## Subscription / Monetization (StoreKit 2)

**Free tier:**
- Save up to 50 items
- 3 collections max
- No full-text search
- No highlights
- No import/export

**Stash Pro — $2.99/month or $24.99/year:**
- Unlimited items
- Unlimited collections
- Full-text search
- Highlights with color + export to Readwise
- Import / Export
- Custom app icon

Implement with StoreKit 2's `Product.products(for:)` and `Transaction.currentEntitlements`. Gate features with a `@Observable ProStatusManager` that checks entitlements on launch and after purchase.

Show paywall as a sheet triggered on hitting limits. Paywall design: gradient hero, feature list with checkmarks, two CTA buttons (monthly / annual), "Restore Purchases" text button at bottom.

---

## App Store Metadata (prepare these files)

Create `AppStoreMetadata/` folder with:
- `description.txt` — 4000-char App Store description
- `keywords.txt` — 100 char keyword string
- `screenshots_notes.md` — instructions for 6.9" screenshots (iPhone 16 Pro Max): what each of 5 frames should show

---

## Build Checklist Before First Run

1. Add App Group capability to both targets (main app + ShareExtension)
2. Add iCloud + CloudKit capability to main app target
3. Configure `NSExtensionActivationRule` in ShareExtension Info.plist to accept `public.url`, `public.plain-text`, `public.image`, `public.movie`
4. Add `NSUserTrackingUsageDescription` to Info.plist (even if not tracking — App Store review may require it)
5. Add `NSPhotoLibraryUsageDescription` if reading from Photos
6. HTML parser: add via Swift Package Manager `https://github.com/kylehowells/swift-justhtml` (module `justhtml`). *(Original draft suggested SwiftSoup; swift-justhtml was chosen for zero dependencies + HTML5 spec compliance.)*
7. Set `SWIFT_STRICT_CONCURRENCY = complete` in build settings

---

## What "Premium Design" Means Here

**Do:**
- Use large, bold section titles (SF Pro Display Bold 28–34pt)
- Give every screen breathing room (generous padding: 20pt horizontal)
- Use micro-animations on every tap (`.scaleEffect` on press: 0.96)
- Thumbnail images get a subtle gradient overlay so text is always readable
- Empty states are never just a label — they're illustrated moments
- Buttons have clear hierarchy: primary (amber fill), secondary (glass), tertiary (text-only)
- Every list row has a favicon, visual, or color — no plain text rows
- Skeleton loading states always, never a spinner on main content areas

**Don't:**
- No plain white backgrounds with black text (use cream/navy system colors)
- No generic SF Symbol grids as placeholder art — use actual card content
- No `.listStyle(.plain)` with dividers — use custom card rows with `.listStyle(.sidebar)` or custom ScrollView
- No default blue tint color — always use stashAmber as accent
- No flat action sheets — use custom `.sheet` with drag handles and proper padding

---

## Final Instructions to Claude Code

1. Scaffold the full project structure above
2. Implement every View file listed — no `// TODO` stubs left behind
3. The app must compile and run on iOS 26 Simulator with Xcode 26 with zero errors
4. Seed 8–10 realistic demo items (mix of article, video, YouTube, Instagram, X post) so no screen ever looks empty on first launch
5. All SF Symbols used must exist in SF Symbols 6 (iOS 26 ships with SF Symbols 6)
6. After scaffolding, run a quick self-review: check every view has a non-empty preview, every ViewModel has at least one `@Query` or `@Observable` state driving UI, and the Share Extension compiles in isolation
7. Add a `README.md` at the root with setup instructions (App Group ID to change, iCloud container, StoreKit product IDs to configure)

