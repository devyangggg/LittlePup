using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Imaging;

namespace LittlePupWin.Walking;

public partial class OverlayWindow : Window
{
    private const int GWL_EXSTYLE    = -20;
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_TOOLWINDOW = 0x00000080;

    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hwnd, int index, int value);

    public OverlayWindow()
    {
        InitializeComponent();
        Loaded += (_, _) => MakeClickThrough();
    }

    private void MakeClickThrough()
    {
        var hwnd  = new WindowInteropHelper(this).Handle;
        int style = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, style | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW);
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
