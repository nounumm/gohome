import SwiftUI

struct PopoverView: View {
    @StateObject private var vm = WorkViewModel()
    @State private var activeSheet: Sheet? = nil
    @State private var editCheckInTime: Date = Date()

    enum Sheet: Identifiable {
        case settings, history, checkInEdit
        var id: Self { self }
    }

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            // 상단 타이틀 + 버튼들
            HStack {
                Text("집에가자")
                    .font(.headline)
                Spacer()
                Button {
                    activeSheet = .history
                } label: {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    activeSheet = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .top)

            Divider()

            // 콘텐츠 영역
            VStack(spacing: 0) {
                // 현재 상태 섹션
                SectionHeader(title: "현재 상태")

                VStack(spacing: 10) {
                    HStack {
                        Text(vm.statusText())
                            .font(.title3.bold())
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        TimeCard(label: "출근 시간", time: vm.formatTime(vm.today?.checkIn))
                            .onTapGesture {
                                guard let checkIn = vm.today?.checkIn else { return }
                                editCheckInTime = checkIn
                                activeSheet = .checkInEdit
                            }
                        TimeCard(label: "퇴근 예정", time: vm.formatTime(vm.expectedCheckout()))
                    }

                    // 반차 (예전 캘린더 연동 대체)
                    HStack {
                        Toggle("오늘 반차 (4시간 근무)", isOn: Binding(
                            get: { vm.isHalfDay },
                            set: { vm.setHalfDay($0) }
                        ))
                        .toggleStyle(.checkbox)
                        .disabled(vm.today?.checkOut != nil)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            }

            Divider()

            // 하단 액션 버튼
            HStack(spacing: 8) {
                Button("출근하기") { vm.checkIn() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(vm.today?.checkIn != nil)

                Button("퇴근하기") { vm.checkOut() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(vm.today?.checkIn == nil || vm.today?.checkOut != nil)

                Spacer()

                Button("종료") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.callout)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .frame(width: 320)

        if let sheet = activeSheet {
            Color(NSColor.windowBackgroundColor)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .overlay(
                    Group {
                        switch sheet {
                        case .settings:    SettingsView(activeSheet: $activeSheet)
                        case .history:     HistoryView(vm: vm, activeSheet: $activeSheet)
                        case .checkInEdit: CheckInEditView(time: editCheckInTime, activeSheet: $activeSheet) { newTime in
                            vm.updateCheckIn(date: newTime)
                        }
                        }
                    }
                )
                .padding(8)
        }
        } // ZStack
        .frame(width: 320)
    }
}

// MARK: - 출근 내역 팝업

struct HistoryView: View {
    @ObservedObject var vm: WorkViewModel
    @Binding var activeSheet: PopoverView.Sheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("출근 내역")
                    .font(.headline)
                Spacer()
                Button("닫기") { activeSheet = nil }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            if vm.recentRecords.isEmpty {
                Text("출근 내역이 없습니다.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 32)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.recentRecords, id: \.date) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vm.formatDate(record.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(vm.formatTime(record.checkIn)) – \(vm.formatTime(record.checkOut))")
                                        .font(.callout)
                                }
                                Spacer()
                                if let interval = record.workedInterval {
                                    Text(vm.formatWorked(interval))
                                        .font(.caption)
                                        .foregroundColor(record.isOvertime ? .red : .green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(record.isOvertime ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)

                            if record.date != vm.recentRecords.last?.date {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}

struct TimeCard: View {
    let label: String
    let time: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(time)
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CheckInEditView: View {
    let time: Date
    @Binding var activeSheet: PopoverView.Sheet?
    let onSave: (Date) -> Void

    @State private var hour: Int = 0
    @State private var minute: Int = 0

    // 표시·저장이 전부 KST 기준이므로 편집도 같은 달력을 쓴다.
    private var calendar: Calendar {
        var c = Calendar.current
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("출근 시간 수정")
                    .font(.headline)
                Spacer()
                Button("닫기") { activeSheet = nil }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Button("저장") {
                    if let updated = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: time) {
                        onSave(updated)
                    }
                    activeSheet = nil
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .fontWeight(.medium)
            }
            .padding(.bottom, 16)

            Divider()

            HStack(spacing: 0) {
                Spacer()
                TimeUnitStepper(value: $hour, range: 0...23)
                Text(":")
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .offset(y: -4)
                TimeUnitStepper(value: $minute, range: 0...59)
                Spacer()
            }
            .padding(.top, 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            hour   = calendar.component(.hour,   from: time)
            minute = calendar.component(.minute, from: time)
        }
    }
}

private struct TimeUnitStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 6) {
            Button { value = value < range.upperBound ? value + 1 : range.lowerBound } label: {
                Image(systemName: "chevron.up")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("", text: $text)
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 66)
                .focused($focused)
                .onAppear { text = String(format: "%02d", value) }
                .onChange(of: text) {
                    // 저장 버튼을 누르는 시점에 포커스 이탈이 아직 반영되지 않을 수 있다.
                    // 입력 중에도 유효한 값이면 바로 반영해 둔다.
                    if let n = Int(text), range.contains(n) { value = n }
                }
                .onChange(of: focused) {
                    if !focused {
                        let clamped = min(max(Int(text) ?? value, range.lowerBound), range.upperBound)
                        value = clamped
                        text = String(format: "%02d", clamped)
                    }
                }
                .onChange(of: value) {
                    if !focused { text = String(format: "%02d", value) }
                }

            Button { value = value > range.lowerBound ? value - 1 : range.upperBound } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
