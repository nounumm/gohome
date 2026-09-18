using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace GoHome.Services;

/// <summary>
/// 트레이 아이콘. macOS 버전의 실제 메뉴바 아이콘(gohomeApp.swift MenuBarIcon, SF Symbol "house.fill")과
/// 같은 모양을 쓴다 — SF Symbols 앱에서 내보낸 SVG 좌표를 그대로 벡터 경로로 옮겼다.
/// 색 규칙은 AppDelegate.updateStatusIcon 과 동일:
///   - 출근 전 / 퇴근 완료 → 색 지정 안 함(nil) → 시스템 기본(트레이 배경에 맞는 흑/백)
///   - 근무 중, 퇴근 30분 이상 남음 → 위와 동일하게 기본색
///   - 근무 중, 퇴근 30분 이내 → 오렌지→빨강 블렌딩 (지날수록 빨강에 가까워지고 초과해도 빨강에 고정)
/// </summary>
public static class TrayIconRenderer
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr hIcon);

    private static readonly Color Orange = Color.FromArgb(255, 149, 0);   // systemOrange
    private static readonly Color Red = Color.FromArgb(255, 59, 48);      // systemRed

    private const double WarningWindowSeconds = 1800; // 퇴근 30분 전부터 물들기 시작

    public static Color ColorFor(WorkState state, TimeSpan? remaining)
    {
        // macOS: 출근 전/퇴근 완료는 둘 다 iconColor = nil → 기본색. 별도 색을 주지 않는다.
        if (state != WorkState.Working) return Foreground();

        if (remaining is not { } r) return Foreground();

        var secs = r.TotalSeconds;
        if (secs > WarningWindowSeconds) return Foreground();

        var t = 1.0 - (secs / WarningWindowSeconds);
        return Blend(Orange, Red, t);
    }

    private static Color Foreground() =>
        ThemeInfo.IsTrayDark()
            ? Color.FromArgb(240, 240, 240)
            : Color.FromArgb(32, 32, 32);

    private static Color Blend(Color from, Color to, double t)
    {
        t = Math.Clamp(t, 0.0, 1.0);
        return Color.FromArgb(
            255,
            (int)Math.Round(from.R + (to.R - from.R) * t),
            (int)Math.Round(from.G + (to.G - from.G) * t),
            (int)Math.Round(from.B + (to.B - from.B) * t));
    }

    // house.fill SVG 의 viewBox 크기 (SF Symbols 앱에서 내보낸 원본 좌표계).
    private const float ViewBoxWidth = 15f;
    private const float ViewBoxHeight = 13f;
    private const float ContentFraction = 0.86f; // 배경이 없으니 캔버스를 거의 꽉 채운다

    /// <summary>집 모양 아이콘을 지정 색으로 그려 반환한다. 호출자가 Dispose 해야 한다.</summary>
    public static Icon Render(Color color)
    {
        var small = SystemInformation.SmallIconSize;
        int w = Math.Max(16, small.Width);
        int h = Math.Max(16, small.Height);

        using var bmp = new Bitmap(w, h);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);

            float scale = Math.Min(w * ContentFraction / ViewBoxWidth, h * ContentFraction / ViewBoxHeight);
            float houseW = ViewBoxWidth * scale;
            float houseH = ViewBoxHeight * scale;
            float offsetX = (w - houseW) / 2f;
            float offsetY = (h - houseH) / 2f;

            float TX(float x) => x * scale + offsetX;
            float TY(float y) => y * scale + offsetY;

            using var housePath = new GraphicsPath(FillMode.Winding);
            var path = housePath;
            // subpath 0
            path.StartFigure();
            path.AddBezier(TX(0.6035f), TY(6.4688f), TX(0.2285f), TY(6.4688f), TX(0f), TY(6.2109f), TX(0f), TY(5.9062f));
            path.AddBezier(TX(0f), TY(5.9062f), TX(0f), TY(5.7422f), TX(0.0762f), TY(5.5723f), TX(0.2285f), TY(5.4434f));
            path.AddLine(TX(0.2285f), TY(5.4434f), TX(6.334f), TY(0.3164f));
            path.AddBezier(TX(6.334f), TY(0.3164f), TX(6.5918f), TY(0.1055f), TX(6.8731f), TY(0f), TX(7.1543f), TY(0f));
            path.AddBezier(TX(7.1543f), TY(0f), TX(7.4356f), TY(0f), TX(7.7168f), TY(0.1055f), TX(7.9746f), TY(0.3164f));
            path.AddLine(TX(7.9746f), TY(0.3164f), TX(10.8691f), TY(2.7539f));
            path.AddLine(TX(10.8691f), TY(2.7539f), TX(10.8691f), TY(1.7109f));
            path.AddBezier(TX(10.8691f), TY(1.7109f), TX(10.8691f), TY(1.4531f), TX(11.0449f), TY(1.2832f), TX(11.3086f), TY(1.2832f));
            path.AddLine(TX(11.3086f), TY(1.2832f), TX(12.0996f), TY(1.2832f));
            path.AddBezier(TX(12.0996f), TY(1.2832f), TX(12.3574f), TY(1.2832f), TX(12.5273f), TY(1.4531f), TX(12.5273f), TY(1.7109f));
            path.AddLine(TX(12.5273f), TY(1.7109f), TX(12.5273f), TY(4.1426f));
            path.AddLine(TX(12.5273f), TY(4.1426f), TX(14.0801f), TY(5.4434f));
            path.AddBezier(TX(14.0801f), TY(5.4434f), TX(14.2324f), TY(5.5723f), TX(14.3086f), TY(5.7422f), TX(14.3086f), TY(5.9062f));
            path.AddBezier(TX(14.3086f), TY(5.9062f), TX(14.3086f), TY(6.2109f), TX(14.0801f), TY(6.4688f), TX(13.7109f), TY(6.4688f));
            path.AddBezier(TX(13.7109f), TY(6.4688f), TX(13.5293f), TY(6.4688f), TX(13.3652f), TY(6.375f), TX(13.2246f), TY(6.2519f));
            path.AddLine(TX(13.2246f), TY(6.2519f), TX(7.4062f), TY(1.3711f));
            path.AddBezier(TX(7.4062f), TY(1.3711f), TX(7.3242f), TY(1.3008f), TX(7.2363f), TY(1.2715f), TX(7.1543f), TY(1.2715f));
            path.AddBezier(TX(7.1543f), TY(1.2715f), TX(7.0723f), TY(1.2715f), TX(6.9844f), TY(1.3008f), TX(6.9082f), TY(1.3711f));
            path.AddLine(TX(6.9082f), TY(1.3711f), TX(1.084f), TY(6.2519f));
            path.AddBezier(TX(1.084f), TY(6.2519f), TX(0.9434f), TY(6.375f), TX(0.7852f), TY(6.4688f), TX(0.6035f), TY(6.4688f));
            path.AddLine(TX(0.6035f), TY(6.4688f), TX(0.6035f), TY(6.4688f));
            path.CloseFigure();
            // subpath 1
            path.StartFigure();
            path.AddLine(TX(1.8984f), TY(11.2031f), TX(1.8984f), TY(6.7207f));
            path.AddLine(TX(1.8984f), TY(6.7207f), TX(6.791f), TY(2.6191f));
            path.AddBezier(TX(6.791f), TY(2.6191f), TX(7.0137f), TY(2.4316f), TX(7.2891f), TY(2.4258f), TX(7.5117f), TY(2.6191f));
            path.AddLine(TX(7.5117f), TY(2.6191f), TX(12.4102f), TY(6.7207f));
            path.AddLine(TX(12.4102f), TY(6.7207f), TX(12.4102f), TY(11.2031f));
            path.AddBezier(TX(12.4102f), TY(11.2031f), TX(12.4102f), TY(12.0469f), TX(11.8828f), TY(12.5508f), TX(11.0156f), TY(12.5508f));
            path.AddLine(TX(11.0156f), TY(12.5508f), TX(3.2871f), TY(12.5508f));
            path.AddBezier(TX(3.2871f), TY(12.5508f), TX(2.4258f), TY(12.5508f), TX(1.8984f), TY(12.0469f), TX(1.8984f), TY(11.2031f));
            path.AddLine(TX(1.8984f), TY(11.2031f), TX(1.8984f), TY(11.2031f));
            path.CloseFigure();
            // subpath 2
            path.StartFigure();
            path.AddLine(TX(5.5664f), TY(11.4258f), TX(8.7422f), TY(11.4258f));
            path.AddLine(TX(8.7422f), TY(11.4258f), TX(8.7422f), TY(8.0449f));
            path.AddBezier(TX(8.7422f), TY(8.0449f), TX(8.7422f), TY(7.7695f), TX(8.5664f), TY(7.5938f), TX(8.291f), TY(7.5938f));
            path.AddLine(TX(8.291f), TY(7.5938f), TX(6.0234f), TY(7.5938f));
            path.AddBezier(TX(6.0234f), TY(7.5938f), TX(5.7481f), TY(7.5938f), TX(5.5664f), TY(7.7695f), TX(5.5664f), TY(8.0449f));
            path.AddLine(TX(5.5664f), TY(8.0449f), TX(5.5664f), TY(11.4258f));
            path.AddLine(TX(5.5664f), TY(11.4258f), TX(5.5664f), TY(11.4258f));
            path.CloseFigure();

            using var brush = new SolidBrush(color);
            g.FillPath(brush, housePath);
        }

        // GetHicon 이 만든 GDI 핸들은 우리가 정리해야 한다.
        IntPtr handle = bmp.GetHicon();
        try
        {
            using var temp = Icon.FromHandle(handle);
            return (Icon)temp.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }
}
