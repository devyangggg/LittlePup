using System;
using System.Windows.Threading;
using LittlePup.Animation;
using LittlePup.Core;
using LittlePup.Profile;

namespace LittlePup.Behavior;

// Mirrors the macOS AppDelegate auto-cycle: every ~2.5–3.5 minutes it picks idle/sleep/run weighted
// by personality (defaults 2/2/1). Run is capped to personality.runDuration (or random 5–8s) and
// then immediately picks the next state. The richer JSON "behaviors" block is intentionally unused
// (same as macOS).
public sealed class BehaviorScheduler
{
    private readonly AnimationController _anim;
    private readonly PetProfile _profile;
    private readonly DispatcherTimer _cycleTimer = new();
    private readonly DispatcherTimer _runTimer = new();
    private readonly Random _rng = new();

    public BehaviorScheduler(AnimationController anim, PetProfile profile)
    {
        _anim = anim;
        _profile = profile;
        _cycleTimer.Tick += (_, _) => { _cycleTimer.Stop(); Play(Pick()); };
        _runTimer.Tick += (_, _) => { _runTimer.Stop(); Play(Pick()); };
    }

    public void Start() => ScheduleNext();

    public void Stop()
    {
        _cycleTimer.Stop();
        _runTimer.Stop();
    }

    private void ScheduleNext()
    {
        _cycleTimer.Stop();
        _cycleTimer.Interval = TimeSpan.FromSeconds(_rng.Next(150, 211)); // 150–210s inclusive
        _cycleTimer.Start();
    }

    private PetState Pick()
    {
        int idleW = _profile.Personality?.IdleWeight ?? 2;
        int sleepW = _profile.Personality?.SleepWeight ?? 2;
        int runW = _profile.Personality?.RunWeight ?? 1;
        int total = Math.Max(1, idleW + sleepW + runW);
        int roll = _rng.Next(0, total);
        if (roll < idleW) return PetState.Idle;
        if (roll < idleW + sleepW) return PetState.Sleep;
        return PetState.Run;
    }

    private void Play(PetState state)
    {
        switch (state)
        {
            case PetState.Idle:
                _anim.Play(PetState.Idle, loop: true, cyclePause: 4.0);
                ScheduleNext();
                break;

            case PetState.Sleep:
                _anim.Play(PetState.Sleep, loop: true, cyclePause: 3.0);
                ScheduleNext();
                break;

            case PetState.Run:
                double duration = _profile.Personality?.RunDuration ?? _rng.Next(5, 9); // 5–8s
                _anim.Play(PetState.Run, loop: true, cyclePause: 0);
                _runTimer.Stop();
                _runTimer.Interval = TimeSpan.FromSeconds(duration);
                _runTimer.Start();
                break;

            default:
                _anim.Play(PetState.Idle, loop: true, cyclePause: 4.0);
                ScheduleNext();
                break;
        }
    }
}
