import SwiftUI
import AppKit

@main
struct OnAirApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        observeModel()
    }

    // MARK: - Icon

    func updateIcon() {
        guard let button = statusItem?.button else { return }
        if model.isOnAir {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            let image = NSImage(systemSymbolName: "record.circle.fill",
                                accessibilityDescription: "On Air")?
                .withSymbolConfiguration(config)
            image?.isTemplate = false
            button.image = image
        } else {
            let image = NSImage(systemSymbolName: "record.circle",
                                accessibilityDescription: "OnAir")
            image?.isTemplate = true
            button.image = image
        }
    }

    // Re-runs whenever observed @Observable properties change
    func observeModel() {
        withObservationTracking {
            _ = model.isOnAir
            _ = model.connectionState
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateIcon()
                self?.observeModel()
            }
        }
    }

    // MARK: - NSMenuDelegate (rebuild menu each time it opens)

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        // Status row
        let statusRow = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusRow.isEnabled = false
        menu.addItem(statusRow)

        menu.addItem(.separator())

        // Paired devices
        if model.connectionState == .connected {
            if model.pairedDevices.isEmpty {
                let none = NSMenuItem(title: "No devices paired", action: nil, keyEquivalent: "")
                none.isEnabled = false
                menu.addItem(none)
            } else {
                for mac in model.pairedDevices {
                    let item = NSMenuItem(title: mac, action: nil, keyEquivalent: "")
                    let sub = NSMenu()
                    let remove = NSMenuItem(title: "Remove from Arduino",
                                           action: #selector(removeDevice(_:)),
                                           keyEquivalent: "")
                    remove.representedObject = mac
                    remove.target = self
                    sub.addItem(remove)
                    item.submenu = sub
                    menu.addItem(item)
                }
                menu.addItem(.separator())
                let clearAll = NSMenuItem(title: "Clear All Paired Devices…",
                                         action: #selector(clearAllDevices),
                                         keyEquivalent: "")
                clearAll.target = self
                menu.addItem(clearAll)
            }
            menu.addItem(.separator())
        }

        let forget = NSMenuItem(title: "Forget Arduino",
                                action: #selector(forgetArduino),
                                keyEquivalent: "")
        forget.target = self
        menu.addItem(forget)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit OnAir",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    // MARK: - Actions

    @objc func removeDevice(_ sender: NSMenuItem) {
        guard let mac = sender.representedObject as? String else { return }
        model.removeDevice(mac)
    }

    @objc func clearAllDevices() {
        model.clearAllDevices()
    }

    @objc func forgetArduino() {
        model.forgetArduino()
    }

    // MARK: - Helpers

    private var statusText: String {
        if model.isOnAir { return "● On Air" }
        switch model.connectionState {
        case .connected:            return "● Connected"
        case .connecting:           return "◌ Connecting…"
        case .scanning:             return "◌ Scanning…"
        case .disconnected:         return "○ Disconnected"
        case .bluetoothUnavailable: return "✕ Bluetooth unavailable"
        }
    }
}
