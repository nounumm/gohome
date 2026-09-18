using Microsoft.Win32;

namespace GoHome.Services;

/// <summary>
/// Windows 는 WPF 앱에 테마를 자동 적용해주지 않으므로 직접 읽는다.
/// 트레이(작업표시줄)와 앱 창의 테마 설정은 별개 키다.
/// </summary>
public static class ThemeInfo
{
    private const string PersonalizeKey =
        @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";

    /// <summary>작업표시줄·트레이가 어두운가. 트레이 아이콘 색을 정할 때 쓴다.</summary>
    public static bool IsTrayDark() => ReadIsDark("SystemUsesLightTheme");

    /// <summary>앱 창이 어두운 테마인가. 팝업 배색에 쓴다.</summary>
    public static bool IsAppDark() => ReadIsDark("AppsUseLightTheme");

    private static bool ReadIsDark(string valueName)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(PersonalizeKey);
            // 값이 0 이면 다크. 키가 없으면 라이트로 본다.
            return key?.GetValue(valueName) is int v && v == 0;
        }
        catch
        {
            return false;
        }
    }
}
