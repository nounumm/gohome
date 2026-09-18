using System;
using Microsoft.Win32;

namespace GoHome.Services;

/// <summary>
/// 로그인 시 자동 실행. macOS 의 로그인 항목 대응.
/// 이 앱은 상주해야 잠금 해제를 감지할 수 있으므로 사실상 필수 기능이다.
/// </summary>
public static class StartupService
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "GoHome";

    public static bool IsEnabled
    {
        get
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKey);
                return key?.GetValue(ValueName) is string s && s.Length > 0;
            }
            catch
            {
                return false;
            }
        }
    }

    public static void SetEnabled(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
            if (key is null) return;

            if (enabled)
            {
                // 단일 파일 배포에서도 올바른 경로를 주는 건 ProcessPath 다.
                // (Assembly.Location 은 단일 파일에서 빈 문자열)
                var exe = Environment.ProcessPath;
                if (string.IsNullOrEmpty(exe)) return;
                key.SetValue(ValueName, $"\"{exe}\"");
            }
            else
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
            }
        }
        catch
        {
            // 정책으로 막힌 환경이면 조용히 무시한다.
        }
    }
}
