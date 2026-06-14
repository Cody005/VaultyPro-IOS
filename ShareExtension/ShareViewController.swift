import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Wraps a non-Sendable value so it can be handed to a detached async task.
private struct UncheckedBox<T>: @unchecked Sendable { let value: T }

/// Hosts the SwiftUI share sheet and extracts shared content from the host app.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let providers = (extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []
        let box = UncheckedBox(value: providers)
        Task { @MainActor in
            let input = await Self.extractInput(box)
            self.present(input: input)
        }
    }

    private func present(input: SharedInput?) {
        let root = ShareRootView(
            input: input ?? .text(""),
            onClose: { [weak self] in self?.complete() }
        )
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - Input extraction

    /// Resolves the first usable attachment, preferring URLs, then images, then text.
    /// Each continuation only ever resumes with a `Sendable` value so it satisfies strict concurrency.
    private static func extractInput(_ box: UncheckedBox<[NSItemProvider]>) async -> SharedInput? {
        let providers = box.value
        let urlType = UTType.url.identifier
        let imageType = UTType.image.identifier
        let textType = UTType.plainText.identifier

        for provider in providers where provider.hasItemConformingToTypeIdentifier(urlType) {
            return await withCheckedContinuation { cont in
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { data, _ in
                    if let url = data as? URL { cont.resume(returning: .url(url.absoluteString)) }
                    else if let str = data as? String { cont.resume(returning: .url(str)) }
                    else { cont.resume(returning: nil) }
                }
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(imageType) {
            return await withCheckedContinuation { cont in
                provider.loadItem(forTypeIdentifier: imageType, options: nil) { data, _ in
                    if let url = data as? URL, let d = try? Data(contentsOf: url) { cont.resume(returning: .image(d)) }
                    else if let img = data as? UIImage, let d = img.jpegData(compressionQuality: 0.8) { cont.resume(returning: .image(d)) }
                    else { cont.resume(returning: nil) }
                }
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(textType) {
            return await withCheckedContinuation { cont in
                provider.loadItem(forTypeIdentifier: textType, options: nil) { data, _ in
                    if let str = data as? String { cont.resume(returning: .text(str)) }
                    else { cont.resume(returning: nil) }
                }
            }
        }
        return nil
    }
}
