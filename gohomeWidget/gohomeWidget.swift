import WidgetKit
import SwiftUI

// MARK: - Data

struct WorkRecord: Codable {
    var date: Date
    var checkIn: Date?
    var checkOut: Date?

    var expectedCheckOut: Date? {
        guard let checkIn = checkIn else { return nil }
        return checkIn.addingTimeInterval(9 * 3600)
    }
}

func loadTodayRecord() -> WorkRecord? {
    let seoul = TimeZone(identifier: "Asia/Seoul")!
    let formatter = DateFormatter()
    formatter.timeZone = seoul
    formatter.dateFormat = "yyyy-MM-dd"
    let key = formatter.string(from: Date())

    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/gohome/work_records.json")
    guard let data = try? Data(contentsOf: url),
          let records = try? JSONDecoder().decode([String: WorkRecord].self, from: data)
    else { return nil }

    return records[key]
}

func formatTime(_ date: Date?) -> String {
    guard let date = date else { return "--:--" }
    let f = DateFormatter()
    f.timeZone = TimeZone(identifier: "Asia/Seoul")
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

// MARK: - Entry

struct WorkEntry: TimelineEntry {
    let date: Date
    let checkIn: Date?
    let checkOut: Date?
    let expectedCheckOut: Date?

    var statusText: String {
        if checkOut != nil { return "퇴근 완료" }
        if checkIn != nil { return "근무 중" }
        return "출근 전"
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WorkEntry {
        WorkEntry(date: Date(), checkIn: nil, checkOut: nil, expectedCheckOut: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkEntry) -> Void) {
        let record = loadTodayRecord()
        completion(WorkEntry(
            date: Date(),
            checkIn: record?.checkIn,
            checkOut: record?.checkOut,
            expectedCheckOut: record?.expectedCheckOut
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkEntry>) -> Void) {
        let record = loadTodayRecord()
        let entry = WorkEntry(
            date: Date(),
            checkIn: record?.checkIn,
            checkOut: record?.checkOut,
            expectedCheckOut: record?.expectedCheckOut
        )
        // 30분마다 갱신
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: WorkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("집에가자")
                .font(.caption2.bold())
                .foregroundColor(.secondary)

            Spacer()

            Text(entry.statusText)
                .font(.caption.bold())
                .foregroundColor(entry.checkOut != nil ? .green : entry.checkIn != nil ? .blue : .secondary)

            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption2)
                Text(formatTime(entry.checkIn))
                    .font(.title3.bold())
            }

            HStack(spacing: 4) {
                Image(systemName: "house.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
                Text(formatTime(entry.checkOut ?? entry.expectedCheckOut))
                    .font(.title3.bold())
                    .foregroundColor(entry.checkOut != nil ? .primary : .secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: WorkEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("집에가자")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)

                Text(entry.statusText)
                    .font(.headline.bold())
                    .foregroundColor(entry.checkOut != nil ? .green : entry.checkIn != nil ? .blue : .secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Label(formatTime(entry.checkIn), systemImage: "arrow.right.circle.fill")
                        .font(.callout.bold())
                        .foregroundColor(.blue)

                    Text("→")
                        .foregroundColor(.secondary)

                    Label(formatTime(entry.checkOut ?? entry.expectedCheckOut), systemImage: "house.fill")
                        .font(.callout.bold())
                        .foregroundColor(entry.checkOut != nil ? .green : .secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct gohomeWidget: Widget {
    let kind: String = "gohomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(macOS 14.0, *) {
                SmallWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                SmallWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("집에가자")
        .description("오늘 출퇴근 현황을 확인해요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
