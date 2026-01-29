; =============================================
; Amazon WorkSpaces Login Helper (AHK v2)
; =============================================
; Description:
;   This AutoHotkey script automates the login process for Amazon WorkSpaces
;   by launching the WorkSpaces client and inputting the provided credentials
;   and MFA code.
;
; Requirements:
;   - AutoHotkey v2.0+ 64-bit
;   - Amazon WorkSpaces Client installed and configured (Login screen accessible)
;
; Parameters:
;   -AWSExePath="C:\Path\To\workspaces.exe" : (Required) Full path to Amazon WorkSpaces executable.
;   -UserName="MyUserName"                  : (Required) Amazon WorkSpaces Username.
;   -Password="MyPassword"                  : (Required) Amazon WorkSpaces Password.
;   -MFACode="MyMFACode"                    : (Required) Amazon WorkSpaces MFA Code.
;   -LogOutputMode=[CONSOLE|FILE|UI]        : (Optional) Logging output mode. Default is CONSOLE.
;   -LogFilePath="C:\Path\To\logfile.log"   : (Optional) Log file path if LogOutputMode is FILE. Default is $TEMP\aws_login_ahk.log.
;   -Verbose                                : (Optional) Enable verbose logging.
;
; Usage:
;   AutoHotkey.exe "ThisScriptFullPath" -AWSExePath="C:\Path\To\workspaces.exe" -UserName="MyUserName" -Password="MyPassword" -MFACode="MyMFACode" [-LogOutputMode="CONSOLE|FILE|UI"] [-LogFilePath="C:\Path\To\logfile.log"] [-Verbose]
;
; Example:
;   AutoHotkey.exe "C:\Users\John.Doe\Documents\AmazonWorkspaceLogin.ahk" -AWSExePath="C:\Program Files\Amazon WorkSpaces\workspaces.exe" -UserName="john.doe" -Password="P@ssw0rd!" -MFACode="123456" -LogOutputMode="FILE" -LogFilePath="C:\Logs\aws_login.log" -Verbose
;
; Exit Codes:
;   0 - Success
;   1 - Unspecified Error
;   2 - Parameter Validation Error
;   3 - Amazon WorkSpaces Executable Not Found
;   4 - Failed to Launch Amazon WorkSpaces
;   5 - Failed to Activate Amazon WorkSpaces Window
; =============================================

#Requires AutoHotkey v2.0+ 64-bit
#SingleInstance Force
#ErrorStdOut "UTF-8"

DetectHiddenWindows true
SetTitleMatchMode 3
SetTitleMatchMode "Slow"
FileEncoding 'UTF-8'

