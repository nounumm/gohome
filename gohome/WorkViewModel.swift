import Foundation
import Combine
import WidgetKit

extension Notification.Name {
    static let didUpdateWorkRecord = Notification.Name("didUpdateWorkRecord")
}

class WorkViewModel: ObservableObject {
    @Published var today: WorkRecord?
    @Published var recentRecords: [WorkRecord] = []

    private let storage = StorageService.shared
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private lazy var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = seoul
        f.dateFormat = "HH:mm"
        return f
    }()

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = seoul
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd EEE"
        return f
    }()

    init() {
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .didUpdateWorkRecord,
            object: nil
        )
    }

    func load() {
        today = storage.todayRecord()
        recentRecords = storage.recentRecords()
    }

    @objc func reload() {
        DispatchQueue.main.async {
            self.load()
            self.scheduleNotificationIfNeeded()
        }
    }

    private func scheduleNotificationIfNeeded() {
        guard today?.checkIn != nil, today?.checkOut == nil,
              let expected = expectedCheckout() else { return }
        NotificationService.shared.scheduleCheckout(at: expected)
        UserDefaults.standard.set(expected, forKey: "expected_checkout")
    }

    var isHalfDay: Bool { today?.halfDay ?? false }

    // 퇴근 예정 시간 계산 (반차/일반 구분)
    func expectedCheckout() -> Date? {
        guard let checkIn = today?.checkIn else { return nil }

        // 반차: 4시간 근무, 12~13시 점심 제외
        if isHalfDay {
            return calcWithLunchBreak(from: checkIn, workHours: 4)
        }

        // 일반 근무: 출근 + 9시간
        return checkIn.addingTimeInterval(9 * 3600)
    }

    private func calcWithLunchBreak(from checkIn: Date, workHours: Double) -> Date {
        var cal = Calendar.current
        cal.timeZone = seoul

        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: checkIn)!
        let onepm = cal.date(bySettingHour: 13, minute: 0, second: 0, of: checkIn)!

        var remaining = workHours * 3600
        var current = checkIn

        if current < noon {
            let beforeLunch = noon.timeIntervalSince(current)
            if beforeLunch >= remaining {
                return current.addingTimeInterval(remaining)
            }
            remaining -= beforeLunch
            current = onepm
        } else if current < onepm {
            current = onepm
        }

        return current.addingTimeInterval(remaining)
    }

    /// 오후 반차 출근 시간대: 13:00 ~ 15:00. 이 사이에 출근하면 자동으로 반차 처리한다.
    /// 그 전/후엔 팝오버 체크박스로 직접 지정한다.
    static func applyHalfDayAutoRule() {
        guard let checkIn = StorageService.shared.todayRecord()?.checkIn else { return }

        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let c = cal.dateComponents([.hour, .minute, .second], from: checkIn)
        let tod = (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)

        if tod >= 13 * 3600 && tod <= 15 * 3600 {
            StorageService.shared.setHalfDay(true)
        }
    }

    func checkIn() {
        storage.checkIn()
        WorkViewModel.applyHalfDayAutoRule()
        load()
        refreshCheckoutSchedule()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateCheckIn(date: Date) {
        storage.updateCheckIn(date: date)
        WorkViewModel.applyHalfDayAutoRule()
        load()
        refreshCheckoutSchedule()
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .didUpdateWorkRecord, object: nil)
    }

    func setHalfDay(_ value: Bool) {
        guard isHalfDay != value else { return }
        storage.setHalfDay(value)
        load()
        refreshCheckoutSchedule()
        NotificationCenter.default.post(name: .didUpdateWorkRecord, object: nil)
    }

    private func refreshCheckoutSchedule() {
        guard let expected = expectedCheckout() else { return }
        NotificationService.shared.scheduleCheckout(at: expected)
        UserDefaults.standard.set(expected, forKey: "expected_checkout")
    }

    func checkOut() {
        storage.checkOut()
        NotificationService.shared.cancelCheckout()
        UserDefaults.standard.removeObject(forKey: "expected_checkout")
        load()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func statusText() -> String {
        guard let today = today else { return "출근 전" }
        if today.checkOut != nil { return "퇴근 완료" }
        if today.checkIn != nil { return "일하는 중" }
        return "출근 전"
    }

    func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        return timeFormatter.string(from: date)
    }

    func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    func formatWorked(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "\(h)h \(m)m"
    }
}
