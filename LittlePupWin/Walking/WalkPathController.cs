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
        double taskbarH  = SystemParameters.PrimaryScreenHeight - SystemParameters.WorkArea.Bottom;
        double y         = SystemParameters.WorkArea.Bottom;   // walk inside the taskbar strip
        double screenW   = SystemParameters.PrimaryScreenWidth;
        bool   goLeft    = Random.Shared.NextDouble() < 0.5;

        Point start = goLeft ? new Point(screenW - taskbarH, y) : new Point(0, y);
        Point end   = goLeft ? new Point(0, y) : new Point(screenW - taskbarH, y);

        return new WalkPlan(start, end, goLeft, durationSeconds);
    }
}
