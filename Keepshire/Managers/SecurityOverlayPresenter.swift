import SwiftUI
import UIKit

final class SecurityOverlayPresenter {
    /// Why the black cover is up. Leaving the app must not tear down a cover that
    /// screen recording still needs, so each reason is tracked separately.
    enum ProtectionReason: Hashable {
        case recording
        case inactive
    }

    private var overlayWindow: UIWindow?
    private var reasons: Set<ProtectionReason> = []
    private weak var screenshotAlert: UIAlertController?

    var isProtectionActive: Bool { !reasons.isEmpty }

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

    func showProtection(for reason: ProtectionReason) {
        let wasActive = isProtectionActive
        reasons.insert(reason)
        guard !wasActive else { return }

        DispatchQueue.main.async { [weak self] in
            self?.createOverlayWindow()
        }
    }

    func hideProtection(for reason: ProtectionReason) {
        guard reasons.remove(reason) != nil, reasons.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            self?.removeOverlayWindow()
        }
    }

    func hideAllProtection() {
        guard isProtectionActive else { return }
        reasons.removeAll()

        DispatchQueue.main.async { [weak self] in
            self?.removeOverlayWindow()
        }
    }

    func showScreenshotAlert() {
        // Without this the next notice presents on top of the one already showing,
        // and the person has to dismiss the same message twice.
        guard screenshotAlert == nil else { return }
        guard let rootViewController = activeKeyWindow?.rootViewController else { return }

        var presentingViewController = rootViewController
        while let presented = presentingViewController.presentedViewController {
            presentingViewController = presented
        }

        let alert = UIAlertController(
            title: SecurityNoticeCopy.screenshotTitle,
            message: SecurityNoticeCopy.screenshotMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.screenshotAlert = nil
        })
        screenshotAlert = alert
        presentingViewController.present(alert, animated: true)
    }

    var isShowingScreenshotAlert: Bool { screenshotAlert != nil }

    private func createOverlayWindow() {
        guard overlayWindow == nil, let windowScene = candidateWindowScenes.first else { return }

        overlayWindow = SecurityOverlayWindow(windowScene: windowScene)
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

/// Marks the black cover window so window lookups never mistake it for app content.
final class SecurityOverlayWindow: UIWindow {}

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
