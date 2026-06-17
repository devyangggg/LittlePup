using System.Windows.Threading;
using LittlePupWin.Core;
using LittlePupWin.Profile;

namespace LittlePupWin.Behavior;

public interface IBehaviorSchedulerDelegate
{
    void SchedulerWantsTransition(BehaviorScheduler scheduler, PetState state, TimeSpan duration);
}

public class BehaviorScheduler(PetProfile profile)
{
    private DispatcherTimer? _timer;

    public IBehaviorSchedulerDelegate? Delegate { get; set; }
    public PetState CurrentState { get; private set; } = PetState.Idle;
    public bool IsPaused { get; private set; }

    public void Start(PetState from)
    {
        CurrentState = from;
        IsPaused = false;
        ScheduleFromCurrent();
    }

    public void Pause()
    {
        IsPaused = true;
        _timer?.Stop();
        _timer = null;
    }

    public void Resume(PetState from)
    {
        CurrentState = from;
        IsPaused = false;
        ScheduleFromCurrent();
    }

    public void Stop()
    {
        _timer?.Stop();
        _timer = null;
    }

    private void ScheduleFromCurrent()
    {
        var beh = profile.Behavior(CurrentState);
        if (beh == null) return;
        double d = WeightedPicker.RandomDuration(beh.MinDuration, beh.MaxDuration);
        ScheduleTimer(d, beh);
    }

    private void ScheduleTimer(double seconds, BehaviorConfig behavior)
    {
        _timer?.Stop();
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(seconds) };
        _timer.Tick += (_, _) =>
        {
            _timer?.Stop();
            _timer = null;
            Fire(behavior);
        };
        _timer.Start();
    }

    private void Fire(BehaviorConfig behavior)
    {
        if (IsPaused) return;
        var items = behavior.NextStates.Select(ws => (ws.State, ws.Weight)).ToList();
        if (!WeightedPicker.TryPick<PetState>(items, out var next)) return;

        CurrentState = next;
        var nextBeh = profile.Behavior(next);
        double duration = nextBeh != null
            ? WeightedPicker.RandomDuration(nextBeh.MinDuration, nextBeh.MaxDuration)
            : 5.0;

        Delegate?.SchedulerWantsTransition(this, next, TimeSpan.FromSeconds(duration));

        if (!IsPaused && nextBeh != null)
            ScheduleTimer(duration, nextBeh);
    }
}
