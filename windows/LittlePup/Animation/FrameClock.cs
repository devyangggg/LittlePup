using System;
using System.Windows.Threading;

namespace LittlePup.Animation;

// Wraps a DispatcherTimer (UI-thread, message-loop based). Analog of the macOS FrameClock; on
// Windows the Jump List is rendered by the shell, not a blocking modal loop, so no special
// run-loop-mode handling is needed — the timer keeps ticking.
public sealed class FrameClock
{
    private readonly DispatcherTimer _timer = new(DispatcherPriority.Render);

    public Action? OnTick;

    public FrameClock()
    {
        _timer.Tick += (_, _) => OnTick?.Invoke();
    }

    public bool IsRunning => _timer.IsEnabled;

    public void Start(double fps)
    {
        _timer.Stop();
        var interval = fps > 0 ? 1.0 / fps : 0.1;
        _timer.Interval = TimeSpan.FromSeconds(interval);
        _timer.Start();
    }

    public void Stop() => _timer.Stop();
}
