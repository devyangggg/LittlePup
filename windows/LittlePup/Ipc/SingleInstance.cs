using System;
using System.IO;
using System.IO.Pipes;
using System.Threading;
using System.Threading.Tasks;

namespace LittlePup.Ipc;

// Ensures one running instance and bridges Jump List relaunches to it. The first instance owns a
// named mutex and runs a pipe server; later launches (from Jump List tasks) detect the mutex,
// send their command over the pipe, and exit. This makes taskbar Jump List items behave like the
// in-process macOS Dock-menu closures.
public sealed class SingleInstance : IDisposable
{
    private const string MutexName = "LittlePup.SingleInstance.Mutex";
    private const string PipeName = "LittlePup.Pipe";

    private Mutex? _mutex;
    private bool _owns;
    private CancellationTokenSource? _cts;

    // True if this process is the first/owning instance.
    public bool TryAcquire()
    {
        _mutex = new Mutex(initiallyOwned: true, MutexName, out _owns);
        return _owns;
    }

    // Owning instance: listen for commands forwarded by later launches.
    public void StartServer(Action<string> onMessage)
    {
        _cts = new CancellationTokenSource();
        _ = Task.Run(() => ServerLoop(onMessage, _cts.Token));
    }

    private static async Task ServerLoop(Action<string> onMessage, CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                using var server = new NamedPipeServerStream(
                    PipeName, PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
                await server.WaitForConnectionAsync(ct).ConfigureAwait(false);
                using var reader = new StreamReader(server);
                var message = await reader.ReadLineAsync().ConfigureAwait(false);
                if (!string.IsNullOrWhiteSpace(message)) onMessage(message.Trim());
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch
            {
                // Ignore a single failed connection and keep serving.
            }
        }
    }

    // Non-owning instance: forward a command to the running app, then return.
    public static void Send(string message)
    {
        try
        {
            using var client = new NamedPipeClientStream(".", PipeName, PipeDirection.Out);
            client.Connect(2000);
            using var writer = new StreamWriter(client) { AutoFlush = true };
            writer.WriteLine(message);
        }
        catch
        {
            // Running instance not reachable; nothing else we can do.
        }
    }

    public void Dispose()
    {
        _cts?.Cancel();
        if (_owns)
        {
            try { _mutex?.ReleaseMutex(); } catch { /* not held */ }
        }
        _mutex?.Dispose();
    }
}