; =============================================
; Default Variables Assignment
; =============================================
DEFAULT_SCRIPT_TITLE   := "Amazon WorkSpaces AutoLogin"
DEFAULT_WINDOW_BUTTONS := "OK Iconx"
DEFAULT_MESSAGE_TYPE   := "ERROR"
DEFAULT_LOG_OUTPUT     := "CONSOLE"
DEFAULT_DELAY_MS       := 10000
DEFAULT_FIELD_POS_X    := 70
DEFAULT_FIELD_POS_Y    := 240
DEFAULT_LOG_FILEPATH   := A_Temp "\aws_login_ahk.log"
; =============================================
; Parameter Regular Expression (Breakdown):
; =============================================
; ^                -> Start of the argument string.
; (?:--|[-/])      -> PREFIX: Matches exactly '--', '-', or '/'.
; (?i:             -> CASE-INSENSITIVE START: Apply to the Name group.
;    (?<Name>\w+)  -> GROUP "Name": One or more alphanumeric/underscore chars.
; )                -> CASE-INSENSITIVE END.
; (?:              -> OPTIONAL ASSIGNMENT START: Handles the "=Value" part.
;    [=]           -> SEPARATOR: Exactly one '=' character.
;    (?:           -> ALTERNATION START: Pick between Quoted or Unquoted.
;       (?<Quote>["']) -> GROUP "Quote": Matches and captures either " or '.
;       (?<Quoted>.*?) -> GROUP "Quoted": Matches any content (non-greedy).
;       \k<Quote>      -> BACKREFERENCE: Matches exactly the same char found in "Quote".
;       |              -> OR.
;       (?<Unquoted>\S.*) -> OPTION 2: Capture into group "UnQuoted" ONLY if it starts with a non-whitespace character.
;    )             -> ALTERNATION END.
; )?               -> OPTIONAL ASSIGNMENT END: Makes the whole "=Value" optional.
; $                -> End of the argument string.
; =============================================
; Parameter Usage Example:
; =============================================
; Valid:   -UserName="John.Doe"  (Params["UserName"] := "JohnDoe")
; Valid:   --PATH='C:\AWS.exe'   (Params["PATH"] := "C:\AWS.exe")
; Valid:   -verbose              (Params["verbose"] := true)
; Valid:   /Log="C:\log.txt"     (Params["Log"] := "C:\log.txt")
; Valid:   /debug                (Params["debug"] := true)
; Invalid: ---path="C:\Some\Path"    (Triggers ERROR)
; Invalid: /path=C:\Path With Spaces (Triggers ERROR)
; Invalid: -path:value               (Triggers ERROR)
DEFAULT_PARAM_REGEX    := "^(?:--|[-/])(?i:(?<Name>\w+))(?:[=](?:(?<QuoteChar>[`"'])(?<QuotedValue>.*?)\k<QuoteChar>|(?<UnQuotedValue>\S.*)))?$"

; Output Redirection Setup
DllCall("AttachConsole", "Int", -1)
DEFAULT_STD_OUT        := FileOpen("*", "w `n")
DEFAULT_STD_ERR        := FileOpen("**", "w `n")

; =============================================
; Define Logging Function
; =============================================
Log(Message, PrefixDate := "NONE", PrefixData := Map(), MessageType := DEFAULT_MESSAGE_TYPE, LogOutput := DEFAULT_LOG_OUTPUT, LogFilePath := DEFAULT_LOG_FILEPATH, ExitCode := 0) {
  global DEFAULT_SCRIPT_TITLE, DEFAULT_STD_OUT, DEFAULT_STD_ERR

  StdObj := (MessageType = "ERROR") ? DEFAULT_STD_ERR : DEFAULT_STD_OUT

  local MessageLog := ""

  if (PrefixDate != "NONE" && MessageType != "GROUP" && MessageType != "ENDGROUP") {
    switch PrefixDate {
      case "DATETIME":
        MessageLog .= "[" FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss") "] "
      case "DATE":
        MessageLog .= "[" FormatTime(A_NowUTC, "yyyy-MM-dd") "] "
    }
  }

  local TimePrefix := (PrefixDate == "DATETIME") ? "[" FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss") "]" : (PrefixDate == "DATE") ? "[" FormatTime(A_NowUTC, "yyyy-MM-dd") "]" : ""


  switch LogOutput {
    case "UI":
	    MsgBox MessageLog, MessageType "-" WindowTitle, WindowOptions
    case "CONSOLE":

      StdObj.Write("[" TimeStamp "] " MessageLog "`n")
      StdObj.Read(0)
	  case "FILE":
	    try {
        FileAppend(MessageLog, LogFilePath, "UTF-8")
      } catch {
        StdObj.Write("Failed to write to log file: " LogFilePath "`n")
        StdObj.Read(0)
      }
	  default:
  	  throw Error("Invalid LogOutput specified. Valid options are: CONSOLE, UI, FILE.")
  }

  if (ExitCode != 0) {
    if IsSet(DEFAULT_STD_OUT) {
      DEFAULT_STD_OUT.Close()
    }
    if IsSet(DEFAULT_STD_ERR) {
      DEFAULT_STD_ERR.Close()
    }
    ExitApp ExitCode
  }
}

; =============================================
; Define MaskValue Function
; =============================================
Mask(Value, VisibleChars := 3) {
  if (!IsSet(Value) || Value = "") {
    return "***"
  }

  Length := StrLen(Value)
  if (Length <= VisibleChars) {
    return "***"
  }

  Masked := SubStr(Value, 1, VisibleChars)

  Loop (Length - VisibleChars) {
    Masked .= "*"
  }

  return Masked
}

; =============================================
; Parameter Validation and Parameter Assignment
; =============================================
Params := Map()
Log("Parsing Command-Line parameters.", "DATETIME", , "DEBUG", "FILE", LogFilePath, 2)
for Arg in A_Args {
  Log("Processing parameter: '" Arg "'", "DATETIME", , "DEBUG", "FILE", LogFilePath, 2)
  ErrorMessage := "Invalid parameter: '" Arg "'.`nSupported parameter structure: -Param=Val, --Param=Val, /Param=Val, -Param=`"Val`", --Param=`"Val`", /Param=`"Val`", -Param, --Param, /Param"
  if RegExMatch(Arg, DEFAULT_PARAM_REGEX, &Match) {
    ParamName := StrLower(Match.Name)

    if (Match.QuotedValue != "") {
      ParamValue := Match.QuotedValue
    }
    else if (Match.UnquotedValue != "") {
      ParamValue := Match.UnQuotedValue
    }
    else if (!InStr(Arg, "=")) {
      ParamValue := true
    }
    else {
      Log(ErrorMessage, "DATETIME", , "ERROR", LogOutputMode, LogFilePath, , 2)
    }
    Params[ParamName] := ParamValue
    Log("Parsed parameter - Name: '" ParamName "' | Value: '" ParamValue "'", , , "DEBUG", , )
  } else {
    Log(ErrorMessage, , , , LogOutputMode, 2)
  }
}

