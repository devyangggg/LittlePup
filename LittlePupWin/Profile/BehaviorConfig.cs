using System.Text.Json.Serialization;
using LittlePupWin.Core;

namespace LittlePupWin.Profile;

public record WeightedState(
    [property: JsonPropertyName("state")]  PetState State,
    [property: JsonPropertyName("weight")] int Weight
);

public record BehaviorConfig(
    [property: JsonPropertyName("minDuration")] double MinDuration,
    [property: JsonPropertyName("maxDuration")] double MaxDuration,
    [property: JsonPropertyName("nextStates")]  List<WeightedState> NextStates
);
