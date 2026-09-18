using System;

namespace GoHome.Services;

/// <summary>
/// macOS 버전이 TimeZone(identifier: "Asia/Seoul") 을 하드코딩한 것과 같은 동작.
/// .NET 8 은 Windows 에서도 ICU 덕분에 IANA ID 가 먹지만,
/// ICU 가 비활성(Invariant globalization)인 환경을 대비해 Windows ID 로 폴백한다.
/// </summary>
public static class KoreaTime
{
    private static readonly TimeZoneInfo Zone = Resolve();

    private static TimeZoneInfo Resolve()
    {
        string[] candidates = { "Asia/Seoul", "Korea Standard Time" };
        foreach (var id in candidates)
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
            catch (TimeZoneNotFoundException) { }
            catch (InvalidTimeZoneException) { }
        }
        return TimeZoneInfo.Local;
    }

    public static DateTimeOffset Now => TimeZoneInfo.ConvertTime(DateTimeOffset.Now, Zone);

    public static DateTimeOffset ToKst(DateTimeOffset t) => TimeZoneInfo.ConvertTime(t, Zone);

    /// <summary>저장 파일의 키. "yyyy-MM-dd" (KST 기준)</summary>
    public static string DateKey(DateTimeOffset t) => ToKst(t).ToString("yyyy-MM-dd");

    public static string DateKeyToday() => DateKey(DateTimeOffset.Now);

    /// <summary>"HH:mm", null 이면 "--:--"</summary>
    public static string Time(DateTimeOffset? t) =>
        t is null ? "--:--" : ToKst(t.Value).ToString("HH:mm");

    /// <summary>"2026.07.30 목"</summary>
    public static string LongDate(DateTimeOffset t) =>
        ToKst(t).ToString("yyyy.MM.dd ddd", new System.Globalization.CultureInfo("ko-KR"));

    /// <summary>"07.30 목"</summary>
    public static string ShortDate(DateTimeOffset t) =>
        ToKst(t).ToString("MM.dd ddd", new System.Globalization.CultureInfo("ko-KR"));

    /// <summary>"HH:mm" 문자열을 오늘(KST) 날짜와 합쳐 시각으로 만든다. 형식이 틀리면 null.</summary>
    public static DateTimeOffset? ParseTimeToday(string text)
    {
        if (!DateTime.TryParseExact(
                text.Trim(), "HH:mm",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None,
                out var t))
            return null;

        var today = ToKst(DateTimeOffset.Now);
        return new DateTimeOffset(today.Year, today.Month, today.Day, t.Hour, t.Minute, 0, today.Offset);
    }

    /// <summary>같은 날(KST)의 지정 시각.</summary>
    public static DateTimeOffset AtHour(DateTimeOffset t, int hour)
    {
        var k = ToKst(t);
        return new DateTimeOffset(k.Year, k.Month, k.Day, hour, 0, 0, k.Offset);
    }

    /// <summary>"2h 15m"</summary>
    public static string Duration(TimeSpan span)
    {
        if (span < TimeSpan.Zero) span = TimeSpan.Zero;
        return $"{(int)span.TotalHours}h {span.Minutes}m";
    }
}