for Arg in A_Args {
  Log("Processing parameter: '" Arg "'", , , "DEBUG", , )
  if RegExMatch(Arg, DEFAULT_PARAM_REGEX, &Match) {
    ParamName := StrLower(Match.Name)
    ; If Value is empty, it's a flag (e.g., -verbose or /debug)
    ; If Value has content, it's a Key=Value pair (e.g., -user=admin or /user=admin or --user=admin)
    ParamValue := Match.Value == "" ? true : Match.Value
    Params[ParamName] := ParamValue

    Log("Parsed parameter - Name: '" ParamName "' | Value: '" ParamValue "'", , , "DEBUG", , )
  } else {
    ErrorMessage := "Invalid parameter: '" Arg "'.`nSupported parameter structure: -Param=Val, --Param=Val, /Param=Val, -Param, --Param, /Param"
    Log(ErrorMessage, , , , LogOutputMode, 2)
  }
}

AWSExePath    := Params.Has("awsexepath")    ? Params["awsexepath"]    : unset
UserName      := Params.Has("username")      ? Params["username"]      : unset
Password      := Params.Has("password")      ? Params["password"]      : unset
MFACode       := Params.Has("mfacode")       ? Params["mfacode"]       : unset
LogOutputMode := Params.Has("LogOutputMode") ? Params["LogOutputMode"] : DEFAULT_LOG_OUTPUT
LogFilePath   := Params.Has("logfilepath")   ? Params["logfilepath"]   : DEFAULT_LOG_FILEPATH
IsVerbose     := Params.Has("verbose")       ? Params["verbose"]       : false

if (!IsSet(AWSExePath) || AWSExePath = "") {
  Log("Missing required parameter: -AWSExePath=`"C:\Path\To\workspaces.exe`"", , , , LogOutputMode, 2)
}
if (!IsSet(UserName) || UserName = "") {
  Log("Missing required parameter: -UserName=`"MyUserName`"", , , , LogOutputMode, 2)
}
if (!IsSet(Password) || Password = "") {
  Log("Missing required parameter: -Password=`"MyPassword`"", , , , LogOutputMode, 2)
}
if (!IsSet(MFACode) || MFACode = "") {
  Log("Missing required parameter: -MFACode=`"MyMFACode`"", , , , LogOutputMode, 2)
}

Log("Amazon WorkSpaces AutoLogin script started.", , , "INFO", , )
Log("Amazon WorkSpaces EXE Path: " AWSExePath, , , "DEBUG", , )

; =============================================
; Validate Amazon WorkSpace Executable Path
; =============================================
if !FileExist(AWSExePath) {
  Log("Amazon WorkSpaces not found at provided path: '" AWSExePath "'", , , , LogOutputMode, 3)
}

; =============================================
; Launch Amazon WorkSpaces
; =============================================
try {
  Run AWSExePath, , , &AWSExePID
  if !WinWait("ahk_pid " AWSExePID, , DEFAULT_DELAY_MS / 1000) {
    Log("Amazon WorkSpaces window not found with PID [" AWSExePID "]", , , , LogOutputMode, 5)
  }
  Sleep DEFAULT_DELAY_MS
} catch {
  Log("Failed to launch Amazon WorkSpaces.", , , , LogOutputMode, 4)
}

Log("Amazon WorkSpaces Launched.", , , "INFO", , )
Log("Amazon WorkSpaces PID: " AWSExePID, , , "DEBUG", , )

; =============================================
; Wait for Amazon Workspace Window (by PID)
; =============================================
try {
  WinActivate("ahk_pid " AWSExePID)

  if !WinWaitActive("ahk_pid " AWSExePID, , DEFAULT_DELAY_MS / 1000) {
    Log("Failed to activate Amazon WorkSpaces window", , , , LogOutputMode, 5)
  }

  CoordMode "Mouse", "Client"
  MouseClick "Left", DEFAULT_FIELD_POS_X, DEFAULT_FIELD_POS_Y
}
catch {
  Log("An error occurred while waiting for or activating the Amazon WorkSpaces window.", , , , LogOutputMode, 5)
}

Log("Amazon WorkSpaces window activated.", , , "INFO", , )

; =============================================
; Login Sequence
; Assumes Tabulation order:
;   User -> Password -> MFA
; =============================================
Sleep(500)

Log("Starting auto login sequence.", , , "INFO", , )
Log("Sending Username: " UserName " {TAB}", , , "DEBUG", , )
SendInput UserName
SendInput("{Tab}")
Log("Sending Password: " Mask(Password) " {TAB}", , , "DEBUG", , )
SendInput(Password)
SendInput("{Tab}")
Log("Sending MFA Code: " Mask(MFACode) " {ENTER}", , , "DEBUG", , )
SendInput(MFACode)
SendInput("{Enter}")

Log("Amazon WorkSpace Auto login sequence completed.", , , "INFO", , )

if IsSet(DEFAULT_STD_OUT) {
  DEFAULT_STD_OUT.Close()
}
if IsSet(DEFAULT_STD_ERR) {
  DEFAULT_STD_ERR.Close()
}
ExitApp(0)
