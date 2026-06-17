using System.Windows;

namespace LittlePupWin.Walking;

public record WalkPlan(Point StartOrigin, Point EndOrigin, bool FacingLeft, double DurationSeconds)
{
    public Point OriginAtProgress(double t)
    {
        double x = StartOrigin.X + (EndOrigin.X - StartOrigin.X) * t;
        return new Point(x, StartOrigin.Y);
    }
}

public class WalkPathController
{
    public WalkPlan MakePath(int frameSize, double durationSeconds)
    {
        var area   = SystemParameters.WorkArea;
        double y   = area.Bottom - frameSize;   // walk just above the taskbar
        bool goLeft = Random.Shared.NextDouble() < 0.5;

        Point start = goLeft ? new Point(area.Right - frameSize, y) : new Point(area.Left, y);
        Point end   = goLeft ? new Point(area.Left, y) : new Point(area.Right - frameSize, y);

        return new WalkPlan(start, end, goLeft, durationSeconds);
    }
}
