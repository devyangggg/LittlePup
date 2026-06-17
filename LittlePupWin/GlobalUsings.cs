// Resolve type ambiguities that arise from having both UseWPF and UseWindowsForms active.
// WinForms global usings pull in System.Drawing.Point and System.Windows.Forms.Application;
// we pin the bare names to the WPF versions so every file defaults to the right type.
global using Application    = System.Windows.Application;
global using MessageBox     = System.Windows.MessageBox;
global using OpenFileDialog = Microsoft.Win32.OpenFileDialog;
global using Point          = System.Windows.Point;
