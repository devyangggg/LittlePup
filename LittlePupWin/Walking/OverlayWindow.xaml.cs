using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Imaging;

namespace LittlePupWin.Walking;

public partial class OverlayWindow : Window
{
    private const int GWL_EXSTYLE       = -20;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_TOOLWINDOW  = 0x00000080;

    private const uint SWP_NOMOVE    = 0x0002;
    private const uint SWP_NOSIZE    = 0x0001;
    private const uint SWP_NOACTIVATE = 0x0010;
    private static readonly IntPtr HWND_TOPMOST = new(-1);

    [DllImport("user32.dll")] private static extern int  GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] private static extern int  SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);

    public OverlayWindow()
    {
        InitializeComponent();
        Loaded += (_, _) => ConfigureWindow();
    }

    private void ConfigureWindow()
    {
        var hwnd  = new WindowInteropHelper(this).Handle;
        // click-through + hide from alt-tab / taskbar button
        int style = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, style | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW);
        // force above the taskbar (both are HWND_TOPMOST; explicit call wins tie)
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }

    public void SetFrame(BitmapSource frame, bool flipH)
    {
        PetImage.Source      = frame;
        FlipTransform.ScaleX  = flipH ? -1 : 1;
        FlipTransform.CenterX = Width / 2.0;
    }

    public void MoveTo(Point origin)
    {
        Left = origin.X;
        Top  = origin.Y;
    }

    public void SizeTo(int pixels)
    {
        Width  = pixels;
        Height = pixels;
    }
}
