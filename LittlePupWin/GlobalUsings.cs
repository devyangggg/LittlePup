// Pin OpenFileDialog to the WPF version (Microsoft.Win32) since both WPF and System.Windows
// define one when the project targets Windows.
global using OpenFileDialog = Microsoft.Win32.OpenFileDialog;
