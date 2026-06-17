using System.Text.Json.Serialization;

namespace LittlePupWin.Profile;

public record AnimationConfig(
    [property: JsonPropertyName("row")]        int Row,
    [property: JsonPropertyName("frameCount")] int FrameCount,
    [property: JsonPropertyName("fps")]        double Fps
);
