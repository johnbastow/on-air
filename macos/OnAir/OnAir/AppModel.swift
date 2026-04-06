import Foundation
import Observation
import AVFoundation

/// Central state model for the app. All mutations happen on the main thread:
/// BLEManager uses queue:.main, and mic polling uses a main-thread Timer.
@Observable
final class AppModel {
    var isOnAir: Bool = false
    var connectionState: ConnectionState = .scanning
    var pairedDevices: [String] = []

    private let bleManager = BLEManager()
    private let micMonitor = MicMonitor()
    private var micTimer: Timer?

    init() {
        bleManager.onStateChanged = { [weak self] state in
            self?.connectionState = state
        }
        bleManager.onDeviceListUpdated = { [weak self] devices in
            self?.pairedDevices = devices
        }
        bleManager.start()
        requestMicrophoneAccess()
    }

    // MARK: - Microphone

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startMicPolling()
                }
            }
        }
    }

    private func startMicPolling() {
        micTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let active = self.micMonitor.isInUse()
            guard active != self.isOnAir else { return }
            self.isOnAir = active
            self.bleManager.sendMicState(active)
        }
    }

    // MARK: - Device management

    func removeDevice(_ mac: String) {
        bleManager.removeDevice(mac)
    }

    func clearAllDevices() {
        bleManager.clearAllDevices()
    }

    /// Clears the stored Arduino peripheral UUID so the app re-scans from scratch.
    func forgetArduino() {
        bleManager.forget()
    }
}
