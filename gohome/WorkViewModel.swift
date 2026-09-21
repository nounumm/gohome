import Foundation
import Combine
import WidgetKit

extension Notification.Name {
    static let didUpdateWorkRecord = Notification.Name("didUpdateWorkRecord")
}

class WorkViewModel: ObservableObject {
    @Published var today: WorkRecord?
    @Published var recentRecords: [WorkRecord] = []

    /// 아직 퇴근이 안 찍힌 기록. 자정을 넘겨 일하면 전날 기록이 들어온다.
    @Published var openRecord: WorkRecord?

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
        openRecord = storage.openRecord()
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

    /// 오후 반차 출근 시간대: 13:00 ~ 15:00.
    private static func isAfternoonHalfDay(_ date: Date) -> Bool {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        let tod = (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
        return tod >= 13 * 3600 && tod <= 15 * 3600
    }

    /// 출근 시각이 오후 반차 시간대면 자동으로 반차를 켠다.
    /// 그 전/후엔 팝오버 체크박스로 직접 지정한다.
    ///
    /// previousCheckIn 은 출근 시각을 고칠 때만 넘긴다. 고치기 전 시각이
    /// 반차 시간대였고 고친 시각이 아니라면, 자동으로 켰던 반차도 같이 끈다.
    /// 직접 켠 반차는 건드리지 않는다 (고치기 전 시각이 시간대 밖이므로).
    static func applyHalfDayAutoRule(previousCheckIn: Date? = nil) {
        guard let checkIn = StorageService.shared.todayRecord()?.checkIn else { return }

        if isAfternoonHalfDay(checkIn) {
            StorageService.shared.setHalfDay(true)
        } else if let previous = previousCheckIn, isAfternoonHalfDay(previous) {
            StorageService.shared.setHalfDay(false)
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
        // 값이 그대로면 파일을 다시 쓰지 않는다.
        guard today?.checkIn != date else { return }
        let previous = today?.checkIn
        storage.updateCheckIn(date: date)
        WorkViewModel.applyHalfDayAutoRule(previousCheckIn: previous)
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
