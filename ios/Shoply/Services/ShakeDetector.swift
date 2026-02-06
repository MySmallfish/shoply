import CoreMotion
import Foundation

final class ShakeDetector: ObservableObject {
    private let motionManager = CMMotionManager()
    private var lastShake = Date.distantPast
    var onShake: (() -> Void)?

    func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let acceleration = data.acceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            if magnitude > 2.3 {
                let now = Date()
                if now.timeIntervalSince(self.lastShake) > 1.2 {
                    self.lastShake = now
                    self.onShake?()
                }
            }
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
    }
}
