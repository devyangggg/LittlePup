namespace LittlePupWin.Core;

public enum PetState { Idle, Walk, Run, Sit, Sleep, Eat, Bark }

public static class PetStateExtensions
{
    public static string ToJsonKey(this PetState s) => s.ToString().ToLowerInvariant();
    public static bool IsMoving(this PetState s) => s is PetState.Walk or PetState.Run;
    public static bool IsOneShot(this PetState s) => s is PetState.Eat or PetState.Bark;
}
