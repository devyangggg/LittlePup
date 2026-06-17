namespace LittlePupWin.Behavior;

public static class WeightedPicker
{
    public static bool TryPick<T>(IReadOnlyList<(T Value, int Weight)> items, out T picked)
    {
        picked = default!;
        int total = items.Sum(x => x.Weight);
        if (total <= 0) return false;

        int roll = Random.Shared.Next(total);
        int running = 0;
        foreach (var (value, weight) in items)
        {
            running += weight;
            if (roll < running) { picked = value; return true; }
        }
        picked = items[^1].Value;
        return true;
    }

    public static double RandomDuration(double min, double max) =>
        min + Random.Shared.NextDouble() * (max - min);
}
