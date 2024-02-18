Set colArgs = WScript.Arguments.Named
' Defines the EventLog name that the powershell script will log to.
sEventLog = colArgs.Item("EventLog")
' Defines if the EventLog source that the powershell script will log to.
sEventSource = colArgs.Item("EventSource")
' Defines the Subscribe Url for the AVD feed.
sSubscribeUrl = colArgs.Item("SubscribeUrl")

Set oShell = WScript.CreateObject("WScript.Shell")
Set oFSO = WScript.CreateObject("Scripting.FileSystemObject")

' Run the Clear-AVDClient Powershell Script and wait for it to complete.
sScriptDir = oFSO.GetParentFolderName(WScript.ScriptFullName)
sPowerShellScriptPath = sScriptDir & "\Restart-AADSignIn.vbs"
sCmd = "Powershell.exe -executionpolicy Bypass -NoLogo -WindowStyle Hidden -file " & sPowerShellScriptPath & _
    " -EventLog " & chr(34) & sEventLog & chr(34) & _
    " -EventSource " & chr(34) & sEventSource & chr(34) & _
    " -SubscribeUrl " & chr(34) & sSubscribeUrl & chr(34)
ExitCode = oShell.Run(sCmd, 0, True)
Set oShell = Nothing
WScript.Quit ExitCode