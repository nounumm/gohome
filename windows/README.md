# 집에가자 — Windows

macOS 메뉴바 앱(`../gohome`)의 Windows 포팅. 트레이 아이콘 + 클릭 팝업까지만 담았다.

## 빌드

Windows 에서만 빌드된다 (WPF/WinForms 는 Windows 전용 타겟). .NET 8 SDK 필요.

```powershell
cd windows\GoHome
dotnet build
dotnet run
```

단일 exe 로 배포:

```powershell
dotnet publish -c Release -r win-x64 --self-contained false ^
  -p:PublishSingleFile=true -o ..\publish
```

`.NET 8 Desktop Runtime` 이 없는 PC 에도 돌리려면 `--self-contained true` 로 바꾼다 (용량 커짐).

## VM에서 개발 중 코드 갱신하기

UTM 공유 폴더(`Z:\GoHome`)는 맥 쪽 파일을 실시간으로 반영하지만, **빌드는 반드시 로컬 디스크(`C:\dev\GoHome`)에서 해야 한다** (네트워크 드라이브 위에서 `dotnet build` 하면 파일 잠금·권한 문제가 종종 생긴다). 그래서 맥에서 코드를 고칠 때마다 `Z:` → `C:\dev\GoHome`로 다시 복사해줘야 하고, 이건 자동으로 안 된다.

매번 탐색기로 복사하지 말고 `sync.bat` 하나 만들어서 재사용하는 걸 추천한다. `C:\dev` 안에 아래 내용으로 저장:

```bat
@echo off
robocopy Z:\GoHome C:\dev\GoHome /MIR /XD bin obj /NFL /NDL /NJH
echo 동기화 완료. dotnet build 다시 돌리세요.
```

코드 고칠 때마다: `sync.bat` 더블클릭(또는 터미널에서 실행) → `dotnet build`. `/XD bin obj`로 빌드 산출물은 건드리지 않는다.

## 구성

| 파일 | 역할 | macOS 대응 |
|---|---|---|
| `TrayApp.cs` | 트레이 아이콘, 컨텍스트 메뉴, 팝업 토글, 30초 갱신 | `MenuBarExtra` + `AppDelegate` |
| `PopupWindow.xaml(.cs)` | 클릭 시 우하단에 뜨는 정보 창 | `PopoverView` |
| `Services/WorkService.cs` | 상태 판정, 퇴근 예정 시각 계산 | `WorkViewModel` |
| `Services/StorageService.cs` | `%APPDATA%\gohome\work_records.json` | `StorageService` |
| `Services/SessionWatcher.cs` | 잠금 해제 / 절전 복귀 감지 → 자동 출근 | `ScreenWakeService` |
| `Services/TrayIconRenderer.cs` | 아이콘을 런타임에 그림 (상태별 색) | `AppDelegate.updateStatusIcon` |
| `Services/StartupService.cs` | 로그인 시 자동 실행 (레지스트리 Run) | 로그인 항목 |
| `Services/KoreaTime.cs` | KST 고정 시간 처리 | `TimeZone(identifier:)` 하드코딩 |
| `Services/ThemeInfo.cs` | 라이트/다크 테마 판별 | (macOS 는 자동) |

## 동작

- **자동 출근** — 잠금 해제·로그온·사용자 전환·절전 복귀 중 첫 신호에 출근을 찍는다. 08시\~15시 사이에만, 그날 기록이 없을 때만.
- **반차 자동 판정** — 출근 시각이 13:00:00\~15:00 사이면 자동으로 반차 체크박스가 켜진다. 그 밖의 시각은 수동으로만 켜고 끌 수 있다.
- **퇴근 예정** — 일반 근무는 출근 + 9시간. 반차는 4시간 근무 + 12\~13시 점심 제외.
- **트레이 아이콘 색** — 출근 전 회색 / 근무 중 테마 전경색 / 퇴근 30분 전부터 오렌지→빨강 / 퇴근 완료 초록.
- **자동 실행** — 트레이 우클릭 메뉴에서 토글. 상주해야 잠금 해제를 감지하므로 켜두는 게 맞다.
- **출근 시각 수정** — 팝업의 "시각 수정" 클릭 → `HH:mm` 입력 → 저장. 자동 감지가 엉뚱한 시각에 찍혔을 때 고치는 용도. 수정한 시각이 13:00\~15:00 사이로 들어가면 반차도 자동으로 켜진다(그 반대 방향, 즉 반차를 자동으로 끄는 동작은 없다).
- **퇴근 임박 알림** — 퇴근 10분 전 / 정각에 트레이 풍선 알림(토스트)이 뜬다. 같은 출근 기록에 대해 한 번씩만 뜨고, 체크아웃하거나 다음날이 되면 초기화된다.
- **최근 기록 10일치** — 맥 버전과 동일한 개수(`StorageService.recentRecords(limit: 10)`).

