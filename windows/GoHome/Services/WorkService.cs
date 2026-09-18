using System;
using System.Collections.Generic;
using GoHome.Models;

namespace GoHome.Services;

public enum WorkState { BeforeCheckIn, Working, Done }

/// <summary>
/// macOS 버전 WorkViewModel 에 대응. 구글 캘린더 연동은 빠졌고,
/// 반차는 캘린더 대신 사용자가 직접 켠다.
/// </summary>
public sealed class WorkService
{
    public static readonly WorkService Shared = new();

    /// <summary>기록이 바뀌었을 때. UI 스레드에서 발생한다는 보장은 없다.</summary>
    public event Action? Changed;

    private readonly StorageService _storage = StorageService.Shared;

    public WorkRecord? Today { get; private set; }
    public IReadOnlyList<WorkRecord> Recent { get; private set; } = Array.Empty<WorkRecord>();

    private WorkService() => Reload();

    public void Reload()
    {
        Today = _storage.Today();
        Recent = _storage.Recent();
    }

    public WorkState State
    {
        get
        {
            if (Today?.CheckOut is not null) return WorkState.Done;
            if (Today?.CheckIn is not null) return WorkState.Working;
            return WorkState.BeforeCheckIn;
        }
    }

    public string StatusText => State switch
    {
        WorkState.Done => "퇴근 완료",
        WorkState.Working => "일하는 중",
        _ => "출근 전",
    };

    public bool IsHalfDay => Today?.HalfDay ?? false;

    /// <summary>
    /// 퇴근 예정 시각.
    /// 일반 근무는 출근 + 9시간, 반차는 4시간 근무 + 12~13시 점심 제외.
    /// (macOS WorkViewModel.expectedCheckout / calcWithLunchBreak 과 동일한 규칙)
    /// </summary>
    public DateTimeOffset? ExpectedCheckout()
    {
        if (Today?.CheckIn is not { } checkIn) return null;

        return IsHalfDay
            ? WithLunchBreak(checkIn, TimeSpan.FromHours(4))
            : checkIn + TimeSpan.FromHours(9);
    }

    private static DateTimeOffset WithLunchBreak(DateTimeOffset checkIn, TimeSpan work)
    {
        var noon = KoreaTime.AtHour(checkIn, 12);
        var onePm = KoreaTime.AtHour(checkIn, 13);

        var remaining = work;
        var current = checkIn;

        if (current < noon)
        {
            var beforeLunch = noon - current;
            if (beforeLunch >= remaining) return current + remaining;
            remaining -= beforeLunch;
            current = onePm;
        }
        else if (current < onePm)
        {
            current = onePm;
        }

        return current + remaining;
    }

    /// <summary>퇴근까지 남은 시간. 근무 중이 아니면 null.</summary>
    public TimeSpan? Remaining()
    {
        if (State != WorkState.Working) return null;
        if (ExpectedCheckout() is not { } expected) return null;
        return expected - DateTimeOffset.Now;
    }

    /// <summary>
    /// 오후 반차 출근 시간대: 13:00:00 ~ 15:00. 이 사이에 출근하면 자동으로 반차 처리한다.
    /// 그 전/후엔 체크박스로 수동 지정.
    /// </summary>
    private static readonly TimeSpan HalfDayAutoStart = new(13, 0, 0);
    private static readonly TimeSpan HalfDayAutoEnd = new(15, 0, 0);

    public void CheckIn()
    {
        if (!_storage.CheckIn()) return;

        Reload();
        ApplyHalfDayAutoRule();
        Notify();
    }

    /// <summary>
    /// 출근 시각을 고친다. 자동 감지가 엉뚱한 시각에 찍혔을 때 쓴다.
    /// macOS 버전 updateCheckIn(date:) 대응. 그날 출근 기록이 없으면 아무 일도 안 한다.
    /// </summary>
    public void UpdateCheckIn(DateTimeOffset time)
    {
        if (!_storage.UpdateCheckIn(time)) return;

        Reload();
        ApplyHalfDayAutoRule();
        Notify();
    }

    private void ApplyHalfDayAutoRule()
    {
        if (Today?.CheckIn is not { } t) return;
        var tod = KoreaTime.ToKst(t).TimeOfDay;
        if (tod >= HalfDayAutoStart && tod <= HalfDayAutoEnd)
            _storage.SetHalfDay(true);
    }

    public void CheckOut()
    {
        if (_storage.CheckOut()) Notify();
    }

    public void SetHalfDay(bool value)
    {
        if (IsHalfDay == value) return;
        _storage.SetHalfDay(value);
        Notify();
    }

    /// <summary>
    /// 잠금 해제 / 절전 복귀 시 호출. macOS ScreenWakeService 의 판정 규칙을 기반으로 하되,
    /// 오후 반차 출근(13:00~15:00)도 자동으로 잡을 수 있도록 상한을 15시까지 늘렸다.
    /// 08시~15시 사이의 첫 신호에만 출근을 찍는다.
    /// </summary>
    public void HandleWake()
    {
        Reload();          // 날짜가 바뀌었을 수 있으므로 항상 갱신
        Changed?.Invoke();

        var tod = KoreaTime.Now.TimeOfDay;
        if (tod < TimeSpan.FromHours(8) || tod > HalfDayAutoEnd) return;
        if (Today?.CheckIn is not null) return;

        CheckIn();
    }

    private void Notify()
    {
        Reload();
        Changed?.Invoke();
    }
}
