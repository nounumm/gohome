import UserNotifications
import AppKit

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let checkoutActionId = "CHECKOUT_ACTION"
    private let categoryId = "WORK_CATEGORY"
    private let reminderNotificationId = "checkout_reminder"
    private let exactNotificationId = "checkout_exact"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupCategory()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if !granted {
                print("⚠️ 알림 권한 거부됨: \(error?.localizedDescription ?? "사용자 거부")")
            }
        }
    }

    private func setupCategory() {
        let action = UNNotificationAction(
            identifier: checkoutActionId,
            title: "퇴근하기",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [action],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func scheduleCheckout(at date: Date) {
        let reminderRemaining = date.timeIntervalSinceNow - 600
        let exactRemaining = date.timeIntervalSinceNow

        if reminderRemaining > 0 {
            let content = UNMutableNotificationContent()
            content.title = "10분 후 퇴근이에요! 🏠"
            content.body = "오늘도 수고했어요."
            content.sound = .default
            content.categoryIdentifier = categoryId

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderRemaining, repeats: false)
            let request = UNNotificationRequest(identifier: reminderNotificationId, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error { print("❌ 10분전 알림 등록 실패: \(error)") }
            }
        }

        if exactRemaining > 0 {
            let content = UNMutableNotificationContent()
            content.title = "퇴근 시간이에요! 🏠"
            content.body = "오늘도 수고했어요."
            content.sound = .default
            content.categoryIdentifier = categoryId

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: exactRemaining, repeats: false)
            let request = UNNotificationRequest(identifier: exactNotificationId, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error { print("❌ 정각 알림 등록 실패: \(error)") }
            }
        }
    }

    func cancelCheckout() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminderNotificationId, exactNotificationId]
        )
    }

    // 알림 액션 버튼 처리
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == checkoutActionId {
            StorageService.shared.checkOut()
            NotificationCenter.default.post(name: .didUpdateWorkRecord, object: nil)
        }
        completionHandler()
    }

    // 앱 실행 중에도 알림 배너 표시
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
