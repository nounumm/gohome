import AppKit
import SwiftUI
import Combine

class MenuBarIconState: ObservableObject {
    static let shared = MenuBarIconState()
    @Published var iconColor: Color? = nil
    private init() {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var iconTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ScreenWakeService.shared.start()
        NotificationService.shared.requestPermission()

        updateStatusIcon()

        iconTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateStatusIcon()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusIcon),
            name: .didUpdateWorkRecord,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        iconTimer?.invalidate()
    }

    @objc func updateStatusIcon() {
        guard let record = StorageService.shared.todayRecord(),
              let checkIn = record.checkIn else {
            MenuBarIconState.shared.iconColor = nil
            return
        }

        if record.checkOut != nil {
            MenuBarIconState.shared.iconColor = nil
            return
        }

        let expectedCheckout = UserDefaults.standard.object(forKey: "expected_checkout") as? Date
            ?? checkIn.addingTimeInterval(9 * 3600)
        let remaining = expectedCheckout.timeIntervalSinceNow

        let warningStart = 1800.0

        if remaining > warningStart {
            MenuBarIconState.shared.iconColor = nil
        } else {
            let t = CGFloat(1.0 - (remaining / warningStart))
            MenuBarIconState.shared.iconColor = Color(blendFrom: .systemOrange, to: .systemRed, t: t)
        }
    }
}

private extension Color {
    init(blendFrom: NSColor, to: NSColor, t: CGFloat) {
        let t = max(0, min(1, t))
        guard let f = blendFrom.usingColorSpace(.sRGB),
              let toC = to.usingColorSpace(.sRGB) else {
            self = Color(blendFrom)
            return
        }
        self = Color(NSColor(
            srgbRed: f.redComponent + (toC.redComponent - f.redComponent) * t,
            green: f.greenComponent + (toC.greenComponent - f.greenComponent) * t,
            blue: f.blueComponent + (toC.blueComponent - f.blueComponent) * t,
            alpha: 1.0
        ))
    }
}
