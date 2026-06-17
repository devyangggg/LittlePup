using System.Windows;

namespace LittlePupWin;

public partial class App : Application
{
    private AppEnvironment? _env;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        ShutdownMode = ShutdownMode.OnExplicitShutdown;

        try
        {
            _env = new AppEnvironment();
            _env.Start();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"LittlePup failed to start:\n{ex.Message}",
                "LittlePup", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown();
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _env?.Shutdown();
        _env?.Dispose();
        base.OnExit(e);
    }
}
