using System.IO;

namespace LittlePupWin.DragDrop;

public record FileDropResult(bool DidEat, bool DeletedFile);

public class FileDropHandler
{
    public FileDropResult HandleDrop(IEnumerable<string> paths)
    {
        bool didEat = false, deleted = false;
        foreach (var path in paths)
        {
            didEat = true;
            if (IsFoodFile(path))
            {
                try { File.Delete(path); deleted = true; }
                catch (Exception ex)
                { Console.WriteLine($"LittlePup: could not delete food file: {ex.Message}"); }
            }
        }
        return new FileDropResult(didEat, deleted);
    }

    public bool IsFoodFile(string path) =>
        Path.GetFileName(path).Equals("food.png", StringComparison.OrdinalIgnoreCase);
}
