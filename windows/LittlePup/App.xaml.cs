using System;
using System.Linq;
using System.Windows;
using LittlePup.Ipc;
using LittlePup.Menu;

namespace LittlePup;

// Entry point. Enforces a single running instance: a second launch (e.g. from a Jump List task)
// forwards its --action to the running instance over a named pipe, then exits — so the pet on the
// taskbar is controlled in-process, mirroring how the macOS Dock menu closures work.
public partial class App : Application
{
    private const string ActionPrefix = "--action=";
    private SingleInstance? _single;
    private PetWindow? _window;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        string? action = ParseAction(e.Args);
        _single = new SingleInstance();

        if (!_single.TryAcquire())
        {
            // Another instance owns the app. Forward the requested action (if any), then quit.
            if (action != null) SingleInstance.Send(action);
            Shutdown();
            return;
        }

        // First instance: keep running even though the (minimized) window is never shown.
        ShutdownMode = ShutdownMode.OnExplicitShutdown;

        _window = new PetWindow();
        _window.Show(); // minimized; this is what gives us the animated taskbar button

        JumpListBuilder.Install();

        // Incoming actions from later launches arrive on a background thread; marshal to the UI thread.
        _single.StartServer(msg => Dispatcher.Invoke(() => _window!.HandleAction(StripPrefix(msg))));

        // Honor an action passed on this very launch.
        if (action != null) Dispatcher.BeginInvoke(new Action(() => _window!.HandleAction(action)));
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _single?.Dispose();
        base.OnExit(e);
    }

    private static string? ParseAction(string[] args)
    {
        var arg = args.FirstOrDefault(a => a.StartsWith(ActionPrefix, StringComparison.OrdinalIgnoreCase));
        return arg == null ? null : arg.Substring(ActionPrefix.Length);
    }

    private static string StripPrefix(string msg) =>
        msg.StartsWith(ActionPrefix, StringComparison.OrdinalIgnoreCase) ? msg.Substring(ActionPrefix.Length) : msg;
}
