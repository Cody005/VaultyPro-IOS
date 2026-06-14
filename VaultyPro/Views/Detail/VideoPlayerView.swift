import SwiftUI
import WebKit

/// Embeds a YouTube (or generic web) video player via WKWebView + iframe API.
struct VideoPlayerView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        if let videoID = MetadataFetcher.youTubeVideoID(url) {
            let embed = """
            <!DOCTYPE html><html><head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>html,body{margin:0;background:#000;height:100%}.wrap{position:relative;padding-bottom:56.25%;height:0}iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}</style>
            </head><body><div class="wrap">
            <iframe src="https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
            </div></body></html>
            """
            webView.loadHTMLString(embed, baseURL: URL(string: "https://www.youtube.com"))
        } else {
            webView.load(URLRequest(url: url))
        }
    }
}
