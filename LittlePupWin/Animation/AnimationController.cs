using System.Windows.Media.Imaging;
using System.Windows.Threading;
using LittlePupWin.Core;
using LittlePupWin.Profile;

namespace LittlePupWin.Animation;

public interface IAnimationDelegate
{
    void AnimationDidCompleteCycle(PetState state);
}

public class AnimationController
{
    private readonly SpriteSheet _sheet;
    private readonly PetProfile  _profile;
    private readonly FrameClock  _clock;
    private readonly PetRenderer _renderer;

    private List<BitmapSource> _frames = [];
    private int            _frameIndex;
    private bool           _looping;
    private double         _cyclePause;
    private Action?        _oneshotCompletion;
    private DispatcherTimer? _pauseTimer;

    public IAnimationDelegate? Delegate     { get; set; }
    public PetState CurrentState            { get; private set; } = PetState.Idle;
    public bool FlipHorizontally            { get; private set; }

    public AnimationController(SpriteSheet sheet, PetProfile profile, FrameClock clock, PetRenderer renderer)
    {
        _sheet    = sheet;
        _profile  = profile;
        _clock    = clock;
        _renderer = renderer;
        _clock.OnTick = Tick;
    }

    public void Play(PetState state, bool loop, double cyclePause = 0, bool flipH = false)
    {
        CancelPauseTimer();
        var cfg = _profile.Animation(state);
        if (cfg == null) return;

        CurrentState        = state;
        _frameIndex         = 0;
        _looping            = loop;
        _cyclePause         = cyclePause;
        _oneshotCompletion  = null;
        FlipHorizontally    = flipH;
        _frames             = _sheet.Frames(cfg.Row, cfg.FrameCount);

        _clock.Start(cfg.Fps);
        if (_frames.Count > 0)
            _renderer.Render(_frames[0], FlipHorizontally);
    }

    public void PlayOnce(PetState state, Action? completion)
    {
        Play(state, loop: false);
        _oneshotCompletion = completion;
    }

    public void Stop()
    {
        CancelPauseTimer();
        _clock.Stop();
    }

    public BitmapSource? CurrentFrameImage() =>
        _frames.Count > 0 ? _frames[_frameIndex] : null;

    private void Tick()
    {
        if (_frames.Count == 0) return;
        int next = _frameIndex + 1;

        if (next >= _frames.Count)
        {
            if (_looping)
            {
                _frameIndex = 0;
                _renderer.Render(_frames[0], FlipHorizontally);
                Delegate?.AnimationDidCompleteCycle(CurrentState);
                if (_cyclePause > 0)
                {
                    _clock.Stop();
                    SchedulePauseTimer();
                }
            }
            else
            {
                _clock.Stop();
                var cb = _oneshotCompletion;
                _oneshotCompletion = null;
                cb?.Invoke();
            }
        }
        else
        {
            _frameIndex = next;
            _renderer.Render(_frames[_frameIndex], FlipHorizontally);
        }
    }

    private void SchedulePauseTimer()
    {
        var cfg = _profile.Animation(CurrentState);
        if (cfg == null) return;
        double fps = cfg.Fps;
        _pauseTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(_cyclePause) };
        _pauseTimer.Tick += (_, _) =>
        {
            _pauseTimer?.Stop();
            _pauseTimer = null;
            _clock.Start(fps);
        };
        _pauseTimer.Start();
    }

    private void CancelPauseTimer()
    {
        _pauseTimer?.Stop();
        _pauseTimer = null;
    }
}
