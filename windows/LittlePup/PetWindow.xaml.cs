using System;
using System.Windows;
using System.Windows.Interop;
using LittlePup.Animation;
using LittlePup.Behavior;
using LittlePup.Core;
using LittlePup.Profile;

namespace LittlePup;

// The hidden, always-minimized window whose taskbar button icon is the pet. It wires up the
// animation stack once it has a native window handle (HWND) to push icons to.
public partial class PetWindow : Window
{
    private PetController? _controller;
    private IconRenderer? _iconRenderer;
    private SpriteSheet? _sheet;
    private FrameClock? _clock;

    public PetWindow()
    {
        InitializeComponent();
        SourceInitialized += OnSourceInitialized;
        // If the user clicks the taskbar button (which would restore the window), re-minimize so
        // no empty window ever appears — the only UI is the taskbar icon + its Jump List.
        StateChanged += (_, _) =>
        {
            if (WindowState != WindowState.Minimized) WindowState = WindowState.Minimized;
        };
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        try
        {
            var loader = new PetProfileLoader();
            var profile = loader.LoadDefaultProfile();
            var bitmap = loader.LoadSpriteSheet(profile);

            _sheet = new SpriteSheet(bitmap, profile.FrameSize);
            _clock = new FrameClock();
            _iconRenderer = new IconRenderer(hwnd);

            var anim = new AnimationController(_sheet, profile, _clock, _iconRenderer);
            var scheduler = new BehaviorScheduler(anim, profile);
            _controller = new PetController(anim, scheduler);
            _controller.Start();
        }
        catch (Exception ex)
        {
            MessageBox.Show("LittlePup failed to start:\n" + ex.Message, "LittlePup");
        }
    }

    // Called by App (from CLI args or forwarded pipe messages) to apply a Jump List command.
    public void HandleAction(string action) => _controller?.HandleAction(action);

    protected override void OnClosed(EventArgs e)
    {
        _controller?.Stop();
        _clock?.Stop();
        _iconRenderer?.Dispose();
        _sheet?.Dispose();
        base.OnClosed(e);
    }
}
