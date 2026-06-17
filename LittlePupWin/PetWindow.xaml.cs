using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;

namespace LittlePupWin;

public partial class PetWindow : Window
{
    public ContextMenu? PetContextMenu { get; set; }

    public PetWindow()
    {
        InitializeComponent();
        // park the 1×1 invisible window off the visible desktop
        Left = -10;
        Top  = -10;
    }

    protected override void OnActivated(EventArgs e)
    {
        base.OnActivated(e);
        // user clicked the taskbar button → show the control menu
        if (PetContextMenu is null) return;
        PetContextMenu.Placement = System.Windows.Controls.Primitives.PlacementMode.MousePoint;
        PetContextMenu.IsOpen    = true;
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        base.OnClosing(e);
        Application.Current.Shutdown();
    }

    // animates the taskbar button icon — the only visible dog
    public void SetFrame(BitmapSource frame, bool flipH) => Icon = frame;

    // still called by PetController during walk; harmless on a hidden 1×1 window
    public void MoveTo(Point origin) { Left = origin.X; Top = origin.Y; }
    public void SizeTo(int pixels)   { }
}
