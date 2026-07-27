import SwiftUI
import UIKit

/// Bridges `UIActivityViewController`. SwiftUI's `ShareLink` can't be used
/// here: the share URL doesn't exist until the publish mutation returns, and
/// `ShareLink` needs its item up front at view-construction time — wrapping it
/// in a sheet just to satisfy that would cost the user an extra tap.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view // iPad crash guard
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// `URL` isn't `Identifiable`, which `.sheet(item:)` requires.
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
