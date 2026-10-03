using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class StandaloneLauncher
{
    [STAThread]
    private static int Main()
    {
        var root = AppDomain.CurrentDomain.BaseDirectory;
        var helper = Path.Combine(root, "standalone\\runtime\\helper.py");
        if (!File.Exists(helper))
        {
            MessageBox.Show("找不到独立桌宠运行文件。请重新安装 Codex 大肥鱼。",
                "Codex 大肥鱼", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        var python = FindPython();
        if (python == null)
        {
            MessageBox.Show(
                "独立桌宠需要 Python 3 和 PySide6。\r\n\r\n" +
                "请先安装 Python 3，然后在安装目录运行：\r\n" +
                "py -3 -m pip install -r standalone\\requirements.txt",
                "无法启动独立桌宠", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 1;
        }

        var isLauncher = string.Equals(Path.GetFileName(python), "py.exe",
            StringComparison.OrdinalIgnoreCase);
        var startInfo = new ProcessStartInfo
        {
            FileName = python,
            Arguments = (isLauncher ? "-3 " : string.Empty) + Quote(helper) + " --standalone",
            WorkingDirectory = root,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };
        startInfo.EnvironmentVariables["CODEX_DAFEIYU_LAYOUT_PATH"] =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Codex\\codex-dafeiyu-standalone\\layout.json");
        startInfo.EnvironmentVariables["CODEX_DAFEIYU_STATUS_PATH"] =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Codex\\codex-dafeiyu\\status.json");

        try
        {
            using (var process = Process.Start(startInfo))
            {
                if (process == null) throw new InvalidOperationException("无法创建 Python 进程。");
                if (process.WaitForExit(1800) && process.ExitCode != 0)
                {
                    MessageBox.Show(
                        "独立桌宠启动失败。请确认已安装 PySide6：\r\n" +
                        "py -3 -m pip install -r standalone\\requirements.txt",
                        "无法启动独立桌宠", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return process.ExitCode;
                }
            }
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "无法启动独立桌宠",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string FindPython()
    {
        var path = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var directory in path.Split(new[] { Path.PathSeparator },
            StringSplitOptions.RemoveEmptyEntries))
        {
            var launcher = Path.Combine(directory.Trim(), "py.exe");
            if (File.Exists(launcher)) return launcher;
        }

        foreach (var candidate in new[] { "py.exe", "python.exe" })
        {
            try
            {
                var info = new ProcessStartInfo(candidate, "--version")
                {
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                using (var process = Process.Start(info))
                {
                    if (process != null && process.WaitForExit(1500)) return candidate;
                }
            }
            catch
            {
                // Try the next Python launcher.
            }
        }
        return null;
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
