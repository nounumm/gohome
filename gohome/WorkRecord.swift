import Foundation

struct WorkRecord {
    var date: Date
    var checkIn: Date?
    var checkOut: Date?

    /// 반차 여부. 예전엔 구글 캘린더에서 읽었지만 지금은 사용자가 직접 켠다.
    var halfDay: Bool = false

    var workedInterval: TimeInterval? {
        guard let checkIn = checkIn, let checkOut = checkOut else { return nil }
        return checkOut.timeIntervalSince(checkIn)
    }

    var isOvertime: Bool {
        guard let w = workedInterval else { return false }
        return w > 9 * 3600
    }
}

extension WorkRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case date, checkIn, checkOut, halfDay
    }

    // halfDay 가 없던 시절의 기록도 그대로 읽을 수 있어야 한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        checkIn = try c.decodeIfPresent(Date.self, forKey: .checkIn)
        checkOut = try c.decodeIfPresent(Date.self, forKey: .checkOut)
        halfDay = try c.decodeIfPresent(Bool.self, forKey: .halfDay) ?? false
    }
}
