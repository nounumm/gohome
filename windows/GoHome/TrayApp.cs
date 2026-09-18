using System;
using System.Drawing;
using System.Windows.Threading;
using GoHome.Services;
using WinForms = System.Windows.Forms;

namespace GoHome;

/// <summary>
/// 트레이 아이콘 + 컨텍스트 메뉴 + 팝업 창을 묶어 관리한다.
/// macOS 의 MenuBarExtra + AppDelegate 를 합친 역할.
/// </summary>
public sealed class TrayApp : IDisposable
{
    private readonly WinForms.NotifyIcon _notifyIcon;
    private readonly WinForms.ToolStripMenuItem _startupItem;
    private readonly DispatcherTimer _timer;
    private readonly SessionWatcher _watcher;
    private readonly Dispatcher _dispatcher;

    private PopupWindow? _popup;
    private Icon? _currentIcon;
    private DateTime _popupHiddenAt = DateTime.MinValue;

    // 퇴근 임박 알림. 같은 출근 기록에 대해 한 번씩만 띄운다.
    private DateTimeOffset? _notifiedForCheckIn;
    private bool _reminderShown;
    private bool _exactShown;

    public TrayApp()
    {
        _dispatcher = Dispatcher.CurrentDispatcher;

        _startupItem = new WinForms.ToolStripMenuItem("로그인 시 자동 실행")
        {
            CheckOnClick = true,
            Checked = StartupService.IsEnabled,
        };
        _startupItem.CheckedChanged += (_, _) => StartupService.SetEnabled(_startupItem.Checked);

        var menu = new WinForms.ContextMenuStrip();
        var openItem = new WinForms.ToolStripMenuItem("열기");
        openItem.Click += (_, _) => ShowPopup();
        var quitItem = new WinForms.ToolStripMenuItem("종료");
        quitItem.Click += (_, _) => System.Windows.Application.Current.Shutdown();

        menu.Items.Add(openItem);
        menu.Items.Add(new WinForms.ToolStripSeparator());
        menu.Items.Add(_startupItem);
        menu.Items.Add(new WinForms.ToolStripSeparator());
        menu.Items.Add(quitItem);

        _notifyIcon = new WinForms.NotifyIcon
        {
            ContextMenuStrip = menu,
            Text = "집에가자",
        };
        _notifyIcon.MouseUp += OnTrayMouseUp;

        Refresh();
        _notifyIcon.Visible = true;

        // 남은 시간에 따라 아이콘 색이 변하므로 주기적으로 다시 그린다.
        _timer = new DispatcherTimer(DispatcherPriority.Background)
        {
            Interval = TimeSpan.FromSeconds(30),
        };
        _timer.Tick += (_, _) => Refresh();
        _timer.Start();

        WorkService.Shared.Changed += OnWorkChanged;

        // SystemEvents 콜백은 별도 스레드에서 오므로 UI 스레드로 넘긴다.
        _watcher = new SessionWatcher(() =>
            _dispatcher.BeginInvoke(new Action(() => WorkService.Shared.HandleWake())));
        _watcher.Start();
    }

    private void OnWorkChanged()
    {
        if (_dispatcher.CheckAccess()) Refresh();
        else _dispatcher.BeginInvoke(new Action(Refresh));
    }

    private void OnTrayMouseUp(object? sender, WinForms.MouseEventArgs e)
    {
        if (e.Button != WinForms.MouseButtons.Left) return;

        // 팝업이 열려 있을 때 아이콘을 누르면 Deactivated 로 먼저 숨겨진다.
        // 그 직후의 클릭을 다시 열기로 처리하면 토글이 안 되므로 짧게 무시한다.
        if ((DateTime.UtcNow - _popupHiddenAt).TotalMilliseconds < 300) return;

        if (_popup is { IsVisible: true }) HidePopup();
        else ShowPopup();
    }

    private void ShowPopup()
    {
        WorkService.Shared.Reload();

        if (_popup is null)
        {
            _popup = new PopupWindow();
            // 고정(핀) 켜져 있으면 포커스를 잃어도 자동으로 안 닫는다.
            _popup.Deactivated += (_, _) => { if (!_popup.IsPinned) HidePopup(); };
        }

        _popup.Refresh();
        _popup.ShowAtCorner();
    }

    private void HidePopup()
    {
        if (_popup is null || !_popup.IsVisible) return;
        _popup.Hide();
        _popupHiddenAt = DateTime.UtcNow;
    }

    private void Refresh()
    {
        var svc = WorkService.Shared;
        svc.Reload();

        var remaining = svc.Remaining();
        var color = TrayIconRenderer.ColorFor(svc.State, remaining);

        var newIcon = TrayIconRenderer.Render(color);
        _notifyIcon.Icon = newIcon;
        _currentIcon?.Dispose();
        _currentIcon = newIcon;

        _notifyIcon.Text = BuildTooltip(svc, remaining);

        MaybeNotifyCheckoutApproaching(svc, remaining);

        if (_popup is { IsVisible: true }) _popup.Refresh();
    }

    /// <summary>
    /// macOS 버전의 퇴근 10분 전 / 정각 알림(NotificationService.scheduleCheckout) 대응.
    /// 토스트 대신 트레이 풍선 알림을 쓴다 — 별도 패키징 없이 되는 유일한 방법.
    /// </summary>
    private void MaybeNotifyCheckoutApproaching(WorkService svc, TimeSpan? remaining)
    {
        // 아이콘이 아직 안 떴으면(생성자 첫 Refresh) 스킵. 다음 30초 틱에 다시 시도된다.
        if (!_notifyIcon.Visible) return;

        if (svc.State != WorkState.Working || remaining is not { } r)
        {
            _notifiedForCheckIn = null;
            _reminderShown = false;
            _exactShown = false;
            return;
        }

        if (_notifiedForCheckIn != svc.Today?.CheckIn)
        {
            _notifiedForCheckIn = svc.Today?.CheckIn;
            _reminderShown = false;
            _exactShown = false;
        }

        if (!_reminderShown && r <= TimeSpan.FromMinutes(10) && r > TimeSpan.Zero)
        {
            _notifyIcon.ShowBalloonTip(5000, "10분 후 퇴근이에요 🏠", "오늘도 수고했어요.", WinForms.ToolTipIcon.Info);
            _reminderShown = true;
        }

        if (!_exactShown && r <= TimeSpan.Zero)
        {
            _notifyIcon.ShowBalloonTip(5000, "퇴근 시간이에요 🏠", "오늘도 수고했어요.", WinForms.ToolTipIcon.Info);
            _exactShown = true;
        }
    }

    private static string BuildTooltip(WorkService svc, TimeSpan? remaining)
    {
        // NotifyIcon.Text 는 길이 제한이 있어 짧게 유지한다.
        return svc.State switch
        {
            WorkState.Done =>
                $"퇴근 완료 · {KoreaTime.Time(svc.Today?.CheckOut)}",

            WorkState.Working when remaining is { } r && r > TimeSpan.Zero =>
                $"퇴근 {KoreaTime.Time(svc.ExpectedCheckout())} · {KoreaTime.Duration(r)} 남음",

            WorkState.Working =>
                $"퇴근 시간 지남 · 예정 {KoreaTime.Time(svc.ExpectedCheckout())}",

            _ => "집에가자 · 출근 전",
        };
    }

    public void Dispose()
    {
        WorkService.Shared.Changed -= OnWorkChanged;
        _timer.Stop();
        _watcher.Dispose();

        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _currentIcon?.Dispose();

        _popup?.Close();
    }
}
