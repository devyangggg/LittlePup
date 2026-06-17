using System.Windows.Threading;

namespace LittlePupWin.Animation;

public class FrameClock
{
    private DispatcherTimer? _timer;

    public Action? OnTick { get; set; }

    public void Start(double fps)
    {
        Stop();
        _timer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromSeconds(1.0 / fps)
        };
        _timer.Tick += (_, _) => OnTick?.Invoke();
        _timer.Start();
    }

    public void Stop()
    {
        _timer?.Stop();
        _timer = null;
    }

    public bool IsRunning => _timer?.IsEnabled == true;
}
