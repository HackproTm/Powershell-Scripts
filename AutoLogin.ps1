function ConvertTo-ArgumentListString {
  param (
    [Parameter(Mandatory)]
    [hashtable[]]$ArgumentList,

    [Parameter(Mandatory = $false)]
    [char]$ArgumentSeparator = ' ',

    [Parameter(Mandatory = $false)]
    [bool]$MaskSensitive = $true
  )

  $Rendered = foreach ($Arg in $ArgumentList) {

    $ArgValue     = $Arg.Value
    $ArgEnclosed  = [char]$Arg.Enclosed
    $ArgSensitive = [bool]$Arg.Sensitive

    if ($ArgValue -is [SecureString]) {
      $OutputValue = ConvertFrom-SecureString -SecureString $ArgValue -AsPlainText
    } else {
      $OutputValue = $ArgValue
    }

    if ($ArgEnclosed) {
      "$ArgEnclosed$($MaskSensitive -and $ArgSensitive ? '*' * $OutputValue.Length : $OutputValue)$ArgEnclosed"
    } else {
      $MaskSensitive -and $ArgSensitive ? '*' * $OutputValue.Length : $OutputValue
    }
  }

  return ($Rendered -join $ArgumentSeparator)
}

function Start-AutoLoginInAmazonWorkSpaces {
  param (
    [Parameter(Mandatory = $true)]
    [string]$UserName,

    [Parameter(Mandatory = $true)]
    [SecureString]$Password,

    [Parameter(Mandatory = $true)]
    [SecureString]$MFACode,

    [Parameter(Mandatory = $false)]
    [string]$WorkSpacesPath = "C:\Program Files\Amazon WorkSpaces\workspaces.exe",

    [Parameter(Mandatory = $false)]
    [string]$AutoHotkeyPath = "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe",

    [Parameter(Mandatory = $false)]
    [ValidateSet("CONSOLE", "UI", "FILE")]
    [string]$LogMode = "CONSOLE"
  )

  if (-not (Test-Path $WorkSpacesPath)) {
    throw "Amazon WorkSpaces executable not found at expected path '$WorkSpacesPath'"
  }

  if (-not (Test-Path $AutoHotkeyPath)) {
    throw "AutoHotkey executable not found at expected path '$AutoHotkeyPath'"
  }

  $AmazonWorkspaceLoginScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "templates\AmazonWorkspaceLogin.ahk"
  if (-not (Test-Path $AmazonWorkspaceLoginScriptPath)) {
    throw "AutoHotkey script for Amazon Workspace login not found at expected path '$AmazonWorkspaceLoginScriptPath'"
  }

  $ExistingProcess = Get-Process -Name "workspaces" -ErrorAction SilentlyContinue
  if ($ExistingProcess) {
    throw "Amazon WorkSpaces is already running with PID: $($ExistingProcess.Id). Close it before executing this script."
  }

  # Execute AutoHotKey script to perform login
  $ArgumentList = @(
    @{ Value = "/ErrorStdOut=UTF-8"; Enclosed = 0; Sensitive = $false }
    @{ Value = $AmazonWorkspaceLoginScriptPath; Enclosed = '"'; Sensitive = $false }
    @{ Value = $WorkSpacesPath; Enclosed = '"'; Sensitive = $false }
    @{ Value = $UserName; Enclosed = '"'; Sensitive = $false }
    @{ Value = $Password; Enclosed = '"'; Sensitive = $true }
    @{ Value = $MFACode; Enclosed = '"'; Sensitive = $true }
    @{ Value = $LogMode; Enclosed = '"'; Sensitive = $false }
  )

  Write-Host "Launching Amazon WorkSpaces with AutoHotkey from '$AutoHotkeyPath'"
  Write-Host "Starting AutoHotkey with arguments: $(ConvertTo-ArgumentListString -ArgumentList $ArgumentList)"
  Start-Process `
    -FilePath $AutoHotkeyPath `
    -ArgumentList $(ConvertTo-ArgumentListString -ArgumentList $ArgumentList -MaskSensitive $false) `
    -NoNewWindow `
    -PassThru | Wait-Process
}
