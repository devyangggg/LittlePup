namespace LittlePupWin.Core;

public enum TransitionSource { Scheduler, ManualOverride, FileDrop, Restore }

public record StateTransition(PetState Target, TransitionSource Source, TimeSpan? Duration = null);
