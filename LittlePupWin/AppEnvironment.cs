using System.Windows;
using LittlePupWin.Animation;
using LittlePupWin.Behavior;
using LittlePupWin.Core;
using LittlePupWin.DragDrop;
using LittlePupWin.Menu;
using LittlePupWin.Persistence;
using LittlePupWin.Profile;
using LittlePupWin.Walking;
using Microsoft.Win32;

namespace LittlePupWin;

public class AppEnvironment : IDisposable
{
    private readonly OverlayWindow    _overlay;
    private readonly TrayMenuBuilder  _tray;
    private readonly PetController    _controller;

    public AppEnvironment()
    {
        var loader  = new PetProfileLoader();
        var profile = loader.LoadDefault();

        var sheet   = SpriteSheet.Load(profile.SpriteSheet, profile.FrameSize);
        _overlay    = new OverlayWindow();
        _overlay.SizeTo(profile.FrameSize);

        var clock      = new FrameClock();
        var renderer   = new PetRenderer(_overlay);
        var animation  = new AnimationController(sheet, profile, clock, renderer);
        var scheduler  = new BehaviorScheduler(profile);
        var walkPath   = new WalkPathController();
        var drop       = new FileDropHandler();
        var store      = new StateStore();

        _controller = new PetController(
            profile, animation, scheduler, walkPath,
            _overlay, renderer, drop, store);

        var actions = new TrayMenuActions(
            OnIdle:        () => _controller.UserRequestedIdle(),
            OnSit:         () => _controller.UserRequestedSit(),
            OnSleep:       () => _controller.UserRequestedSleep(),
            OnWalk:        () => _controller.UserRequestedWalk(),
            OnRun:         () => _controller.UserRequestedRun(),
            OnFeed:        () => _controller.UserRequestedFeed(),
            OnBark:        () => _controller.UserRequestedBark(),
            OnFeedFromFile: FeedFromFile,
            OnQuit:        QuitApp
        );
        _tray = new TrayMenuBuilder(actions);
    }

    public void Start()  => _controller.Start();
    public void Shutdown() => _controller.Shutdown();

    private void FeedFromFile()
    {
        var dlg = new OpenFileDialog
        {
            Title  = "Choose a file to feed LittlePup",
            Filter = "All files (*.*)|*.*"
        };
        if (dlg.ShowDialog() == true)
            _controller.HandleDroppedFiles([dlg.FileName]);
    }

    private static void QuitApp()
    {
        Application.Current.Dispatcher.Invoke(() => Application.Current.Shutdown());
    }

    public void Dispose()
    {
        _tray.Dispose();
        _overlay.Close();
    }
}
