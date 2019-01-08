ECHO @Off

SET ScriptPath=%~dp0
CD /D %ScriptPath%

powershell.exe -ExecutionPolicy ByPass -NonInteractive -Command "& {.\SetIPRoute.ps1}"
