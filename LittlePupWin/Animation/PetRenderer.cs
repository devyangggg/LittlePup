using System.Windows.Media.Imaging;

namespace LittlePupWin.Animation;

public class PetRenderer(PetWindow window)
{
    public void Render(BitmapSource frame, bool flipH = false) =>
        window.SetFrame(frame, flipH);

    public void Show() => window.Show();
    public void Hide() => window.Hide();
    public bool IsVisible => window.IsVisible;
}
