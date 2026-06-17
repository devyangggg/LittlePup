namespace LittlePupWin.Profile;

public class ProfileException(string message, Exception? inner = null)
    : Exception(message, inner);

public class ProfileNotFoundException(string name)
    : ProfileException($"Profile '{name}' not found.");

public class ProfileValidationException(string reason)
    : ProfileException($"Profile validation failed: {reason}");
