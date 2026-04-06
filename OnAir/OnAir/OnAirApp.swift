import SwiftUI

@main
struct OnAirApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            MenuBarIcon(isOnAir: model.isOnAir, connectionState: model.connectionState)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The icon shown in the menu bar.
/// On Air  → red filled circle (pulsing)
/// Connected, not on air → primary colour outline circle
/// Scanning / disconnected → secondary colour outline circle
struct MenuBarIcon: View {
    let isOnAir: Bool
    let connectionState: ConnectionState

    var body: some View {
        if isOnAir {
            Image(systemName: "record.circle.fill")
                .foregroundStyle(.red)
                .symbolEffect(.pulse)
        } else {
            Image(systemName: "record.circle")
                .foregroundStyle(connectionState == .connected ? Color.primary : Color.secondary)
        }
    }
}
