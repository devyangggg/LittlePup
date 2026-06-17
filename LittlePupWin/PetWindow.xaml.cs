using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media.Imaging;

namespace LittlePupWin;

public partial class PetWindow : Window
{
    private const int GWL_EXSTYLE       = -20;
    private const int WS_EX_NOACTIVATE  = 0x08000000;  // clicking pet never steals focus

    private static readonly IntPtr HWND_TOPMOST  = new(-1);
    private const uint SWP_NOMOVE    = 0x0002;
    private const uint SWP_NOSIZE    = 0x0001;
    private const uint SWP_NOACTIVATE = 0x0010;

    [DllImport("user32.dll")] static extern int  GetWindowLong(IntPtr hwnd, int idx);
    [DllImport("user32.dll")] static extern int  SetWindowLong(IntPtr hwnd, int idx, int val);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);

    public ContextMenu? PetContextMenu { get; set; }

    public PetWindow()
    {
        InitializeComponent();
        Loaded += (_, _) => ConfigureWindow();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        base.OnClosing(e);
        Application.Current.Shutdown();
    }

    private void ConfigureWindow()
    {
        var hwnd  = new WindowInteropHelper(this).Handle;
        // Don't steal focus when the user clicks the sprite
        int style = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, style | WS_EX_NOACTIVATE);
        // Stay above the taskbar so the dog is always visible
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }

    public void SetFrame(BitmapSource frame, bool flipH)
    {
        PetImage.Source      = frame;
        FlipTransform.ScaleX  = flipH ? -1 : 1;
        FlipTransform.CenterX = Width / 2.0;
        Icon = frame;  // taskbar button icon matches the current animation frame
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

    private void OnRightClick(object sender, MouseButtonEventArgs e)
    {
        if (PetContextMenu is null) return;
        PetContextMenu.PlacementTarget = this;
        PetContextMenu.IsOpen = true;
        e.Handled = true;
    }
}
