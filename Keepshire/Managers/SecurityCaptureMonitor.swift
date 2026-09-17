import UIKit

final class SecurityCaptureMonitor: NSObject {
    var onScreenshot: (() -> Void)?
    var onCaptureChanged: ((Bool) -> Void)?
    var onWillResignActive: (() -> Void)?
    var onDidBecomeActive: (() -> Void)?

    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidTakeScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturedDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }

    @objc private func userDidTakeScreenshot() {
        onScreenshot?()
    }

    @objc private func capturedDidChange() {
        onCaptureChanged?(isScreenBeingCaptured)
    }

    @objc private func willResignActive() {
        onWillResignActive?()
    }

    @objc private func didBecomeActive() {
        onDidBecomeActive?()
    }

    var isScreenBeingCaptured: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard !scenes.isEmpty else { return UIScreen.main.isCaptured }
        return scenes.contains { $0.screen.isCaptured }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
