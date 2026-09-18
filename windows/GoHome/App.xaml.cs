using System;
using System.Threading;
using System.Windows;

namespace GoHome;

public partial class App : Application
{
    private TrayApp? _tray;
    private Mutex? _singleInstance;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 트레이 아이콘이 두 개 생기는 걸 막는다.
        _singleInstance = new Mutex(initiallyOwned: true, @"Local\GoHome.SingleInstance", out bool isFirst);
        if (!isFirst)
        {
            Shutdown();
            return;
        }

        _tray = new TrayApp();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _tray?.Dispose();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }
}
