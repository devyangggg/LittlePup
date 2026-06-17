using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

namespace LittlePup.Animation;

// Slices the sprite sheet into square frames. Mirrors SpriteSheet.swift: grid of frameSize-px
// squares, top-left origin (no Y flip), crop rect (col*frameSize, row*frameSize, frameSize square).
// Frames are cached on first access.
public sealed class SpriteSheet : IDisposable
{
    private readonly Bitmap _sheet;
    private readonly int _frameSize;
    private readonly Dictionary<int, Bitmap> _cache = new();

    public SpriteSheet(Bitmap sheet, int frameSize)
    {
        _sheet = sheet;
        _frameSize = frameSize;
    }

    public Bitmap Frame(int row, int index)
    {
        int key = (row * 1000) + index; // frames-per-row is well under 1000
        if (_cache.TryGetValue(key, out var cached)) return cached;

        var src = new Rectangle(index * _frameSize, row * _frameSize, _frameSize, _frameSize);
        var frame = new Bitmap(_frameSize, _frameSize, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(frame))
        {
            g.DrawImage(_sheet, new Rectangle(0, 0, _frameSize, _frameSize), src, GraphicsUnit.Pixel);
        }
        _cache[key] = frame;
        return frame;
    }

    public List<Bitmap> Frames(int row, int count)
    {
        var list = new List<Bitmap>(count);
        for (int i = 0; i < count; i++) list.Add(Frame(row, i));
        return list;
    }

    public void Dispose()
    {
        foreach (var b in _cache.Values) b.Dispose();
        _cache.Clear();
        _sheet.Dispose();
    }
}
