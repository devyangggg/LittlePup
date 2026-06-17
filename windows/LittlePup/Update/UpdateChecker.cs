using System;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;

namespace LittlePup.Update;

// Windows counterpart of UpdateChecker.swift. Because Windows ships as a rolling pre-release (kept
// out of GitHub's shared releases/latest so the macOS app is unaffected), this reads the version
// from the fixed "win-latest" release's name and offers the permanent exe download link.
public sealed class UpdateChecker
{
    private const string Repo = "devyangggg/LittlePup";
    private static readonly string TagApiUrl = $"https://api.github.com/repos/{Repo}/releases/tags/win-latest";
    private static readonly string ExeUrl = $"https://github.com/{Repo}/releases/download/win-latest/LittlePup.exe";
    private static readonly string ReleasesUrl = $"https://github.com/{Repo}/releases";

    public async void Check()
    {
        string local = LocalVersion();
        string? remote = await FetchRemoteVersionAsync();

        if (remote == null) { ShowError(); return; }
        if (IsNewer(remote, local)) ShowUpdateAvailable(remote, local);
        else ShowUpToDate(local);
    }

    private static string LocalVersion()
    {
        var v = Assembly.GetEntryAssembly()?.GetName().Version;
        return v == null ? "0.0.0" : $"{v.Major}.{v.Minor}.{v.Build}";
    }

    private static async Task<string?> FetchRemoteVersionAsync()
    {
        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("LittlePup");
            http.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");

            using var resp = await http.GetAsync(TagApiUrl);
            if (!resp.IsSuccessStatusCode) return null;

            var json = await resp.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.TryGetProperty("name", out var name) ? name.GetString() : null;
        }
        catch
        {
            return null;
        }
    }

    // True if remote is a strictly higher version than local (dotted integer components).
    public static bool IsNewer(string remote, string local)
    {
        int[] r = Parse(remote);
        int[] l = Parse(local);
        int n = Math.Max(r.Length, l.Length);
        for (int i = 0; i < n; i++)
        {
            int rv = i < r.Length ? r[i] : 0;
            int lv = i < l.Length ? l[i] : 0;
            if (rv != lv) return rv > lv;
        }
        return false;
    }

    private static int[] Parse(string s)
    {
        s = s.Trim();
        if (s.StartsWith("v", StringComparison.OrdinalIgnoreCase)) s = s.Substring(1);
        return s.Split('.')
                .Select(part =>
                {
                    var digits = new string(part.TakeWhile(char.IsDigit).ToArray());
                    return int.TryParse(digits, out var v) ? v : 0;
                })
                .ToArray();
    }

    private static void OpenUrl(string url) =>
        Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });

    private static void ShowUpdateAvailable(string remote, string local)
    {
        var result = MessageBox.Show(
            $"A new version of LittlePup is available.\n\nLatest: {remote}\nYou have: {local}\n\nDownload it now?",
            "LittlePup", MessageBoxButton.YesNo, MessageBoxImage.Information);
        if (result == MessageBoxResult.Yes) OpenUrl(ExeUrl);
    }

    private static void ShowUpToDate(string local) =>
        MessageBox.Show($"LittlePup {local} is the latest version.",
            "LittlePup", MessageBoxButton.OK, MessageBoxImage.Information);

    private static void ShowError()
    {
        var result = MessageBox.Show(
            "Couldn't check for updates. Open the releases page?",
            "LittlePup", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        if (result == MessageBoxResult.Yes) OpenUrl(ReleasesUrl);
    }
}
