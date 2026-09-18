using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using GoHome.Services;

namespace GoHome;

public partial class PopupWindow : Window
{
    /// <summary>출근 내역 한 줄. 색상은 미리 계산해서 바인딩만 하면 되게 한다.</summary>
    public sealed class RecentRow
    {
        public string Day { get; init; } = "";
        public string TimeRange { get; init; } = "";
        public string BadgeText { get; init; } = "";
        public Visibility BadgeVisibility { get; init; } = Visibility.Collapsed;
        public Brush BadgeBackground { get; init; } = Brushes.Transparent;
        public Brush BadgeForeground { get; init; } = Brushes.Transparent;
    }

    private bool _suppressEvents;
    private bool _isEditingCheckIn;

    /// <summary>켜져 있으면 포커스를 잃어도 자동으로 안 닫힌다. 트레이 아이콘 클릭으로는 여전히 닫을 수 있다.</summary>
    public bool IsPinned { get; private set; }

    // 테마별 배색. Windows 는 WPF 창에 테마를 자동 적용하지 않으므로 직접 넣는다.
    private static readonly Color DarkCard = Color.FromRgb(0x2B, 0x2B, 0x2F);
    private static readonly Color DarkBorder = Color.FromRgb(0x3F, 0x3F, 0x46);
    private static readonly Color DarkText = Color.FromRgb(0xF2, 0xF2, 0xF4);
    private static readonly Color LightCard = Color.FromRgb(0xFB, 0xFB, 0xFD);
    private static readonly Color LightBorder = Color.FromRgb(0xD8, 0xD8, 0xDE);
    private static readonly Color LightText = Color.FromRgb(0x1A, 0x1A, 0x1E);

    // macOS 버전은 초과근무만 빨강이고 나머지는 초록이다 (회색 아님).
    private static readonly Brush OvertimeBg = new SolidColorBrush(Color.FromArgb(26, 0xEF, 0x44, 0x44));
    private static readonly Brush OvertimeFg = new SolidColorBrush(Color.FromRgb(0xEF, 0x44, 0x44));
    private static readonly Brush NormalBg = new SolidColorBrush(Color.FromArgb(26, 0x22, 0xC5, 0x5E));
    private static readonly Brush NormalFg = new SolidColorBrush(Color.FromRgb(0x22, 0xC5, 0x5E));

    // 카드/버튼용 옅은 표면색. macOS controlBackgroundColor 에 대응.
    private static readonly Color DarkSurface = Color.FromRgb(0x35, 0x35, 0x3A);
    private static readonly Color LightSurface = Color.FromRgb(0xF1, 0xF5, 0xF9);
    private static readonly Color DarkButtonBorder = Color.FromRgb(0x52, 0x52, 0x5B);
    private static readonly Color LightButtonBorder = Color.FromRgb(0xD8, 0xD8, 0xDE);

    public PopupWindow()
    {
        InitializeComponent();
        ApplyTheme();

        // SizeToContent 로 높이가 바뀔 때마다 우하단에 다시 붙인다.
        SizeChanged += (_, _) => Reposition();
        ContentRendered += (_, _) => Reposition();
    }

    private void ApplyTheme()
    {
        bool dark = ThemeInfo.IsAppDark();

        Card.Background = new SolidColorBrush(dark ? DarkCard : LightCard);
        Card.BorderBrush = new SolidColorBrush(dark ? DarkBorder : LightBorder);

        var text = new SolidColorBrush(dark ? DarkText : LightText);
        Foreground = text;
        HalfDayCheck.Foreground = text;
        AutoStartCheck.Foreground = text;

        var divider = new SolidColorBrush(dark ? DarkBorder : LightBorder);
        HeaderDivider.Background = divider;
        ActionDivider.Background = divider;

        var surface = new SolidColorBrush(dark ? DarkSurface : LightSurface);
        CheckInCard.Background = surface;
        CheckOutCard.Background = surface;

        var btnBorder = new SolidColorBrush(dark ? DarkButtonBorder : LightButtonBorder);
        CheckInButton.Background = surface;
        CheckInButton.BorderBrush = btnBorder;
        CheckInButton.Foreground = text;
        CheckOutButton.Background = surface;
        CheckOutButton.BorderBrush = btnBorder;
        CheckOutButton.Foreground = text;
    }

