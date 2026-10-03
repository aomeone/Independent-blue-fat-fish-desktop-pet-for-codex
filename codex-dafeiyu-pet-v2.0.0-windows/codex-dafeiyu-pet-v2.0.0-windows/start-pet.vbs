Option Explicit

Dim shell, fso, scriptDir, ps1, command, powershell
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = fso.BuildPath(scriptDir, "start-pet.ps1")
powershell = "powershell.exe"
On Error Resume Next
Dim probe
Set probe = shell.Exec("where pwsh.exe")
If Err.Number = 0 Then
    Do While probe.Status = 0
        WScript.Sleep 50
    Loop
    If probe.ExitCode = 0 Then powershell = "pwsh.exe"
End If
Err.Clear
On Error GoTo 0

command = powershell & " -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"

shell.Run command, 0, False
