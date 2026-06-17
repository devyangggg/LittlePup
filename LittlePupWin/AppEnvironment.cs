using System.Windows;
using System.Windows.Controls;
using LittlePupWin.Animation;
using LittlePupWin.Behavior;
using LittlePupWin.Core;
using LittlePupWin.DragDrop;
using LittlePupWin.Persistence;
using LittlePupWin.Profile;
using LittlePupWin.Walking;
using Microsoft.Win32;

namespace LittlePupWin;

public class AppEnvironment : IDisposable
{
    private readonly PetWindow     _window;
    private readonly PetController _controller;

    public AppEnvironment()
    {
        var loader  = new PetProfileLoader();
        var profile = loader.LoadDefault();

        var sheet   = SpriteSheet.Load(profile.SpriteSheet, profile.FrameSize);
        _window     = new PetWindow();
        _window.SizeTo(profile.FrameSize);

        var clock      = new FrameClock();
        var renderer   = new PetRenderer(_window);
        var animation  = new AnimationController(sheet, profile, clock, renderer);
        var scheduler  = new BehaviorScheduler(profile);
        var walkPath   = new WalkPathController();
        var drop       = new FileDropHandler();
        var store      = new StateStore();

        _controller = new PetController(
            profile, animation, scheduler, walkPath,
            _window, renderer, drop, store);

        _window.PetContextMenu = BuildMenu();
    }

    public void Start()    => _controller.Start();
    public void Shutdown() => _controller.Shutdown();

    private ContextMenu BuildMenu()
    {
        var menu = new ContextMenu();

        void Add(string header, Action action)
        {
            var item = new MenuItem { Header = header };
            item.Click += (_, _) => action();
            menu.Items.Add(item);
        }

        Add("Idle",  () => _controller.UserRequestedIdle());
        Add("Sit",   () => _controller.UserRequestedSit());
        Add("Sleep", () => _controller.UserRequestedSleep());
        Add("Walk",  () => _controller.UserRequestedWalk());
        Add("Run",   () => _controller.UserRequestedRun());
        menu.Items.Add(new Separator());
        Add("Feed",             () => _controller.UserRequestedFeed());
        Add("Bark",             () => _controller.UserRequestedBark());
        Add("Feed from file…",  FeedFromFile);
        menu.Items.Add(new Separator());
        Add("Quit", () => Application.Current.Shutdown());

        return menu;
    }

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

    public void Dispose() => _window.Close();
}
