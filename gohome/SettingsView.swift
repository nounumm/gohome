import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Binding var activeSheet: PopoverView.Sheet?
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("설정")
                    .font(.headline)
                Spacer()
                Button("닫기") { activeSheet = nil }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 일반
                    Text("일반")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) {
                            do {
                                if launchAtLogin { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                            } catch {
                                print("자동 실행 설정 실패: \(error)")
                                launchAtLogin = !launchAtLogin
                            }
                        }

                }
                .padding(.top, 16)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
