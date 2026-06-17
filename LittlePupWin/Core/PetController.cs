using System.Windows;
using System.Windows.Threading;
using LittlePupWin.Animation;
using LittlePupWin.Behavior;
using LittlePupWin.DragDrop;
using LittlePupWin.Persistence;
using LittlePupWin.Profile;
using LittlePupWin.Walking;

namespace LittlePupWin.Core;

public class PetController : IAnimationDelegate, IBehaviorSchedulerDelegate
{
    private readonly PetProfile          _profile;
    private readonly AnimationController _animation;
    private readonly BehaviorScheduler   _scheduler;
    private readonly WalkPathController  _walkPath;
    private readonly OverlayWindow       _window;
    private readonly PetRenderer         _renderer;
    private readonly FileDropHandler     _dropHandler;
    private readonly StateStore          _store;

    private PetState         _state          = PetState.Idle;
    private DispatcherTimer? _walkTimer;
    private WalkPlan?        _currentPlan;
    private DateTime         _walkStart;
    private TransitionSource _walkSource;

    public PetController(
        PetProfile profile, AnimationController animation, BehaviorScheduler scheduler,
        WalkPathController walkPath, OverlayWindow window, PetRenderer renderer,
        FileDropHandler dropHandler, StateStore store)
    {
        _profile     = profile;
        _animation   = animation;
        _scheduler   = scheduler;
        _walkPath    = walkPath;
        _window      = window;
        _renderer    = renderer;
        _dropHandler = dropHandler;
        _store       = store;

        _animation.Delegate = this;
        _scheduler.Delegate = this;
    }

    public void Start()
    {
        var saved = _store.Load();
        var from  = saved?.LastState ?? PetState.Idle;
        if (from.IsMoving() || from.IsOneShot()) from = PetState.Idle;

        PlaceAtHome();
        _renderer.Show();
        Enter(new StateTransition(from, TransitionSource.Restore));
        _scheduler.Start(from);
    }

    public void Shutdown()
    {
        _walkTimer?.Stop();
        _scheduler.Stop();
        _animation.Stop();
        var safe = (_state.IsMoving() || _state.IsOneShot()) ? PetState.Idle : _state;
        _store.Save(new PersistedState(safe, _profile.Id));
    }

    // Tray menu overrides
    public void UserRequestedIdle()  => ManualOverride(PetState.Idle);
    public void UserRequestedSit()   => ManualOverride(PetState.Sit);
    public void UserRequestedSleep() => ManualOverride(PetState.Sleep);
    public void UserRequestedWalk()  => ManualOverride(PetState.Walk);
    public void UserRequestedRun()   => ManualOverride(PetState.Run);

    public void UserRequestedFeed()
    {
        StopWalk();
        _scheduler.Pause();
        Enter(new StateTransition(PetState.Eat, TransitionSource.ManualOverride));
    }

    public void UserRequestedBark()
    {
        StopWalk();
        _scheduler.Pause();
        Enter(new StateTransition(PetState.Bark, TransitionSource.ManualOverride));
    }

    public void HandleDroppedFiles(IEnumerable<string> paths)
    {
        var result = _dropHandler.HandleDrop(paths);
        if (result.DidEat) UserRequestedFeed();
    }

    // IBehaviorSchedulerDelegate
    public void SchedulerWantsTransition(BehaviorScheduler scheduler, PetState state, TimeSpan duration)
    {
        if (state.IsMoving()) scheduler.Pause(); // resume after walk finishes
        Enter(new StateTransition(state, TransitionSource.Scheduler, duration));
    }

    // IAnimationDelegate
    public void AnimationDidCompleteCycle(PetState state) { }

    // ─── private ───────────────────────────────────────────────────────────

    private void ManualOverride(PetState state)
    {
        StopWalk();
        _scheduler.Pause();

        if (state.IsMoving())
        {
            Enter(new StateTransition(state, TransitionSource.ManualOverride, TimeSpan.FromSeconds(7)));
        }
        else
        {
            Enter(new StateTransition(state, TransitionSource.ManualOverride));
            ResumeAfterBehaviorDuration(state);
        }
    }

    private void ResumeAfterBehaviorDuration(PetState state)
    {
        var beh  = _profile.Behavior(state);
        double d = beh != null
            ? WeightedPicker.RandomDuration(beh.MinDuration, beh.MaxDuration)
            : 8.0;

        var t = new DispatcherTimer { Interval = TimeSpan.FromSeconds(d) };
        t.Tick += (_, _) =>
        {
            t.Stop();
            if (!_scheduler.IsPaused) return;
            _scheduler.Resume(PetState.Idle);
            Enter(new StateTransition(PetState.Idle, TransitionSource.Scheduler));
        };
        t.Start();
    }

    private void Enter(StateTransition transition)
    {
        _state = transition.Target;
        PetState safe = (_state.IsMoving() || _state.IsOneShot()) ? PetState.Idle : _state;
        _store.Save(new PersistedState(safe, _profile.Id));

        if (transition.Target.IsMoving())
        {
            BeginWalk(transition.Target, transition.Duration ?? TimeSpan.FromSeconds(7), transition.Source);
        }
        else if (transition.Target.IsOneShot())
        {
            PlaceAtHome();
            _animation.PlayOnce(transition.Target, () =>
            {
                _scheduler.Resume(PetState.Idle);
                Enter(new StateTransition(PetState.Idle, TransitionSource.Scheduler));
            });
        }
        else
        {
            PlaceAtHome();
            double pause = transition.Target == PetState.Idle ? 2.0 : 0;
            _animation.Play(transition.Target, loop: true, cyclePause: pause);
        }
    }

    private void BeginWalk(PetState walkState, TimeSpan duration, TransitionSource source)
    {
        _walkSource  = source;
        var plan     = _walkPath.MakePath(_profile.FrameSize, duration.TotalSeconds);
        _currentPlan = plan;
        _walkStart   = DateTime.UtcNow;

        _window.MoveTo(plan.StartOrigin);
        _animation.Play(walkState, loop: true, flipH: plan.FacingLeft);

        _walkTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _walkTimer.Tick += WalkTick;
        _walkTimer.Start();
    }

    private void WalkTick(object? sender, EventArgs e)
    {
        if (_currentPlan is not { } plan) return;
        double elapsed  = (DateTime.UtcNow - _walkStart).TotalSeconds;
        double progress = Math.Min(elapsed / plan.DurationSeconds, 1.0);
        _window.MoveTo(plan.OriginAtProgress(progress));

        if (progress >= 1.0)
        {
            StopWalk();
            PlaceAtHome();
            _scheduler.Resume(PetState.Idle);
            Enter(new StateTransition(PetState.Idle, TransitionSource.Scheduler));
        }
    }

    private void StopWalk()
    {
        _walkTimer?.Stop();
        _walkTimer   = null;
        _currentPlan = null;
    }

    private void PlaceAtHome()
    {
        double screenW = SystemParameters.PrimaryScreenWidth;
        double screenH = SystemParameters.PrimaryScreenHeight;
        double x = (screenW - _profile.FrameSize) / 2;
        double y = screenH - _profile.FrameSize;   // feet sit on the taskbar
        _window.MoveTo(new Point(x, y));
        _window.SizeTo(_profile.FrameSize);
    }
}
