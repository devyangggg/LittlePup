using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Threading;
using LittlePup.Core;
using LittlePup.Profile;

namespace LittlePup.Animation;

// Mirrors AnimationController.swift: advances a frame index on each clock tick, pushing frames to
// the taskbar icon. Supports looping with a "cyclePause" (hold on frame 0 between loops) and
// one-shot playback (eat/bark) with a completion callback.
public sealed class AnimationController
{
    private readonly SpriteSheet _sheet;
    private readonly PetProfile _profile;
    private readonly FrameClock _clock;
    private readonly IconRenderer _renderer;
    private readonly DispatcherTimer _pauseTimer = new(DispatcherPriority.Render);

    private List<Bitmap> _frames = new();
    private int _index;
    private bool _looping;
    private double _cyclePause;
    private double _fps;
    private Action? _oneShotCompletion;

    public PetState CurrentState { get; private set; } = PetState.Idle;

    public AnimationController(SpriteSheet sheet, PetProfile profile, FrameClock clock, IconRenderer renderer)
    {
        _sheet = sheet;
        _profile = profile;
        _clock = clock;
        _renderer = renderer;
        _clock.OnTick = Tick;
        _pauseTimer.Tick += (_, _) =>
        {
            _pauseTimer.Stop();
            _clock.Start(_fps);
        };
    }

    public void Play(PetState state, bool loop, double cyclePause = 0)
    {
        var cfg = _profile.AnimationFor(state);
        if (cfg == null) return;

        _oneShotCompletion = null;
        CurrentState = state;
        _looping = loop;
        _cyclePause = cyclePause;
        _fps = cfg.Fps;
        _frames = _sheet.Frames(cfg.Row, cfg.FrameCount);
        _index = 0;
        _pauseTimer.Stop();

        if (_frames.Count > 0) _renderer.SetIcon(_frames[0]);
        _clock.Start(_fps);
    }

    public void PlayOnce(PetState state, Action? completion)
    {
        Play(state, loop: false, cyclePause: 0);
        _oneShotCompletion = completion;
    }

    private void Tick()
    {
        if (_frames.Count == 0) return;

        _index++;
        if (_index >= _frames.Count)
        {
            if (_looping)
            {
                _index = 0;
                _renderer.SetIcon(_frames[0]);
                if (_cyclePause > 0)
                {
                    _clock.Stop();
                    _pauseTimer.Interval = TimeSpan.FromSeconds(_cyclePause);
                    _pauseTimer.Start();
                }
                // cyclePause == 0: clock keeps running; next tick advances to frame 1.
            }
            else
            {
                // One-shot finished: stop and fire completion (typically returns to idle).
                _clock.Stop();
                var completion = _oneShotCompletion;
                _oneShotCompletion = null;
                completion?.Invoke();
            }
            return;
        }

        _renderer.SetIcon(_frames[_index]);
    }
}
