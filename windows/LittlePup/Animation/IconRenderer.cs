using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace LittlePup.Animation;

// The Windows analog of DockRenderer: pushes each animation frame to the taskbar button by setting
// the owning window's icon via WM_SETICON. Generates both a 32px (ICON_BIG) and 16px (ICON_SMALL)
// HICON per frame, and destroys the previous handles to avoid leaking GDI objects.
public sealed class IconRenderer : IDisposable
{
    private const int WM_SETICON = 0x0080;
    private const int ICON_SMALL = 0;
    private const int ICON_BIG = 1;

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool DestroyIcon(IntPtr hIcon);

    private readonly IntPtr _hwnd;
    private IntPtr _bigIcon = IntPtr.Zero;
    private IntPtr _smallIcon = IntPtr.Zero;

    public IconRenderer(IntPtr hwnd)
    {
        _hwnd = hwnd;
    }

    public void SetIcon(Bitmap frame)
    {
        using var big = Scaled(frame, 32);
        using var small = Scaled(frame, 16);

        IntPtr newBig = big.GetHicon();
        IntPtr newSmall = small.GetHicon();

        SendMessage(_hwnd, WM_SETICON, (IntPtr)ICON_BIG, newBig);
        SendMessage(_hwnd, WM_SETICON, (IntPtr)ICON_SMALL, newSmall);

        if (_bigIcon != IntPtr.Zero) DestroyIcon(_bigIcon);
        if (_smallIcon != IntPtr.Zero) DestroyIcon(_smallIcon);
        _bigIcon = newBig;
        _smallIcon = newSmall;
    }

    // Nearest-neighbor keeps the pixel art crisp when scaling the 128px frame down to icon size.
    private static Bitmap Scaled(Bitmap src, int size)
    {
        var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using var g = Graphics.FromImage(bmp);
        g.InterpolationMode = InterpolationMode.NearestNeighbor;
        g.PixelOffsetMode = PixelOffsetMode.Half;
        g.DrawImage(src, 0, 0, size, size);
        return bmp;
    }

    public void Dispose()
    {
        if (_bigIcon != IntPtr.Zero) DestroyIcon(_bigIcon);
        if (_smallIcon != IntPtr.Zero) DestroyIcon(_smallIcon);
        _bigIcon = IntPtr.Zero;
        _smallIcon = IntPtr.Zero;
    }
}
