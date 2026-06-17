using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using LittlePupWin.Core;

namespace LittlePupWin.Persistence;

public record PersistedState(PetState LastState, string ProfileId);

public class StateStore
{
    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "LittlePup", "state.json");

    private static readonly JsonSerializerOptions Opts = new()
    {
        Converters = { new JsonStringEnumConverter() }
    };

    public void Save(PersistedState state)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(state, Opts));
    }

    public PersistedState? Load()
    {
        if (!File.Exists(FilePath)) return null;
        try { return JsonSerializer.Deserialize<PersistedState>(File.ReadAllText(FilePath), Opts); }
        catch { return null; }
    }

    public void Clear()
    {
        if (File.Exists(FilePath)) File.Delete(FilePath);
    }
}
