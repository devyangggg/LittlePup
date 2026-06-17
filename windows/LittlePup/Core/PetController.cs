using System.Windows;
using LittlePup.Animation;
using LittlePup.Behavior;
using LittlePup.Update;

namespace LittlePup.Core;

// Top-level brain: starts the idle loop + auto-cycle and maps Jump List commands to animation
// actions. Mirrors the macOS DockMenuActions closures.
public sealed class PetController
{
    private readonly AnimationController _anim;
    private readonly BehaviorScheduler _scheduler;
    private readonly UpdateChecker _updater = new();

    public PetController(AnimationController anim, BehaviorScheduler scheduler)
    {
        _anim = anim;
        _scheduler = scheduler;
    }

    public void Start()
    {
        _anim.Play(PetState.Idle, loop: true, cyclePause: 4.0);
        _scheduler.Start();
    }

    public void Stop() => _scheduler.Stop();

    // action is the bare command (e.g. "sit"), already stripped of the --action= prefix.
    public void HandleAction(string action)
    {
        switch (action)
        {
            case "idle":
                _anim.Play(PetState.Idle, loop: true, cyclePause: 4.0);
                break;
            case "sit":
                _anim.Play(PetState.Sit, loop: true, cyclePause: 4.0);
                break;
            case "sleep":
                _anim.Play(PetState.Sleep, loop: true, cyclePause: 3.0);
                break;
            case "walk":
                _anim.Play(PetState.Walk, loop: true, cyclePause: 0);
                break;
            case "feed":
                _anim.PlayOnce(PetState.Eat, () => _anim.Play(PetState.Idle, loop: true, cyclePause: 4.0));
                break;
            case "bark":
                _anim.PlayOnce(PetState.Bark, () => _anim.Play(PetState.Idle, loop: true, cyclePause: 4.0));
                break;
            case "update":
                _updater.Check();
                break;
            case "quit":
                _scheduler.Stop();
                Application.Current.Shutdown();
                break;
        }
    }
}
