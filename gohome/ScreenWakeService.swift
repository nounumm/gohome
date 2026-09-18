import AppKit

class ScreenWakeService {
    static let shared = ScreenWakeService()
    private init() {}

    func start() {
        let workspaceNames: [Notification.Name] = [
            NSWorkspace.sessionDidBecomeActiveNotification, // Fast User Switching
            NSWorkspace.screensDidWakeNotification,         // 화면 슬립에서 깨어남
            NSWorkspace.didWakeNotification                 // 시스템 슬립에서 깨어남
        ]
        for name in workspaceNames {
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(handleScreenWake),
                name: name,
                object: nil
            )
        }

        // Cmd+Ctrl+Q 화면 잠금 해제
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func handleScreenWake() {
        // 날짜가 바뀌었을 수 있으므로 항상 UI 갱신
        NotificationCenter.default.post(name: .didUpdateWorkRecord, object: nil)

        let seoul = TimeZone(identifier: "Asia/Seoul")!
        var calendar = Calendar.current
        calendar.timeZone = seoul

        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // 오후 반차 출근(13~15시)도 자동으로 잡을 수 있도록 상한을 15시까지 늘렸다.
        guard hour >= 8 && hour < 15 else { return }
        guard StorageService.shared.todayRecord()?.checkIn == nil else { return }

        StorageService.shared.checkIn()
        WorkViewModel.applyHalfDayAutoRule()
        NotificationCenter.default.post(name: .didUpdateWorkRecord, object: nil)
    }
}
