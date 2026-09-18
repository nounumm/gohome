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

    func save(_ record: WorkRecord) {
        var all = loadAll()
        all[dateKey(for: record.date)] = record
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL())
        }
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
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL())
        }
    }

    func updateCheckIn(date: Date) {
        var all = loadAll()
        let key = dateKey()
        guard var record = all[key] else { return }
        record.checkIn = date
        all[key] = record
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL())
        }
    }

    /// 오늘 기록이 아직 없으면 만들어서 기록한다.
    func setHalfDay(_ value: Bool) {
        var all = loadAll()
        let key = dateKey()
        var record = all[key] ?? WorkRecord(date: Date())
        record.halfDay = value
        all[key] = record
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL())
        }
    }

    func checkOut() {
        let now = Date()
        var all = loadAll()
        let key = dateKey()
        guard var record = all[key],
              record.checkIn != nil,
              record.checkOut == nil else { return }
        record.checkOut = now
        all[key] = record
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL())
        }
    }
}
