import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // Status — non-interactive, shows current state
        Text(statusText)
            .disabled(true)

        Divider()

        // Paired devices — only shown when connected so we have live data
        if model.connectionState == .connected {
            if model.pairedDevices.isEmpty {
                Text("No devices paired")
                    .disabled(true)
            } else {
                ForEach(model.pairedDevices, id: \.self) { mac in
                    Menu(mac) {
                        Button("Remove from Arduino", role: .destructive) {
                            model.removeDevice(mac)
                        }
                    }
                }

                Divider()

                Button("Clear All Paired Devices…", role: .destructive) {
                    model.clearAllDevices()
                }
            }

            Divider()
        }

        Button("Forget Arduino") {
            model.forgetArduino()
        }

        Divider()

        Button("Quit OnAir") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusText: String {
        if model.isOnAir { return "● On Air" }
        switch model.connectionState {
        case .connected:             return "● Connected"
        case .connecting:            return "◌ Connecting…"
        case .scanning:              return "◌ Scanning…"
        case .disconnected:          return "○ Disconnected"
        case .bluetoothUnavailable:  return "✕ Bluetooth unavailable"
        }
    }
}
