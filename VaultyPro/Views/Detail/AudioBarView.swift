import SwiftUI

/// Decorative audio player bar for podcast/audio links (opens source for full playback).
struct AudioBarView: View {
    let item: StashItem
    @Environment(\.openURL) private var openURL
    @State private var progress: Double = 0.3
    @State private var playing = false

    var body: some View {
        VStack(spacing: 14) {
            ThumbnailView(data: item.thumbnailData, urlString: item.thumbnailURL, contentType: .audio)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: 220).frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)

            ProgressView(value: progress).tint(Color.stashAmber).padding(.horizontal, 30)

            HStack(spacing: 36) {
                Image(systemName: "gobackward.15")
                Button {
                    playing.toggle()
                    if let url = item.url.flatMap(URL.init) { openURL(url) }
                } label: {
                    Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56)).foregroundStyle(Color.stashAmber)
                }
                Image(systemName: "goforward.15")
            }
            .font(.system(size: 24))
            .foregroundStyle(.primary)

            Text("Opens in \(item.platform?.displayName ?? "source app")")
                .font(AppFont.metadata()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
