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
        double screenW = SystemParameters.PrimaryScreenWidth;
        double screenH = SystemParameters.PrimaryScreenHeight;
        double y       = screenH - frameSize;   // walk along the taskbar
        bool   goLeft  = Random.Shared.NextDouble() < 0.5;

        Point start = goLeft
            ? new Point(screenW - frameSize, y)
            : new Point(0, y);
        Point end = goLeft
            ? new Point(0, y)
            : new Point(screenW - frameSize, y);

        return new WalkPlan(start, end, goLeft, durationSeconds);
    }
}
