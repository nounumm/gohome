import SwiftUI

@main
struct gohomeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)

        Settings { EmptyView() }
    }
}

struct MenuBarIcon: View {
    @StateObject private var state = MenuBarIconState.shared

    var body: some View {
        if let color = state.iconColor {
            Image(systemName: "house.fill")
                .foregroundStyle(color)
        } else {
            Image(systemName: "house.fill")
        }
    }
}
