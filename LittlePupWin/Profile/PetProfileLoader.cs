using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;

namespace LittlePupWin.Profile;

public class PetProfileLoader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    public PetProfile LoadDefault() => Load("golden_retriever");

    public PetProfile Load(string name)
    {
        var uri = new Uri($"pack://application:,,,/Resources/Pets/{name}.json");
        var info = Application.GetResourceStream(uri)
            ?? throw new ProfileNotFoundException(name);

        using var reader = new StreamReader(info.Stream);
        var json = reader.ReadToEnd();

        PetProfile profile;
        try
        {
            profile = JsonSerializer.Deserialize<PetProfile>(json, Options)
                ?? throw new ProfileException("Deserialized profile was null.");
        }
        catch (JsonException ex)
        {
            throw new ProfileException($"Failed to parse '{name}'.", ex);
        }

        Validate(profile);
        return profile;
    }

    private static void Validate(PetProfile p)
    {
        if (p.FrameSize <= 0)
            throw new ProfileValidationException("frameSize must be > 0.");
        foreach (var (key, anim) in p.Animations)
        {
            if (anim.FrameCount <= 0)
                throw new ProfileValidationException($"Animation '{key}': frameCount must be > 0.");
            if (anim.Fps <= 0)
                throw new ProfileValidationException($"Animation '{key}': fps must be > 0.");
        }
    }
}
