import CoreMotion
import UIKit

final class SecurityMotionDetector: NSObject {
    var onLockRequested: ((String) -> Void)?

    // Intentionally eager to preserve the previous CoreMotion lifecycle.
    private let motionManager = CMMotionManager()
    private var lastOrientation: UIDeviceOrientation = .portrait
    private let shakeThreshold: Double = 2.5

    func setup(shakeEnabled: Bool, flipEnabled: Bool) {
        if shakeEnabled {
            startShakeDetection()
        }
        if flipEnabled {
            startFlipDetection()
        }

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        lastOrientation = UIDevice.current.orientation
    }

    func setShakeDetectionEnabled(_ enabled: Bool) {
        enabled ? startShakeDetection() : stopShakeDetection()
    }

    func setFlipDetectionEnabled(_ enabled: Bool) {
        enabled ? startFlipDetection() : stopFlipDetection()
    }

    private func startShakeDetection() {
        guard motionManager.isAccelerometerAvailable else {
            print("DEBUG: Accelerometer not available for shake detection")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }
            let magnitude = sqrt(
                acceleration.x * acceleration.x
                    + acceleration.y * acceleration.y
                    + acceleration.z * acceleration.z
            )
            if magnitude > self.shakeThreshold {
                print("DEBUG: Shake detected! Magnitude: \(magnitude)")
                self.onLockRequested?("Shake detected")
            }
        }
        print("DEBUG: Shake detection started")
    }

    private func stopShakeDetection() {
        motionManager.stopAccelerometerUpdates()
        print("DEBUG: Shake detection stopped")
    }

    private func startFlipDetection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        print("DEBUG: Flip detection started")
    }

    private func stopFlipDetection() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        print("DEBUG: Flip detection stopped")
    }

    @objc private func deviceOrientationDidChange() {
        let currentOrientation = UIDevice.current.orientation
        if currentOrientation == .faceDown && lastOrientation != .faceDown {
            print("DEBUG: Face-down flip detected!")
            onLockRequested?("Device flipped face-down")
        } else if currentOrientation == .faceDown && lastOrientation == .faceUp {
            print("DEBUG: Face-up to face-down flip detected!")
            onLockRequested?("Device flipped")
        }
        lastOrientation = currentOrientation
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        motionManager.stopAccelerometerUpdates()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}
