using System.Windows;
using System.Windows.Media.Imaging;

namespace LittlePupWin.Animation;

public class SpriteSheet
{
    private readonly BitmapSource _source;
    private readonly int _frameSize;
    private readonly int _colCount;
    private readonly Dictionary<int, BitmapSource> _cache = [];

    public int FrameSize  => _frameSize;
    public int PixelWidth  => _source.PixelWidth;
    public int PixelHeight => _source.PixelHeight;

    public SpriteSheet(BitmapSource source, int frameSize)
    {
        _source    = source;
        _frameSize = frameSize;
        _colCount  = frameSize > 0 ? source.PixelWidth / frameSize : 0;
    }

    public static SpriteSheet Load(string resourceName, int frameSize)
    {
        var uri = new Uri($"pack://application:,,,/Resources/Pets/{resourceName}");
        var bmp = new BitmapImage();
        bmp.BeginInit();
        bmp.UriSource    = uri;
        bmp.CacheOption  = BitmapCacheOption.OnLoad;
        bmp.EndInit();
        bmp.Freeze();
        return new SpriteSheet(bmp, frameSize);
    }

    public BitmapSource Frame(int row, int index)
    {
        int key = row * _colCount + index;
        if (_cache.TryGetValue(key, out var hit)) return hit;

        var rect    = new Int32Rect(index * _frameSize, row * _frameSize, _frameSize, _frameSize);
        var cropped = new CroppedBitmap(_source, rect);
        cropped.Freeze();
        _cache[key] = cropped;
        return cropped;
    }

    public List<BitmapSource> Frames(int row, int count) =>
        Enumerable.Range(0, count).Select(i => Frame(row, i)).ToList();
}
