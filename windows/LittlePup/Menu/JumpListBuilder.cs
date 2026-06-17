using System.Diagnostics;
using System.Windows;
using System.Windows.Shell;

namespace LittlePup.Menu;

// Builds the taskbar Jump List — the Windows analog of the macOS right-click Dock menu. Each task
// relaunches the exe with --action=<cmd>; the single-instance guard forwards it to the running app.
public static class JumpListBuilder
{
    public static void Install()
    {
        var exe = Process.GetCurrentProcess().MainModule?.FileName ?? "";

        var list = new JumpList
        {
            ShowRecentCategory = false,
            ShowFrequentCategory = false
        };

        void Add(string title, string action) => list.JumpItems.Add(new JumpTask
        {
            Title = title,
            ApplicationPath = exe,
            Arguments = "--action=" + action,
            IconResourcePath = exe
        });

        Add("Idle", "idle");
        Add("Sit", "sit");
        Add("Sleep", "sleep");
        Add("Walk", "walk");
        Add("Feed", "feed");
        Add("Bark", "bark");
        Add("Check for Updates", "update");
        Add("Quit", "quit");

        JumpList.SetJumpList(Application.Current, list);
        list.Apply();
    }
}
