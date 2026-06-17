using System;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text.Json;

namespace LittlePup.Profile;

// Loads the embedded pet profile JSON + sprite sheet PNG. Embedded (not loose files) so the
// published single-file exe is fully self-contained.
public sealed class PetProfileLoader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public PetProfile LoadDefaultProfile()
    {
        using var stream = OpenResource("Pets/golden_retriever.json")
            ?? throw new InvalidOperationException("Embedded profile 'Pets/golden_retriever.json' not found.");
        return JsonSerializer.Deserialize<PetProfile>(stream, Options)
            ?? throw new InvalidOperationException("Failed to decode pet profile JSON.");
    }

    // Returns a fully owned Bitmap (decoupled from the resource stream, which GDI+ otherwise locks).
    public Bitmap LoadSpriteSheet(PetProfile profile)
    {
        var name = "Pets/" + profile.SpriteSheet;
        using var stream = OpenResource(name)
            ?? throw new InvalidOperationException($"Embedded sprite sheet '{name}' not found.");
        using var temp = new Bitmap(stream);
        return new Bitmap(temp); // copy into independent memory so the stream can be released
    }

    private static Stream? OpenResource(string logicalName) =>
        Assembly.GetExecutingAssembly().GetManifestResourceStream(logicalName);
}
