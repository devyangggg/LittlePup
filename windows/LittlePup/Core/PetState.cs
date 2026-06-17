namespace LittlePup.Core;

// Mirrors PetState.swift. Raw values match the JSON animation keys exactly.
public enum PetState
{
    Idle,
    Walk,
    Run,
    Sit,
    Sleep,
    Eat,
    Bark
}

public static class PetStateExtensions
{
    // Lowercase key used to look up the state in the profile's animations/behaviors dictionaries.
    public static string Raw(this PetState state) => state switch
    {
        PetState.Idle => "idle",
        PetState.Walk => "walk",
        PetState.Run => "run",
        PetState.Sit => "sit",
        PetState.Sleep => "sleep",
        PetState.Eat => "eat",
        PetState.Bark => "bark",
        _ => "idle"
    };

    public static PetState? FromRaw(string raw) => raw.ToLowerInvariant() switch
    {
        "idle" => PetState.Idle,
        "walk" => PetState.Walk,
        "run" => PetState.Run,
        "sit" => PetState.Sit,
        "sleep" => PetState.Sleep,
        "eat" => PetState.Eat,
        "bark" => PetState.Bark,
        _ => null
    };
}