## 맥 버전과 다른 점

- **위젯 없음.** `gohomeWidget` 은 포팅하지 않았다.
- **구글 캘린더 연동 없음.** 연차·반차를 캘린더에서 읽지 않고, 팝업의 반차 체크박스로 직접 켠다. `ASWebAuthenticationSession` 이 Windows 에 없어서 OAuth 를 루프백 리다이렉트로 다시 짜야 하고, Google Cloud Console 에서 "데스크톱 앱" 타입 클라이언트를 새로 발급받아야 한다.
- **퇴근 알림이 토스트가 아니라 트레이 풍선.** `NotifyIcon.ShowBalloonTip` 을 썼다. 별도 NuGet(WinUI 토스트 라이브러리) 없이 되는 방법이라 이렇게 갔다 — 진짜 Action Center 토스트가 필요하면 MSIX 패키징이 딸려온다.
- **저장 파일 호환 안 됨.** 구조(날짜키 → 기록)는 같지만 날짜 인코딩이 다르다. Swift `JSONEncoder` 는 기본값이 2001-01-01 기준 초 단위 `Double` 이고, 여기서는 ISO 8601 문자열을 쓴다. 맥 기록을 가져오려면 변환이 필요하다.
- **저장이 원자적** — 임시 파일에 쓰고 교체한다. 맥 버전은 곧바로 덮어써서 쓰는 중 크래시하면 전체 기록이 날아갈 수 있다.
- **반차 계산 버그 없음** — 맥은 위젯이 `출근 + 9시간` 을 따로 하드코딩해서(`gohomeWidget.swift:11`) 반차인 날 위젯과 본체가 다른 값을 보여줬다. 계산 경로가 하나로 합쳐져 사라졌다.

## 알려진 미검증 / 손볼 수 있는 곳

이 코드는 macOS 에서 작성돼 **컴파일·실행 검증을 하지 못했다.** 첫 빌드에서 손볼 가능성이 있는 지점:

1. **`ImplicitUsings` 를 끈 이유** — WPF + WinForms 를 같이 켜면 `Application`, `MessageBox`, `Color`, `Point`, `Size` 등이 양쪽 네임스페이스에 있어 전부 모호성 에러가 난다. 새 파일 추가할 때도 `using` 을 직접 쓰고 별칭(`WinForms = System.Windows.Forms`)으로 구분할 것.
2. **아이콘 외곽선** — `Bitmap.GetHicon()` 은 알파 처리가 완벽하지 않아 16px 에서 테두리가 거칠 수 있다. 거슬리면 32bpp DIB 로 ICO 스트림을 직접 만들어 `new Icon(stream)` 으로 바꾸면 깔끔해진다.
3. **팝업 위치** — 주 모니터 우하단 고정이다. 작업표시줄을 위/왼쪽에 둔 경우나 다중 모니터에서는 커서 위치 기준으로 바꾸는 게 낫다. 그때는 `Cursor.Position`(디바이스 픽셀) → DIP 변환이 필요하다.
4. **팝업 토글** — 트레이 아이콘을 눌러 닫을 때 `Deactivated` 와 `MouseUp` 이 겹치는 문제를 300ms 무시로 처리했다. 체감이 이상하면 이 값을 조정.
