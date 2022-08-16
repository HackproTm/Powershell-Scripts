ECHO @Off

SET ScriptPath=%~dp0
CD /D %ScriptPath%

powershell.exe -ExecutionPolicy ByPass -Command "& {.\SetIPRoute.ps1 -Create}"
