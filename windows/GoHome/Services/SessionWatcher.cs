using System;
using Microsoft.Win32;

namespace GoHome.Services;

/// <summary>
/// macOS ScreenWakeService 대응.
///
/// 맥은 "화면이 깨어남"이 곧 "자리에 앉음"이지만, Windows 에서는 잠금 해제가 더 정확한 신호다.
///   SessionUnlock   — Win+L 잠금 해제 (com.apple.screenIsUnlocked 에 해당)
///   SessionLogon    — 로그온
///   ConsoleConnect  — 사용자 전환으로 돌아옴 (sessionDidBecomeActive 에 해당)
///   PowerModes.Resume — 절전/최대절전 복귀 (didWake 에 해당)
///
/// 주의: SystemEvents 는 전용 백그라운드 스레드에서 콜백을 던진다.
/// UI 를 만지는 쪽으로 마샬링하는 건 호출자 책임.
/// </summary>
public sealed class SessionWatcher : IDisposable
{
    private readonly Action _onWake;
    private bool _started;

    public SessionWatcher(Action onWake) => _onWake = onWake;

    public void Start()
    {
        if (_started) return;
        SystemEvents.SessionSwitch += OnSessionSwitch;
        SystemEvents.PowerModeChanged += OnPowerModeChanged;
        _started = true;
    }

    public void Stop()
    {
        if (!_started) return;
        SystemEvents.SessionSwitch -= OnSessionSwitch;
        SystemEvents.PowerModeChanged -= OnPowerModeChanged;
        _started = false;
    }

    private void OnSessionSwitch(object? sender, SessionSwitchEventArgs e)
    {
        if (e.Reason is SessionSwitchReason.SessionUnlock
                     or SessionSwitchReason.SessionLogon
                     or SessionSwitchReason.ConsoleConnect)
        {
            _onWake();
        }
    }

    private void OnPowerModeChanged(object? sender, PowerModeChangedEventArgs e)
    {
        if (e.Mode == PowerModes.Resume) _onWake();
    }

    public void Dispose() => Stop();
}