    public void ShowAtCorner()
    {
        Show();
        Activate();
        UpdateLayout();
        Reposition();
    }

    /// <summary>
    /// 작업표시줄을 피해 주 모니터 우하단에 붙인다.
    /// SystemParameters.WorkArea 는 DIP 단위라 DPI 변환이 필요 없다.
    /// (다중 모니터에서는 항상 주 모니터에 뜬다 — 필요하면 커서 기준으로 바꿀 수 있음)
    /// </summary>
    private void Reposition()
    {
        var work = SystemParameters.WorkArea;
        if (ActualWidth <= 0 || ActualHeight <= 0) return;

        Left = work.Right - ActualWidth;
        Top = work.Bottom - ActualHeight;
    }

    public void Refresh()
    {
        var svc = WorkService.Shared;
        var today = svc.Today;

        _suppressEvents = true;
        try
        {
            // macOS 원본(PopoverView.swift)은 상태 텍스트에 색을 따로 안 준다. 기본 텍스트색 그대로.
            StatusLabel.Text = svc.StatusText;

            CheckInValue.Text = KoreaTime.Time(today?.CheckIn);
            // 타이핑 중에 30초 타이머가 돌아서 편집 중인 입력칸을 리셋해버리지 않게 한다.
            if (!_isEditingCheckIn)
            {
                CheckInValue.Visibility = Visibility.Visible;
                CheckInEditBox.Visibility = Visibility.Collapsed;
            }

            bool checkedOut = today?.CheckOut is not null;
            CheckOutCaption.Text = checkedOut ? "퇴근" : "퇴근 예정";
            CheckOutValue.Text = KoreaTime.Time(today?.CheckOut ?? svc.ExpectedCheckout());

            RemainingLabel.Text = BuildRemainingText(svc);

            HalfDayCheck.IsChecked = svc.IsHalfDay;
            HalfDayCheck.IsEnabled = svc.State != WorkState.Done;

            CheckInButton.IsEnabled = svc.State == WorkState.BeforeCheckIn;
            CheckOutButton.IsEnabled = svc.State == WorkState.Working;

            var rows = BuildRecentRows();
            HistoryList.ItemsSource = rows;
            HistoryEmptyLabel.Visibility = rows.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

            AutoStartCheck.IsChecked = StartupService.IsEnabled;
        }
        finally
        {
            _suppressEvents = false;
        }
    }

    private static string BuildRemainingText(WorkService svc)
    {
        switch (svc.State)
        {
            case WorkState.BeforeCheckIn:
                return "잠금을 해제하면 자동으로 출근이 기록돼요. (08~15시, 13~15시는 반차로 처리)";

            case WorkState.Working:
                if (svc.Remaining() is not { } r) return "";
                return r > TimeSpan.Zero
                    ? $"{KoreaTime.Duration(r)} 남음"
                    : $"{KoreaTime.Duration(-r)} 초과";

            case WorkState.Done:
                return svc.Today?.Worked is { } w
                    ? $"{KoreaTime.Duration(w)} 근무 · 오늘도 수고했어요."
                    : "오늘도 수고했어요.";

            default:
                return "";
        }
    }

    private static List<RecentRow> BuildRecentRows()
    {
        var rows = new List<RecentRow>();

        foreach (var record in WorkService.Shared.Recent)
        {
            if (record.CheckIn is null)
            {
                rows.Add(new RecentRow
                {
                    Day = KoreaTime.ShortDate(record.Date),
                    TimeRange = "기록 없음",
                });
                continue;
            }

            var timeRange = $"{KoreaTime.Time(record.CheckIn)} – {KoreaTime.Time(record.CheckOut)}";

            rows.Add(new RecentRow
            {
                Day = KoreaTime.ShortDate(record.Date),
                TimeRange = timeRange,
                BadgeText = record.Worked is { } w ? KoreaTime.Duration(w) : "",
                BadgeVisibility = record.Worked is null ? Visibility.Collapsed : Visibility.Visible,
                BadgeBackground = record.IsOvertime ? OvertimeBg : NormalBg,
                BadgeForeground = record.IsOvertime ? OvertimeFg : NormalFg,
            });
        }

        return rows;
    }

