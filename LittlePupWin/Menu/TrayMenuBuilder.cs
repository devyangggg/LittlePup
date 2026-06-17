using System.Drawing;
using System.Windows.Forms;

namespace LittlePupWin.Menu;

public record TrayMenuActions(
    Action OnIdle,
    Action OnSit,
    Action OnSleep,
    Action OnWalk,
    Action OnRun,
    Action OnFeed,
    Action OnBark,
    Action OnFeedFromFile,
    Action OnQuit
);

public class TrayMenuBuilder : IDisposable
{
    private readonly NotifyIcon _tray;

    public TrayMenuBuilder(TrayMenuActions actions)
    {
        _tray = new NotifyIcon
        {
            Text    = "LittlePup",
            Icon    = SystemIcons.Application,
            Visible = true,
            ContextMenuStrip = BuildMenu(actions)
        };
    }

    public void UpdateIcon(Icon icon) => _tray.Icon = icon;

    private static ContextMenuStrip BuildMenu(TrayMenuActions a)
    {
        var m = new ContextMenuStrip();
        m.Items.Add("Idle",  null, (_, _) => a.OnIdle());
        m.Items.Add("Sit",   null, (_, _) => a.OnSit());
        m.Items.Add("Sleep", null, (_, _) => a.OnSleep());
        m.Items.Add("Walk",  null, (_, _) => a.OnWalk());
        m.Items.Add("Run",   null, (_, _) => a.OnRun());
        m.Items.Add(new ToolStripSeparator());
        m.Items.Add("Feed",             null, (_, _) => a.OnFeed());
        m.Items.Add("Bark",             null, (_, _) => a.OnBark());
        m.Items.Add("Feed from file…",  null, (_, _) => a.OnFeedFromFile());
        m.Items.Add(new ToolStripSeparator());
        m.Items.Add("Quit",  null, (_, _) => a.OnQuit());
        return m;
    }

    public void Dispose()
    {
        _tray.Visible = false;
        _tray.Dispose();
    }
}
