import Foundation

class StorageService {
    static let shared = StorageService()
    private let seoul = TimeZone(identifier: "Asia/Seoul")!
    private init() {}

    private lazy var dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = seoul
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func fileURL() -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/gohome")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("work_records.json")
    }

    private func dateKey(for date: Date = Date()) -> String {
        return dateKeyFormatter.string(from: date)
    }

    private func loadAll() -> [String: WorkRecord] {
        guard let data = try? Data(contentsOf: fileURL()),
              let records = try? JSONDecoder().decode([String: WorkRecord].self, from: data)
        else { return [:] }
        return records
    }

    /// 통째로 덮어쓰면 쓰는 도중 죽었을 때 전체 기록이 날아간다.
    /// .atomic 은 임시 파일에 쓰고 교체하므로 실패해도 이전 파일이 남는다.
    private func write(_ all: [String: WorkRecord]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: fileURL(), options: .atomic)
    }

    func save(_ record: WorkRecord) {
        var all = loadAll()
        all[dateKey(for: record.date)] = record
        write(all)
    }

    func todayRecord() -> WorkRecord? {
        return loadAll()[dateKey()]
    }

    func recentRecords(limit: Int = 10) -> [WorkRecord] {
        return loadAll()
            .sorted { $0.key > $1.key }
            .prefix(limit)
            .map { $0.value }
    }

    func checkIn() {
        let now = Date()
        var all = loadAll()
        let key = dateKey()
        var record = all[key] ?? WorkRecord(date: now)
        guard record.checkIn == nil else { return }
        record.checkIn = now
        all[key] = record
        write(all)
    }

    func updateCheckIn(date: Date) {
        var all = loadAll()
        let key = dateKey()
        guard var record = all[key] else { return }
        record.checkIn = date
        all[key] = record
        write(all)
    }

    /// 오늘 기록이 아직 없으면 만들어서 기록한다.
    func setHalfDay(_ value: Bool) {
        var all = loadAll()
        let key = dateKey()
        var record = all[key] ?? WorkRecord(date: Date())
        record.halfDay = value
        all[key] = record
        write(all)
    }

    /// 퇴근이 아직 안 찍힌 기록의 날짜 키.
    /// 자정을 넘겨 일한 경우 오늘 기록이 없으므로 전날 기록을 가리킨다.
    private func openRecordKey(in all: [String: WorkRecord]) -> String? {
        let today = dateKey()
        if let r = all[today], r.checkIn != nil, r.checkOut == nil { return today }

        let yesterday = dateKey(for: Date().addingTimeInterval(-86400))
        if let r = all[yesterday], r.checkIn != nil, r.checkOut == nil { return yesterday }

        return nil
    }

    /// 아직 퇴근하지 않은 기록. 없으면 nil.
    func openRecord() -> WorkRecord? {
        let all = loadAll()
        guard let key = openRecordKey(in: all) else { return nil }
        return all[key]
    }

    func checkOut() {
        var all = loadAll()
        guard let key = openRecordKey(in: all), var record = all[key] else { return }
        record.checkOut = Date()
        all[key] = record
        write(all)
    }
}
