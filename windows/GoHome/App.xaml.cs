using System;
using System.Threading;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;

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

        // 그래픽 드라이버 업데이트나 잠자기 복귀 뒤 GPU 렌더링이 깨져 팝업이 안 뜨는 일이 있었다.
        // 창이 작아서 CPU 로만 그려도 충분하다. 창을 만들기 전에 정해야 한다.
        RenderOptions.ProcessRenderMode = RenderMode.SoftwareOnly;

        _tray = new TrayApp();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _tray?.Dispose();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }
}
