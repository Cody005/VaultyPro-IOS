# VaultyPro

A premium **save-it-later / read-watch-listen-later** iOS 26 app. Share content to VaultyPro from any app (Instagram, X, TikTok, YouTube, Safari, Reddit, newsletters…) and it captures URLs, metadata, thumbnails, titles, descriptions and article text — your universal content inbox.

Built with **SwiftUI · SwiftData · iOS 26 Liquid Glass · Swift 6 strict concurrency**.

---

## Requirements

- Xcode 26+
- iOS 26 SDK / simulator (built & verified on **iPhone 17 Pro Max**)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml`

## Generate & build

```bash
xcodegen generate
open VaultyPro.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project VaultyPro.xcodeproj -scheme VaultyPro \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  CODE_SIGNING_ALLOWED=NO build
```

> The project regenerates from `project.yml`. If you add/rename files, re-run `xcodegen generate`.

## Dependencies

- **[swift-justhtml](https://github.com/kylehowells/swift-justhtml)** (`0.4.6`) — pure-Swift, zero-dependency, HTML5-spec-compliant parser used for OpenGraph scraping (`MetadataFetcher`) and article reader extraction (`ContentParser`). Resolved automatically via SPM.

## Project layout

```
VaultyPro/            App target (Views, ViewModels, app-only Services, Assets)
Shared/               Code shared by app + Share Extension (Models, Persistence,
                      MetadataFetcher, ItemSaver, shared Components, Extensions)
ShareExtension/       Share sheet extension (ShareViewController + SwiftUI ShareView)
tools/                make_icon.swift (regenerates the app icon)
AppStoreMetadata/     Store listing copy + screenshot notes
project.yml           XcodeGen project definition
```

---

## ⚙️ Configure before shipping

These default to values that **build and run in the Simulator unsigned**. Change them for a real device / App Store build:

1. **Team & signing** — set `DEVELOPMENT_TEAM` in `project.yml` (currently empty), then `xcodegen generate`.
2. **App Group** — update `AppConfig.appGroupID` in `Shared/AppConfig.swift` **and** both `*.entitlements` files to `group.<your-team>.vaultypro`. The app and extension must match so they share one SwiftData store.
   - *Note:* unsigned in the Simulator the App Group container is unavailable, so `Persistence` transparently falls back to a local store. The main app still works; the extension only shares data once signing + the App Group are configured.
3. **iCloud / CloudKit** — set `AppConfig.cloudKitEnabled = true`, add the iCloud capability + a CloudKit container to the app target, then `xcodegen generate`. (Off by default so it runs without a paid account.)
4. **StoreKit** — create the products in App Store Connect (or a local `.storekit` file) matching the IDs in `AppConfig.Product` (`com.vaultypro.pro.monthly`, `com.vaultypro.pro.annual`).
5. **Custom app icons** — the Settings icon picker calls `setAlternateIconName`. Add `AppIcon-Navy` / `AppIcon-Violet` image sets and list them under `CFBundleAlternateIcons` to enable the extra variants (the picker fails gracefully until then).

---

## Features

- **Share Extension** — Liquid Glass save sheet with thumbnail preview, editable title, tag chips, collection picker. Handles URLs, text and images; YouTube links resolve thumbnails + oEmbed titles.
- **Home / Inbox** — greeting hero, type filter chips, masonry grid or list, context-menu actions, Liquid Glass Quick Add.
- **Collections** — smart collections (Unread, Videos, Articles, Saved Today, Favorites) + user collections with cover mosaics.
- **Search** — full-text across titles, descriptions, URLs, tags, notes with recents and filters (Pro-gated).
- **Detail** — immersive article reader (adjustable font/spacing/background), YouTube player, pinch-zoom images, audio bar, highlights, notes, full action bar.
- **Settings** — iCloud status, storage breakdown, appearance, app-icon picker, Import (Raindrop/Instapaper/Pinboard) & Export (JSON/CSV), subscription.
- **Onboarding & Paywall**, **StoreKit 2** Pro gating, seeded demo content on first launch.

## Design system

Deep navy + warm amber + cream palette, SF Pro typography, 20pt corner cards, gradient thumbnail overlays, skeleton shimmer loading, press micro-interactions, and native iOS 26 Liquid Glass on floating chrome. See `Shared/Extensions/Color+Hex.swift` and `Shared/AppConfig.swift`.