    private void CheckInButton_Click(object sender, RoutedEventArgs e)
    {
        if (_suppressEvents) return;
        WorkService.Shared.CheckIn();
        Refresh();
    }

    private void CheckOutButton_Click(object sender, RoutedEventArgs e)
    {
        if (_suppressEvents) return;
        WorkService.Shared.CheckOut();
        Refresh();
    }

    private void HalfDayCheck_Click(object sender, RoutedEventArgs e)
    {
        if (_suppressEvents) return;
        WorkService.Shared.SetHalfDay(HalfDayCheck.IsChecked == true);
        Refresh();
    }

    // 출근 시각: 값을 누르면 그 자리에서 바로 입력칸으로 바뀐다 (macOS 처럼).

    private void CheckInValue_Click(object sender, MouseButtonEventArgs e)
    {
        if (WorkService.Shared.Today?.CheckIn is not { } t) return;

        _isEditingCheckIn = true;
        CheckInEditBox.Text = KoreaTime.Time(t);
        CheckInEditBox.BorderBrush = Brushes.Transparent;
        CheckInValue.Visibility = Visibility.Collapsed;
        CheckInEditBox.Visibility = Visibility.Visible;
        CheckInEditBox.Focus();
        CheckInEditBox.SelectAll();
    }

    private void CheckInEditBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) TrySaveCheckInEdit();
        else if (e.Key == Key.Escape) CancelCheckInEdit();
    }

    private void CheckInEditBox_LostFocus(object sender, RoutedEventArgs e)
    {
        if (_isEditingCheckIn) TrySaveCheckInEdit();
    }

    private void TrySaveCheckInEdit()
    {
        if (KoreaTime.ParseTimeToday(CheckInEditBox.Text) is not { } t)
        {
            CheckInEditBox.BorderBrush = Brushes.Red;
            return;
        }

        _isEditingCheckIn = false;
        WorkService.Shared.UpdateCheckIn(t);
        Refresh();
    }

    private void CancelCheckInEdit()
    {
        _isEditingCheckIn = false;
        Refresh();
    }

    // 헤더 아이콘 / 서브 화면 전환. 메인 ↔ 출근 내역 ↔ 설정, 한 번에 하나만 보인다.

    private void PinIcon_Click(object sender, MouseButtonEventArgs e)
    {
        IsPinned = !IsPinned;
        PinIcon.Opacity = IsPinned ? 1.0 : 0.35;
    }

    private void HistoryIcon_Click(object sender, MouseButtonEventArgs e)
    {
        MainPage.Visibility = Visibility.Collapsed;
        HistoryPage.Visibility = Visibility.Visible;
    }

    private void SettingsIcon_Click(object sender, MouseButtonEventArgs e)
    {
        MainPage.Visibility = Visibility.Collapsed;
        SettingsPage.Visibility = Visibility.Visible;
    }

    private void CloseSubPage_Click(object sender, MouseButtonEventArgs e)
    {
        HistoryPage.Visibility = Visibility.Collapsed;
        SettingsPage.Visibility = Visibility.Collapsed;
        MainPage.Visibility = Visibility.Visible;
    }

    private void AutoStartCheck_Click(object sender, RoutedEventArgs e)
    {
        if (_suppressEvents) return;
        StartupService.SetEnabled(AutoStartCheck.IsChecked == true);
    }

    private void QuitLink_Click(object sender, MouseButtonEventArgs e)
    {
        System.Windows.Application.Current.Shutdown();
    }
}
