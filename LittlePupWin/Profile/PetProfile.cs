using System.Text.Json.Serialization;
using LittlePupWin.Core;

namespace LittlePupWin.Profile;

public record PetProfile(
    [property: JsonPropertyName("id")]          string Id,
    [property: JsonPropertyName("name")]        string Name,
    [property: JsonPropertyName("spriteSheet")] string SpriteSheet,
    [property: JsonPropertyName("frameSize")]   int FrameSize,
    [property: JsonPropertyName("animations")]  Dictionary<string, AnimationConfig> Animations,
    [property: JsonPropertyName("behaviors")]   Dictionary<string, BehaviorConfig>? Behaviors
)
{
    public AnimationConfig? Animation(PetState state) =>
        Animations.TryGetValue(state.ToJsonKey(), out var c) ? c : null;

    public BehaviorConfig? Behavior(PetState state) =>
        Behaviors?.TryGetValue(state.ToJsonKey(), out var c) == true ? c : null;
}
