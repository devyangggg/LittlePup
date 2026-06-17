using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media.Imaging;

namespace LittlePupWin;

public partial class PetWindow : Window
{
    private ContextMenu? _petContextMenu;

    public ContextMenu? PetContextMenu
    {
        get => _petContextMenu;
        set
        {
            _petContextMenu = value;
            if (value != null)
                // after every menu dismissal, minimize so next taskbar click re-fires OnActivated
                value.Closed += (_, _) => WindowState = WindowState.Minimized;
        }
    }

    public PetWindow()
    {
        InitializeComponent();
        Left        = -10;
        Top         = -10;
        WindowState = WindowState.Minimized;  // start minimized; taskbar button still shows
    }

    protected override void OnActivated(EventArgs e)
    {
        base.OnActivated(e);
        WindowState = WindowState.Normal;  // un-minimize so we can show the menu
        if (PetContextMenu is null) return;
        PetContextMenu.Placement = PlacementMode.MousePoint;
        PetContextMenu.IsOpen    = true;
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        base.OnClosing(e);
        Application.Current.Shutdown();
    }

    public void SetFrame(BitmapSource frame, bool flipH) => Icon = frame;

    public void MoveTo(Point origin) { Left = origin.X; Top = origin.Y; }
    public void SizeTo(int pixels)   { }
}
