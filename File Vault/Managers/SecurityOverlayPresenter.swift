import SwiftUI
import UIKit

final class SecurityOverlayPresenter {
    private var overlayWindow: UIWindow?
    private(set) var isProtectionActive = false

    private var candidateWindowScenes: [UIWindowScene] {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foregroundActive = scenes.filter { $0.activationState == .foregroundActive }
        let foregroundInactive = scenes.filter { $0.activationState == .foregroundInactive }
        let remaining = scenes.filter {
            $0.activationState != .foregroundActive && $0.activationState != .foregroundInactive
        }
        return foregroundActive + foregroundInactive + remaining
    }

    private var activeKeyWindow: UIWindow? {
        for scene in candidateWindowScenes {
            let windows = scene.windows.filter { $0 !== overlayWindow }
            if let window = windows.first(where: { $0.isKeyWindow })
                ?? windows.first(where: { !$0.isHidden })
                ?? windows.first {
                return window
            }
        }
        return nil
    }

    func showProtection() {
        guard !isProtectionActive else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.createOverlayWindow()
            // Preserve the existing state transition even if no scene is available.
            self.isProtectionActive = true
        }
    }

    func hideProtection() {
        guard isProtectionActive else { return }

        DispatchQueue.main.async { [weak self] in
            self?.removeOverlayWindow()
            self?.isProtectionActive = false
        }
    }

    func showScreenshotAlert() {
        guard let rootViewController = activeKeyWindow?.rootViewController else { return }

        var presentingViewController = rootViewController
        while let presented = presentingViewController.presentedViewController {
            presentingViewController = presented
        }

        let alert = UIAlertController(
            title: "Security Notice",
            message: "Screenshot detected. Please ensure your vault contents remain secure.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presentingViewController.present(alert, animated: true)
    }

    private func createOverlayWindow() {
        guard let windowScene = candidateWindowScenes.first else { return }

        overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow?.windowLevel = UIWindow.Level.alert + 1
        overlayWindow?.backgroundColor = .black
        overlayWindow?.isOpaque = true
        overlayWindow?.isHidden = false

        let hostingController = UIHostingController(rootView: SecurityOverlayView())
        hostingController.view.backgroundColor = .black
        overlayWindow?.rootViewController = hostingController
        overlayWindow?.makeKeyAndVisible()
    }

    private func removeOverlayWindow() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }
}

struct SecurityOverlayView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text("Content Protected")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Your vault contents are hidden for security")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}
