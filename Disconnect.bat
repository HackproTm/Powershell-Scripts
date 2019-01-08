ECHO @Off

SET ScriptPath=F:\GitHub\HackproTm\Powershell-Scripts
CD /D %ScriptPath%

powershell.exe -NoExit -ExecutionPolicy ByPass -NonInteractive -Command "& {.\SetIPRoute.ps1}"
