using System.Collections.Generic;
using LittlePup.Core;

namespace LittlePup.Profile;

// Codable mirror of golden_retriever.json. Field names map case-insensitively
// (PropertyNameCaseInsensitive = true in PetProfileLoader), e.g. "spriteSheet" -> SpriteSheet.
public sealed class PetProfile
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string SpriteSheet { get; set; } = "";
    public int FrameSize { get; set; }
    public Dictionary<string, AnimationConfig> Animations { get; set; } = new();

    // Loaded but unused at runtime — mirrors the macOS app, kept for format compatibility.
    public Dictionary<string, BehaviorConfig>? Behaviors { get; set; }
    public PersonalityConfig? Personality { get; set; }

    public AnimationConfig? AnimationFor(PetState state) =>
        Animations.TryGetValue(state.Raw(), out var cfg) ? cfg : null;
}

public sealed class AnimationConfig
{
    public int Row { get; set; }
    public int FrameCount { get; set; }
    public double Fps { get; set; }
}

public sealed class BehaviorConfig
{
    public double MinDuration { get; set; }
    public double MaxDuration { get; set; }
    public List<WeightedState> NextStates { get; set; } = new();
}

public sealed class WeightedState
{
    public string State { get; set; } = "";
    public int Weight { get; set; }
}

public sealed class PersonalityConfig
{
    public string? Description { get; set; }
    public double? RunDuration { get; set; }
    public int? IdleWeight { get; set; }
    public int? SleepWeight { get; set; }
    public int? RunWeight { get; set; }
}
