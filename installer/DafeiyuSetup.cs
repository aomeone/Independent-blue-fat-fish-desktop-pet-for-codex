using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

internal sealed class DafeiyuSetup : Form
{
    private readonly CheckBox _miniCheck;
    private readonly CheckBox _standaloneCheck;
    private readonly Button _installButton;
    private readonly ProgressBar _progress;
    private readonly Label _status;

    private DafeiyuSetup()
    {
        Text = "Codex 大肥鱼 · Windows 安装器";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(620, 390);
        Font = new Font("Microsoft YaHei UI", 10F);

        Controls.Add(new Label
        {
            AutoSize = true,
            Text = "安装 Codex 大肥鱼",
            Font = new Font("Microsoft YaHei UI", 18F, FontStyle.Bold),
            Location = new Point(30, 24)
        });
        Controls.Add(new Label
        {
            AutoSize = false,
            Size = new Size(555, 46),
            Text = "选择要安装的组件。Mini 会出现在 Codex 的 Settings > Pets；独立桌宠可以从桌面快捷方式或安装目录中的 EXE 直接启动。\r\n" +
                "勾选独立桌宠时，安装器会自动检测并安装 Python 3、PySide6 和 Node.js（需要网络）。",
            Location = new Point(32, 68)
        });

        var components = new GroupBox
        {
            Text = "安装组件",
            Location = new Point(30, 124),
            Size = new Size(555, 126)
        };
        _miniCheck = new CheckBox
        {
            Text = "Mini（Codex Custom Pet）",
            AutoSize = true,
            Checked = true,
            Location = new Point(22, 30)
        };
        _standaloneCheck = new CheckBox
        {
            Text = "独立桌宠（桌面窗口 + 启动 EXE）",
            AutoSize = true,
            Checked = true,
            Location = new Point(22, 67)
        };
        components.Controls.Add(_miniCheck);
        components.Controls.Add(_standaloneCheck);
        Controls.Add(components);
        Controls.Add(new Label
        {
            AutoSize = false,
            Size = new Size(555, 40),
            Text = "独立桌宠安装目录：%LOCALAPPDATA%\\Codex\\codex-dafeiyu-standalone",
            Location = new Point(32, 265)
        });

        _status = new Label
        {
            AutoSize = false,
            Size = new Size(555, 22),
            Text = "准备安装",
            Location = new Point(32, 303)
        };
        Controls.Add(_status);
        _progress = new ProgressBar
        {
            Style = ProgressBarStyle.Marquee,
            MarqueeAnimationSpeed = 28,
            Visible = false,
            Location = new Point(32, 328),
            Size = new Size(370, 18)
        };
        Controls.Add(_progress);

        _installButton = new Button
        {
            Text = "开始安装",
            Size = new Size(110, 35),
            Location = new Point(475, 320)
        };
        _installButton.Click += InstallButton_Click;
        Controls.Add(_installButton);

        var cancelButton = new Button
        {
            Text = "取消",
            DialogResult = DialogResult.Cancel,
            Size = new Size(80, 35),
            Location = new Point(390, 320)
        };
        Controls.Add(cancelButton);
        CancelButton = cancelButton;
    }

    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new DafeiyuSetup());
    }

    private void InstallButton_Click(object sender, EventArgs e)
    {
        if (!_miniCheck.Checked && !_standaloneCheck.Checked)
        {
            MessageBox.Show("请至少选择一个安装组件。", "Codex 大肥鱼",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        _installButton.Enabled = false;
        _miniCheck.Enabled = false;
        _standaloneCheck.Enabled = false;
        _progress.Visible = true;
        _status.Text = "正在解包并安装，请稍候…";
        Cursor = Cursors.WaitCursor;
        try
        {
            if (_standaloneCheck.Checked)
            {
                EnsureStandaloneEnvironment();
            }
            var temporaryRoot = ExtractPayload();
            try
            {
                if (_miniCheck.Checked) InstallMini(temporaryRoot);
                if (_standaloneCheck.Checked) InstallStandalone(temporaryRoot);
            }
            finally
            {
                TryDelete(temporaryRoot);
            }

            _progress.Visible = false;
            _status.Text = "安装完成";
            var installed = _miniCheck.Checked && _standaloneCheck.Checked
                ? "Mini 和独立桌宠"
                : (_miniCheck.Checked ? "Mini" : "独立桌宠");
            MessageBox.Show(installed + " 已安装完成。", "Codex 大肥鱼",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            DialogResult = DialogResult.OK;
            Close();
        }
        catch (Exception ex)
        {
            _progress.Visible = false;
            _status.Text = "安装失败";
            MessageBox.Show(ex.Message, "安装失败",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            _installButton.Enabled = true;
            _miniCheck.Enabled = true;
            _standaloneCheck.Enabled = true;
        }
        finally
        {
            Cursor = Cursors.Default;
        }
    }

    private void EnsureStandaloneEnvironment()
    {
        SetStatus("正在检测 Python、PySide6 和 Node.js…");

        var python = FindPython();
        if (python == null)
        {
            SetStatus("正在安装 Python 3…");
            InstallWingetPackage(new[] { "Python.Python.3.14", "Python.Python.3.13", "Python.Python.3.12" },
                "Python 3");
            python = FindPython();
        }
        if (python == null)
        {
            throw new InvalidOperationException(
                "没有找到 Python 3。请安装 Python 3.12 或更高版本后重试。\r\n" +
                "也可以在 PowerShell 中运行：winget install --id Python.Python.3.14 -e");
        }

        if (!HasPySide6(python))
        {
            SetStatus("正在安装 PySide6（可能需要几分钟）…");
            var pip = RunProcess(python, PythonArguments(python, "-m pip install --user \"PySide6>=6.7,<7\""));
            if (pip.ExitCode != 0 || !HasPySide6(python))
            {
                throw new InvalidOperationException(
                    "PySide6 安装失败。\r\n\r\n" +
                    "请在 PowerShell 中运行：\r\n" +
                    "py -3 -m pip install --user \"PySide6>=6.7,<7\"\r\n\r\n" +
                    pip.Output.Trim());
            }
        }

        if (FindNode() == null)
        {
            SetStatus("正在安装 Node.js LTS…");
            InstallWingetPackage(new[] { "OpenJS.NodeJS.LTS" }, "Node.js LTS");
            if (FindNode() == null)
            {
                throw new InvalidOperationException(
                    "没有找到 Node.js。请安装 Node.js LTS 后重试。\r\n" +
                    "也可以在 PowerShell 中运行：winget install --id OpenJS.NodeJS.LTS -e");
            }
        }

        SetStatus("启动环境检测通过");
    }

    private void SetStatus(string value)
    {
        _status.Text = value;
        Application.DoEvents();
    }

    private static string FindPython()
    {
        foreach (var candidate in FindOnPath("py.exe"))
        {
            if (CanStart(candidate, "-3 --version")) return candidate;
        }
        foreach (var candidate in FindOnPath("python.exe"))
        {
            if (CanStart(candidate, "--version")) return candidate;
        }

        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var userRoot = Path.Combine(localAppData, "Programs\\Python");
        if (Directory.Exists(userRoot))
        {
            foreach (var candidate in Directory.GetFiles(userRoot, "python.exe",
                SearchOption.AllDirectories))
            {
                if (CanStart(candidate, "--version")) return candidate;
            }
        }
        return null;
    }

    private static string FindNode()
    {
        foreach (var candidate in FindOnPath("node.exe"))
        {
            if (CanStart(candidate, "--version")) return candidate;
        }
        foreach (var candidate in new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "nodejs\\node.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs\\nodejs\\node.exe")
        })
        {
            if (File.Exists(candidate) && CanStart(candidate, "--version")) return candidate;
        }
        return null;
    }

    private static IEnumerable<string> FindOnPath(string fileName)
    {
        var path = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var directory in path.Split(new[] { Path.PathSeparator },
            StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = Path.Combine(directory.Trim(), fileName);
            if (File.Exists(candidate)) yield return candidate;
        }
    }

    private static bool HasPySide6(string python)
    {
        var result = RunProcess(python, PythonArguments(python,
            "-c \"import PySide6; print(PySide6.__version__)\""));
        return result.ExitCode == 0;
    }

    private static string PythonArguments(string python, string arguments)
    {
        return string.Equals(Path.GetFileName(python), "py.exe",
            StringComparison.OrdinalIgnoreCase)
            ? "-3 " + arguments
            : arguments;
    }

    private static bool CanStart(string executable, string arguments)
    {
        try
        {
            var result = RunProcess(executable, arguments);
            return result.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }

    private static void InstallWingetPackage(IEnumerable<string> packageIds, string displayName)
    {
        string winget = null;
        foreach (var candidate in FindOnPath("winget.exe"))
        {
            winget = candidate;
            break;
        }
        string lastOutput = string.Empty;
        if (winget == null)
        {
            throw new InvalidOperationException(
                "找不到 Windows App Installer（winget），无法自动安装 " + displayName + "。\r\n" +
                "请先安装 App Installer，或手动安装 " + displayName + " 后重试。");
        }

        foreach (var packageId in packageIds)
        {
            var result = RunProcess(winget,
                "install --id " + packageId +
                " -e --scope user --accept-source-agreements --accept-package-agreements");
            lastOutput = result.Output;
            if (result.ExitCode == 0) return;

            // Some package manifests only expose a machine scope. Retry without
            // forcing user scope so winget can show the normal elevation prompt.
            result = RunProcess(winget,
                "install --id " + packageId +
                " -e --accept-source-agreements --accept-package-agreements");
            lastOutput = result.Output;
            if (result.ExitCode == 0) return;
        }

        throw new InvalidOperationException(
            displayName + " 自动安装失败。\r\n\r\n" + lastOutput.Trim());
    }

    private static string ExtractPayload()
    {
        var temporaryRoot = Path.Combine(Path.GetTempPath(),
            "CodexDafeiyuSetup-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temporaryRoot);
        try
        {
            using (var payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("PAYLOAD"))
            {
                if (payload == null) throw new InvalidOperationException("安装包资源缺失，请重新下载安装器。");
                using (var archive = new ZipArchive(payload, ZipArchiveMode.Read))
                {
                    foreach (var entry in archive.Entries)
                    {
                        var target = Path.GetFullPath(Path.Combine(temporaryRoot, entry.FullName));
                        var root = Path.GetFullPath(temporaryRoot) + Path.DirectorySeparatorChar;
                        if (!target.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                            throw new InvalidOperationException("安装包包含无效路径。");
                        if (string.IsNullOrEmpty(entry.Name))
                        {
                            Directory.CreateDirectory(target);
                            continue;
                        }
                        Directory.CreateDirectory(Path.GetDirectoryName(target));
                        using (var input = entry.Open())
                        using (var output = File.Create(target))
                            input.CopyTo(output);
                    }
                }
            }
            return temporaryRoot;
        }
        catch
        {
            TryDelete(temporaryRoot);
            throw;
        }
    }

    private static void InstallMini(string packageRoot)
    {
        var script = Path.Combine(packageRoot, "install.ps1");
        if (!File.Exists(script)) throw new InvalidOperationException("安装包缺少 Mini 安装脚本。");
        var result = RunPowerShell(script, packageRoot, "-SkipHooks");
        if (result.ExitCode != 0)
            throw new InvalidOperationException("Mini 安装失败：\r\n" + result.Output.Trim());
    }

    private static void InstallStandalone(string packageRoot)
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var codexDirectory = Path.Combine(localAppData, "Codex");
        var destination = Path.Combine(codexDirectory, "codex-dafeiyu-standalone");
        var staging = Path.Combine(codexDirectory, ".codex-dafeiyu-standalone-" + Guid.NewGuid().ToString("N"));
        var previous = Path.Combine(codexDirectory, ".codex-dafeiyu-standalone-backup-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(codexDirectory);
        try
        {
            CopyDirectory(packageRoot, staging);
            var launcher = Path.Combine(staging, "start-pet.exe");
            if (!File.Exists(launcher)) throw new InvalidOperationException("独立桌宠启动 EXE 缺失。");
            if (Directory.Exists(destination)) Directory.Move(destination, previous);
            try
            {
                Directory.Move(staging, destination);
            }
            catch
            {
                if (Directory.Exists(previous) && !Directory.Exists(destination))
                    Directory.Move(previous, destination);
                throw;
            }
            TryDelete(previous);

            launcher = Path.Combine(destination, "start-pet.exe");
            CreateShortcut(
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                    "Codex 大肥鱼桌宠.lnk"),
                launcher, destination);
            var programs = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "Microsoft\\Windows\\Start Menu\\Programs\\Codex 大肥鱼");
            Directory.CreateDirectory(programs);
            CreateShortcut(Path.Combine(programs, "Codex 大肥鱼桌宠.lnk"), launcher, destination);
            InstallHooks(destination);
        }
        finally
        {
            TryDelete(staging);
            TryDelete(previous);
        }
    }

    private static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);
        foreach (var directory in Directory.GetDirectories(source, "*", SearchOption.AllDirectories))
        {
            var relative = directory.Substring(source.Length).TrimStart(
                Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            Directory.CreateDirectory(Path.Combine(destination, relative));
        }
        foreach (var file in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
        {
            var relative = file.Substring(source.Length).TrimStart(
                Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            var target = Path.Combine(destination, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(target));
            File.Copy(file, target, true);
        }
    }

    private static RunResult RunProcess(string executable, string arguments)
    {
        var info = new ProcessStartInfo
        {
            FileName = executable,
            Arguments = arguments,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using (var process = Process.Start(info))
        {
            if (process == null)
                throw new InvalidOperationException("无法启动 " + executable + "。");
            var output = process.StandardOutput.ReadToEnd();
            output += process.StandardError.ReadToEnd();
            process.WaitForExit();
            return new RunResult(process.ExitCode, output);
        }
    }

    private static void InstallHooks(string packageRoot)
    {
        var script = Path.Combine(packageRoot, "install-user-hooks.ps1");
        if (!File.Exists(script)) return;
        var result = RunPowerShell(script, packageRoot, "-PluginRoot " + Quote(packageRoot));
        if (result.ExitCode != 0)
            throw new InvalidOperationException("独立桌宠状态桥接安装失败：\r\n" + result.Output.Trim());
    }

    private static RunResult RunPowerShell(string script, string workingDirectory, string arguments = "")
    {
        var executable = CanStart("pwsh.exe") ? "pwsh.exe" : "powershell.exe";
        var info = new ProcessStartInfo
        {
            FileName = executable,
            Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(script) +
                (string.IsNullOrWhiteSpace(arguments) ? string.Empty : " " + arguments),
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        using (var process = Process.Start(info))
        {
            if (process == null) throw new InvalidOperationException("无法启动 PowerShell。");
            var output = process.StandardOutput.ReadToEnd();
            output += process.StandardError.ReadToEnd();
            process.WaitForExit();
            return new RunResult(process.ExitCode, output);
        }
    }

    private static bool CanStart(string executable)
    {
        try
        {
            using (var process = Process.Start(new ProcessStartInfo(executable, "--version")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            }))
            {
                return process != null && process.WaitForExit(1200);
            }
        }
        catch
        {
            return false;
        }
    }

    private static void CreateShortcut(string path, string target, string workingDirectory)
    {
        try
        {
            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null) return;
            dynamic shell = Activator.CreateInstance(shellType);
            dynamic shortcut = shell.CreateShortcut(path);
            shortcut.TargetPath = target;
            shortcut.WorkingDirectory = workingDirectory;
            shortcut.Description = "Codex 大肥鱼独立桌宠";
            shortcut.Save();
        }
        catch
        {
            // The installed EXE remains available even if shortcut creation fails.
        }
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, true);
        }
        catch
        {
            // Keep recovery files if Windows still has them open.
        }
    }

    private sealed class RunResult
    {
        public readonly int ExitCode;
        public readonly string Output;
        public RunResult(int exitCode, string output) { ExitCode = exitCode; Output = output; }
    }
}
