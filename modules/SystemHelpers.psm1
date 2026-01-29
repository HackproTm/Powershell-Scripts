# System Helpers Module
# This module contains helper classes and functions for System and Security interactions.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Set script constants for Functions helpers
New-Variable -Option Constant -Visibility Private -Name DEFAULT_USERNAME -Value ([string][System.Environment]::UserName);
New-Variable -Option Constant -Visibility Private -Name DEFAULT_DOMAIN -Value ([string][System.Environment]::UserDomainName);
New-Variable -Option Constant -Visibility Private -Name DEFAULT_SECURE_FILENAME -Value ([string]"$DEFAULT_USERNAME.psvault");
New-Variable -Option Constant -Visibility Private -Name DEFAULT_SECURE_FILEPATH -Value ([string][System.Environment]::GetFolderPath("UserProfile"));
New-Variable -Option Constant -Visibility Private -Name DEFAULT_SECURE_FULLPATH -Value ([string](Join-Path -Path $DEFAULT_SECURE_FILEPATH -ChildPath $DEFAULT_SECURE_FILENAME));
New-Variable -Option Constant -Visibility Private -Name IS_RUNNING_IN_AZURE_DEVOPS -Value ([bool]($ENV:TF_BUILD -eq "True"));

Export-ModuleMember -Variable DEFAULT_USERNAME, DEFAULT_DOMAIN, DEFAULT_SECURE_FILENAME, DEFAULT_SECURE_FILEPATH, DEFAULT_SECURE_FULLPATH, IS_RUNNING_IN_AZURE_DEVOPS

<#
.SYNOPSIS
Logs a formatted message to the console with optional exception details and exit behavior.

.DESCRIPTION
The Out-Log function writes a formatted message to the console, with optional exception details and control over script termination.
It supports multiple message types (Error, Warning, Debug, Command, Information, Group, EndGroup) and automatically formats output for Azure DevOps environments using the appropriate logging commands.
The function allows you to terminate the script with a custom exit code after logging, making it easy to handle critical errors.
Additionally, it supports optional date and custom prefix data to enrich log context, improving traceability and event analysis.

.PARAMETER Message
The main message to log. This parameter is mandatory.

.PARAMETER ExceptionInfo
An optional exception object containing additional error details. If provided, the exception message and any error details are included in the output.

.PARAMETER PrefixDate
Specifies the type of date prefix to add before the message. Valid values are "None", "Date", and "DateTime". Default is "None".
Date format for Date is "yyyy-MM-dd" and for DateTime is "yyyy-MM-dd HH:mm:ss".
Date prefixes are not added for message types "Group" and "EndGroup".

.PARAMETER PrefixData
A hashtable of additional prefix data to add before the message. Each key-value pair is formatted as [KEY=VALUE].
The default is an empty hashtable. Additional prefix data is not added for message types "Group" and "EndGroup".

.PARAMETER MessageType
Specifies the type of message to log. Valid values are "None", "Error", "Warning", "Debug", "Command", "Information", "Group", "EndGroup". Default is "Error".
If script is running in Azure DevOps, the message type controls the prefix used in the output (e.g., ##vso[task.logissue type=error], ##vso[task.logissue type=warning],
##[debug], ##[command], ##[section], ##[group], ##[endgroup] for Azure DevOps).

.PARAMETER ExitCode
If set to a non-zero integer, the script will exit with that status code after logging the message. Default is 0 (no exit).

.EXAMPLE
PS C:\> Out-Log -Message "Failed to connect to API."

Logs the message "Failed to connect to API." to the console as an error, without any exception details, and does not exit the script.

Output:
[ERROR]Failed to connect to API.

Output in Azure DevOps:
##vso[task.logissue type=error]Failed to connect to API.

.EXAMPLE
PS C:\> try { 1/0 } catch { Out-Log -Message "Division by zero." -ExceptionInfo $_ }

Logs the message and the exception details for a division by zero error as an error, and does not exit the script.

Output:
[ERROR]Division by zero. EXCEPTION: Attempted to divide by zero.

Output in Azure DevOps:
##vso[task.logissue type=error]Division by zero. EXCEPTION: Attempted to divide by zero.

.EXAMPLE
PS C:\> Out-Log -Message "This is a warning." -MessageType Warning -PrefixDate DateTime

Logs the message as a warning with a date and time prefix.

Output:
[2024-06-15 14:30:00][WARNING]This is a warning.

Output in Azure DevOps:
##vso[task.logissue type=warning][2024-06-15 14:30:00]This is a warning.

.EXAMPLE
PS C:\> try { throw 'Critical failure' } catch { Out-Log -Message "Critical error." -PrefixDate Date -PrefixData @{ "User" = "Admin" } -ExceptionInfo $_ -ExitCode 1 }

Logs the message and exception details for a critical error with a date prefix and additional user information, then exits the script with status code 1.

Output:
[2024-06-15][ERROR][USER=Admin]Critical error. EXCEPTION: Critical failure

Output in Azure DevOps:
##vso[task.logissue type=error][2024-06-15][USER=Admin]Critical error. EXCEPTION: Critical failure

.EXAMPLE
PS C:\> Out-Log -Message "Informational message." -MessageType Information -PrefixDate Date -PrefixData @{ "ProcessID" = $PID; "Session" = "Test" }

Logs the message as an informational message with a date prefix and additional prefix information.

Output:
[2024-06-15][INFORMATION][PROCESSID=1234][SESSION=Test]Informational message.

Output in Azure DevOps:
##[section][2024-06-15][PROCESSID=1234][SESSION=Test]Informational message.

.EXAMPLE
PS C:\> Out-Log -Message "Starting Build" -MessageType Group -PrefixDate DateTime -PrefixData @{ "Task" = "Deployment" }

Logs the beginning of a process group, Date prefix and Data prefix are ignored.

Output:
----------[ BEGIN Starting Build ]----------

Output in Azure DevOps:
##[group]Starting Build

.LINK
https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/terminating-errors

.LINK
https://learn.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands
#>
function Out-Log {
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Message to log.")]
    [string] $Message,

    [Parameter(Mandatory = $false, HelpMessage = "Exception information to log. Default is `$Null.")]
    [object] $ExceptionInfo = $Null,

    [Parameter(Mandatory = $false, HelpMessage = "Type of date prefix to add before the message (None, Date, DateTime). Default is 'None'.")]
    [ValidateSet("None", "Date", "DateTime")]
    [string] $PrefixDate = "None",

    [Parameter(Mandatory = $false, HelpMessage = "Additional prefix data to add before the message. Default is empty hashtable.")]
    [hashtable] $PrefixData = @{},

    [Parameter(Mandatory = $false, HelpMessage = "Type of message to log (Error, Warning, Debug, Command, Information, Group, EndGroup). Default is 'Error').")]
    [ValidateSet("None", "Error", "Warning", "Debug", "Command", "Information", "Group", "EndGroup")]
    [string] $MessageType = "Error",

    [Parameter(Mandatory = $false, HelpMessage = "Force exit the script with a non-zero status code after logging. Default is 0 (no exit).")]
    [int] $ExitCode = 0
  )

  function Convert-MessageTypeToAzurePrefix {
    param (
      [string] $MessageType,
      [string] $Message
    )

    switch -Regex ($MessageType.ToLower()) {
      "^none$" {
        return ""
      }
      "^(error|warning)$" {
        return "##vso[task.logissue type=$_]"
      }
      "^(debug|command|endgroup)$" {
        return "##[$_]"
      }
      "^group$" {
        return "##[$_]$Message"
      }
      "^information$" {
        return "##[section]"
      }
      default {
        throw "Invalid MessageType: $_. Valid types are: None, Error, Warning, Debug, Command, Information, Group, EndGroup."
      }
    }
  }

  function Convert-MessageTypeToPrefix {
    param (
      [string] $MessageType,
      [string] $Message
    )

    switch -Regex ($MessageType.ToUpper()) {
      "^NONE$" {
        return ""
      }
      "^(ERROR|WARNING|DEBUG|COMMAND)$" {
        return "[$_]"
      }
      "^GROUP$" {
        return "----------[ BEGIN {0} ]----------" -f $Message
      }
      "^ENDGROUP$" {
        return "----------[ ENDED {0} ]----------" -f $Message
      }
      default {
        throw "Invalid MessageType: $_. Valid types are: None, Error, Warning, Debug, Command, Information, Group, EndGroup."
      }
    }
  }

  function Convert-ToLogPrefix {
    param ([hashtable] $PrefixData)

    ($PrefixData.GetEnumerator() | ForEach-Object {
      "[{0}={1}]" -f $_.Key.ToUpper(), $_.Value
    }) -join ''
  }

  # Initialize message prefix
  $MessageLog = ""

  # Add Azure DevOps prefix if running in that environment
  if ($IS_RUNNING_IN_AZURE_DEVOPS) {
    $MessageLog += Convert-MessageTypeToAzurePrefix -MessageType $MessageType -Message $Message
  }

  # Add date prefix except when message type is Group/EndGroup
  if ($PrefixDate -ne "None" -and -not $MessageType -match '(Group|EndGroup)') {
    switch ($PrefixDate) {
      "Date" { $MessageLog += "[{0}]" -f (Get-Date -Format "yyyy-MM-dd") }
      "DateTime" { $MessageLog += "[{0}]" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
    }
  }

  # Add message type prefix replacing the title message when Group/EndGroup
  $MessageLog += Convert-MessageTypeToPrefix -MessageType $MessageType -Message $Message

  # Add additional prefix data except when message type is Group/EndGroup
  if ($PrefixData.Count -gt 0 -and -not $MessageType -match '(Group|EndGroup)') {
    $MessageLog += Convert-ToLogPrefix -PrefixData $PrefixData
  }

  # Add main message
  if (-not $IS_RUNNING_IN_AZURE_DEVOPS -and -not $MessageType -match '(Group|EndGroup)') {
    $MessageLog += $Message
  }

  # Add exception message if available except when message type is Group/EndGroup
  if (-not $MessageType -match '(Group|EndGroup)' -and $ExceptionInfo -and $ExceptionInfo.Exception) {
    $MessageLog += " EXCEPTION: " + $ExceptionInfo.Exception.Message
  }

  Write-Host "$MessageLog"

  # Add exception details if available
  if ($ExceptionInfo -and $ExceptionInfo.ErrorDetails -and $ExceptionInfo.ErrorDetails.Message) {
    Write-Host "`nAPI Response:"
    $ErrorContent = $ExceptionInfo.ErrorDetails.Message
    try {
      $ErrorResponse = $ErrorContent | ConvertFrom-Json
      $ErrorResponse | ConvertTo-Json -Depth 100 | Write-Host
    } catch {
      Write-Host $ErrorContent
    }
  }

  # Exit the script with the specified exit code if non-zero
  if ($ExitCode -ne 0) {
    exit $ExitCode
  }
}

Export-ModuleMember -Function Out-Log

<#
.SYNOPSIS
Converts a string to a valid file name by removing or replacing invalid characters.

.DESCRIPTION
The Convert-ToValidFileName function takes an input string and returns a version of the string that is safe to use as a file name on Windows systems.
It removes or replaces any characters that are not allowed in file names, as defined by the [System.IO.Path]::GetInvalidFileNameChars() method.
If the resulting string is empty after removing invalid characters, a warning is shown and a random file name is generated using [System.IO.Path]::GetRandomFileName().

.PARAMETER InputString
The input string to be cleaned up for use as a file name. This parameter is mandatory.

.PARAMETER ReplacementChar
The character to replace invalid characters with. This parameter accepts a single character or an empty string. The default is a hyphen ("-").
If you provide an empty string, invalid characters will simply be removed.

.EXAMPLE
PS C:\> Convert-ToValidFileName -InputString "My:Invalid/File*Name?.txt" -ReplacementChar "-"

Return: My-Invalid-File-Name-.txt

.EXAMPLE
PS C:\> Convert-ToValidFileName -InputString "My:Invalid/File*Name?.txt" -ReplacementChar ""

Return: MyInvalidFileName.txt

.EXAMPLE
PS C:\> "Another|File<Name>.docx" | Convert-ToValidFileName

Return: Another-File-Name-.docx

.EXAMPLE
PS C:\> Convert-ToValidFileName -InputString "////" -ReplacementChar ""

WARNING: The resulting file name is empty after removing invalid characters. A random file name will be generated instead.
Return: <random file name, e.g., 1b2c3d.tmp>

.EXAMPLE
PS C:\> Convert-ToValidFileName -InputString "testfilename.txt" -ReplacementChar "_"

Return: testfilename.txt

.LINK
https://learn.microsoft.com/en-us/dotnet/api/system.io.path.getinvalidfilenamechars

.LINK
https://learn.microsoft.com/en-us/dotnet/api/system.string.isnullorwhitespace

.LINK
https://learn.microsoft.com/en-us/dotnet/api/system.io.path.getrandomfilename
#>
function Convert-ToValidFileName {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "The input string to be cleaned up for use as a file name.")]
    [string]$InputString,

    [Parameter(Mandatory = $false, HelpMessage = "Character to replace invalid characters with.")]
    [string]$ReplacementChar = "-"
  )

  # Get the characters that are invalid for file names on the current system.
  $InvalidChars = [System.IO.Path]::GetInvalidFileNameChars()
  # Escape each invalid character for use in a regular expression.
  $EscapedInvalidChars = $InvalidChars | ForEach-Object { [regex]::Escape($_) }
  # Join the escaped characters into a single string and wrap them in square brackets
  # to create a character class for the regex pattern.
  $RegexPattern = "[{0}]" -F ($EscapedInvalidChars -Join '')
  # Replace all occurrences of invalid characters with the specified replacement character.
  $CleanedString = $InputString -Replace $RegexPattern, $ReplacementChar

  if ([string]::IsNullOrWhiteSpace($CleanedString)) {
    Out-Log -Message "The resulting file name is empty after removing invalid characters. A random file name will be generated instead." -MessageType "Warning"
    $CleanedString = [System.IO.Path]::GetRandomFileName()
  }

  return $CleanedString
}

Export-ModuleMember -Function Convert-ToValidFileName

<#
.SYNOPSIS
Checks if a string is in the DOMAIN\User format.

.DESCRIPTION
The Test-IsDomainUserFormat function validates whether the provided input string matches the standard Windows domain user format: DOMAIN\User.
The DOMAIN part can contain letters, numbers, underscores, or hyphens. The User part can contain letters, numbers, underscores, hyphens, or periods.

.PARAMETER InputString
The input string to check for DOMAIN\User format. This parameter is mandatory.

.EXAMPLE
PS C:\> Test-IsDomainUserFormat -InputString "MYDOMAIN\User1"

Return: True

.EXAMPLE
PS C:\> Test-IsDomainUserFormat -InputString "MYDOMAIN-123\User.Name"

Return: True

.EXAMPLE
PS C:\> Test-IsDomainUserFormat -InputString "UserOnly"

Return: False

.EXAMPLE
PS C:\> Test-IsDomainUserFormat -InputString "MYDOMAIN\\User"

Return: False

.EXAMPLE
PS C:\> "MYDOMAIN\MyUser" | Test-IsDomainUserFormat

Return: True

.EXAMPLE
PS C:\> "\MyUser" | Test-IsDomainUserFormat

Return: False
#>
function Test-IsDomainUserFormat {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Input string to check if it is in DOMAIN\User format.")]
    [string]$InputString
  )

  # Regex pattern to match "DOMAIN\User" format
  # ^       - Start of the string
  # (       - Start of capture group 1 (for DOMAIN)
  # [a-zA-Z0-9_-]+ - One or more letters, numbers, underscores, or hyphens
  # )       - End of capture group 1
  # \\      - Literal backslash (escaped)
  # (       - Start of capture group 2 (for User)
  # [a-zA-Z0-9_.-]+ - One or more letters, numbers, underscores, hyphens, or periods
  # )       - End of capture group 2
  # $       - End of the string
  $Pattern = '^([a-zA-Z0-9_-]+)\\([a-zA-Z0-9_.-]+)$'

  # Use -Match to check if the string DOES match the pattern
  return $InputString -Match $Pattern
}

Export-ModuleMember -Function Test-IsDomainUserFormat

<#
.SYNOPSIS
Stores user credentials securely in an encrypted file.

.DESCRIPTION
The Set-UserCredentials function prompts the user security information and stores them securely in an encrypted file at the specified path.
It ensures the user security information is protected with appropriate permissions for the user.

.PARAMETER UserName
The username to use for the credentials (must be in the format DOMAIN\UserName). If not specified, the current Windows user is used.

.PARAMETER PathPass
The path where the encrypted credentials file will be stored. If not specified, the user's home directory is used.

.EXAMPLE
PS C:\> Set-UserCredentials

Prompts for credentials for the current Windows user and stores them in the default path.

.EXAMPLE
PS C:\> Set-UserCredentials -UserName "MYDOMAIN\User1"

Prompts for credentials for MYDOMAIN\User1 and stores them in the default path.

.EXAMPLE
PS C:\> Set-UserCredentials -UserName "MYDOMAIN\User1" -PathPass "C:\SecureCreds"

Prompts for credentials for MYDOMAIN\User1 and stores them in C:\SecureCreds.

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/export-clixml

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential

.LINK
https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemaccessrule
#>
function Set-UserCredentials {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, HelpMessage = "User security information to use for the credentials.")]
    [string]$UserName = $DEFAULT_USERNAME,

    [Parameter(Mandatory = $false, HelpMessage = "Path to store the user security information encryted.")]
    [string]$PathPass = $DEFAULT_SECURE_FULLPATH
  )

  # Validate the UserName format
  if (-Not (Test-IsDomainUserFormat -InputString "$UserName")) {
    Out-Log -Message "The UserName must be in the format DOMAIN\UserName." -ForceExit
  }

  # Ensure the path is valid for a file name.
  $FileNameValid = $DEFAULT_FILE_PASS -F ("$UserName" -Split "\\")[-1]
  $PathPassValid = $PathPass + "\" + (Convert-ToValidFileName($FileNameValid))

  # Check if the credentials file exists and has the correct permissions, if not, set it the permissions.
  $SetPermissions = -Not (Test-Path -Path "$PathPassValid")

  try {
    # Get User Credentials
    $SecureCredential = Get-Credential -Message "Please enter your credentials." -UserName "$UserName"
    $SecureCredential | Export-Clixml -Path "$PathPassValid"
  }
  catch {
    Out-Log -Message "It was not possible to set the credentials. Please check the credentials path permissions and try again." -ExceptionInfo $_ -ForceExit
  }

  if ($SetPermissions) {
    try {
      # Get ACL for the credentials file and set permissions
      $Acl = Get-Acl -Path "$PathPassValid"
      # Protect the ACL from inheritance
      $Acl.SetAccessRuleProtection($true, $false)
      # Remove all existing access rules for the file
      foreach ($AccessRule in $Acl.GetAccessRules($true, $false, [System.Security.Principal.NTAccount])) {
        $Acl.RemoveAccessRule($AccessRule) | Out-Null
      }
      # Set the permissions for the user
      $Permissions = [System.Security.AccessControl.FileSystemRights]::Read -Bor `
                     [System.Security.AccessControl.FileSystemRights]::Write -Bor `
                     [System.Security.AccessControl.FileSystemRights]::Synchronize
      $NewAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$UserName", $Permissions, [System.Security.AccessControl.AccessControlType]::Allow)
      $Acl.AddAccessRule($NewAccessRule)
      Set-Acl -Path "$PathPassValid" -AclObject $Acl
    }
    catch {
      Out-Log -Message "It was not possible to set the permissions for the credentials file. Please check the path and try again." -ExceptionInfo $_ -ForceExit
    }
  }
}

Export-ModuleMember -Function Set-UserCredentials

<#
.SYNOPSIS
Retrieves user credentials from an encrypted file.

.DESCRIPTION
The Get-UserCredentials function loads user credentials from an encrypted file at the specified path.
It validates that the username is in DOMAIN\User format and returns the credentials as a PSCredential object.
If the credentials file does not exist, an error message is shown.

.PARAMETER UserName
The username to use for the credentials (must be in the format DOMAIN\UserName). If not specified, the current Windows user is used.

.PARAMETER PathPass
The path where the encrypted credentials file is stored. If not specified, the user's home directory is used.

.EXAMPLE
PS C:\> Get-UserCredentials

Retrieves credentials for the current Windows user from the default path.

.EXAMPLE
PS C:\> Get-UserCredentials -UserName "MYDOMAIN\User1"

Retrieves credentials for MYDOMAIN\User1 from the default path.

.EXAMPLE
PS C:\> Get-UserCredentials -UserName "MYDOMAIN\User1" -PathPass "C:\SecureCreds"

Retrieves credentials for MYDOMAIN\User1 from C:\SecureCreds.

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/import-clixml

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential
#>
function Get-UserCredentials {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, HelpMessage = "Username to use for the credentials (use the format DOMAIN\UserName).")]
    [string]$UserName = $DEFAULT_USERNAME,

    [Parameter(Mandatory = $false, HelpMessage = "Path to get the credentials encryted.")]
    [string]$PathPass = $DEFAULT_SECURE_FULLPATH
  )

  # Validate the UserName format
  if (-Not (Test-IsDomainUserFormat -InputString "$UserName")) {
    Out-Log -Message "The UserName must be in the format DOMAIN\UserName." -ForceExit
  }

  # Ensure the path is valid for a file name.
  $FileNameValid = $DEFAULT_FILE_PASS -F ("$UserName" -Split "\\")[-1]
  $PathPassValid = $PathPass + "\" + (Convert-ToValidFileName($FileNameValid))

  if (Test-Path -Path "$PathPassValid") {
    $Credential = Import-Clixml -Path "$PathPassValid"
    return $Credential
  } else {
    Out-Log -Message "No credentials found. Please set it using Set-UserCredentials." -ForceExit
  }
}

Export-ModuleMember -Function Get-UserCredentials

<#
.SYNOPSIS
Time-Based One-Time Password (TOTP) Generator

.DESCRIPTION
Generates TOTP codes according to RFC 6238 (TOTP) and RFC 4226 (HOTP)
for use with OATH hardware tokens, authenticator apps, and more.

.PARAMETER Secret
The secret key used to generate the TOTP code

.PARAMETER InputFormat
Format of the input secret key. Can be Base32, Hex, or Text. Defaults to Text.

.PARAMETER TimeStep
The time step in seconds. Defaults to 30.

.PARAMETER Digits
The number of digits in the generated TOTP code. Defaults to 6.

.PARAMETER UnixTime
Unix timestamp to use for TOTP generation. If not specified, current time is used.

.PARAMETER Window
Time window for which the code is valid (in steps). Defaults to 1.

.EXAMPLE
PS C:\> Get-TOTP -Secret "JBSWY3DPEB3W64TMMQ======" -InputFormat Base32

Generates a TOTP code using a Base32-encoded secret key

.EXAMPLE
PS C:\> Get-TOTP -Secret "3a085cfcd4618c61dc235c300d7a70c4" -InputFormat Hex

Generates a TOTP code using a hexadecimal secret key

.EXAMPLE
PS C:\> Get-TOTP -Secret "MySecretKey" -Digits 8 -TimeStep 60

Generates an 8-digit TOTP code with a 60-second validity using a text secret

.LINK
https://datatracker.ietf.org/doc/html/rfc6238

.LINK
https://datatracker.ietf.org/doc/html/rfc4226

.LINK
https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.hmacsha1

.NOTES
This implementation follows the RFC specifications for TOTP and works
with common authenticator apps and hardware tokens.
#>

function Get-TOTP {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The secret key used to generate the TOTP code.")]
    [string]$Secret,

    [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Format of the input secret key.")]
    [ValidateSet('Base32', 'Hex', 'Text')]
    [string]$InputFormat = 'Text',

    [Parameter(Mandatory = $false, Position = 2, HelpMessage = "Hash algorithm to use for HMAC.")]
    [ValidateSet('SHA1', 'SHA256', 'SHA512')]
    [string]$Algorithm = 'SHA1',

    [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Time step in seconds.")]
    [ValidateRange(10, 300)]
    [int]$TimeStep = 30,

    [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Number of digits in the TOTP code.")]
    [ValidateRange(6, 10)]
    [int]$Digits = 6,

    [Parameter(Mandatory = $false, Position = 5, HelpMessage = "Unix timestamp to use for TOTP generation.")]
    [int64]$UnixTime = -1,

    [Parameter(Mandatory = $false, Position = 6, HelpMessage = "Time window for which the code is valid (in steps).")]
    [ValidateRange(1, 10)]
    [int]$Window = 1
  )

  begin {
    # Convert Base32 to Bytes
    function ConvertFrom-Base32 {
      [OutputType([byte[]])]
      param(
        [parameter(Mandatory = $true)]
        [string]$Base32
      )

      # Remove any padding and spaces
      $Base32 = $Base32.ToUpper() -Replace '=+$' -Replace '\s', ''

      $Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
      $BitsBuffer = ""

      foreach ($Char in $Base32.ToCharArray()) {
        $Index = $Alphabet.IndexOf($Char)
        if ($Index -lt 0) {
          Out-Log -Message "Invalid Base32 character: $Char" -ForceExit
        }
        $BitsBuffer += [Convert]::ToString($Index, 2).PadLeft(5, '0')
      }

      # Group bits into 8-bit chunks for bytes
      $Bytes = [System.Collections.Generic.List[byte]]::New()
      for ($Index = 0; $Index -lt $bitsBuffer.Length; $Index += 8) {
        # If we don't have 8 bits left, we've reached partial padding that should be ignored
        if ($Index + 8 -gt $BitsBuffer.Length) {
          break
        }
        $ByteValue = [Convert]::ToByte($BitsBuffer.Substring($Index, 8), 2)
        $Bytes.Add($ByteValue)
      }

      return $Bytes.ToArray()
    }

    # Convert hex to bytes
    function ConvertFrom-Hex {
        param([string]$HexString)

        # Clean up the hex string (remove spaces, dashes, etc.)
        $HexString = $HexString -replace '[-: ]', ''

        # Ensure it's even length
        if ($HexString.Length % 2 -ne 0) {
            throw "Hexadecimal string must have an even number of characters"
        }

        # Convert to bytes
        $bytes = [byte[]]::new($HexString.Length / 2)
        for ($i = 0; $i -lt $HexString.Length; $i += 2) {
            $bytes[$i/2] = [Convert]::ToByte($HexString.Substring($i, 2), 16)
        }

        return $bytes
    }
  }

  process {
      try {
          # Remove spaces from secret
          $Secret = $Secret -replace "\s", ""

          # Convert secret to bytes based on input format
          $secretBytes = $null

          switch ($InputFormat) {
              'Base32' {
                  $secretBytes = ConvertFrom-Base32 -Base32 $Secret
              }
              'Hex' {
                  $secretBytes = ConvertFrom-Hex -HexString $Secret
              }
              'Text' {
                  $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
              }
              default {
                  throw "Invalid input format: $InputFormat"
              }
          }

          # Verify we have valid secret bytes
          if ($null -eq $secretBytes -or $secretBytes.Length -eq 0) {
              throw "Failed to convert secret to byte array"
          }

          # Use current Unix time if not specified
          if ($UnixTime -lt 0) {
              $UnixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
          }

          # Calculate counter value (time steps from Unix epoch)
          $counter = [Math]::Floor($UnixTime / $TimeStep)

          # Initialize result array with the current time's TOTP
          $results = @()

          # Calculate TOTP for the current counter and adjacent windows if requested
          for ($i = -($Window - 1); $i -lt $Window; $i++) {
              $currentCounter = $counter + $i

              # Convert counter to bytes (big-endian)
              $counterBytes = [BitConverter]::GetBytes([int64]$currentCounter)
              if ([BitConverter]::IsLittleEndian) {
                  [Array]::Reverse($counterBytes)
              }

              # Create the HMAC object
              $hmac = switch ($Algorithm) {
                  'SHA1'   { New-Object System.Security.Cryptography.HMACSHA1 }
                  'SHA256' { New-Object System.Security.Cryptography.HMACSHA256 }
                  'SHA512' { New-Object System.Security.Cryptography.HMACSHA512 }
              }

              $hmac.Key = $secretBytes

              # Compute the HMAC
              $hash = $hmac.ComputeHash($counterBytes)

              # Get the offset
              $offset = $hash[$hash.Length - 1] -band 0x0F

              # Get the 4 bytes at the offset
              $binary = (($hash[$offset] -band 0x7F) -shl 24) -bor
                          (($hash[$offset + 1] -band 0xFF) -shl 16) -bor
                          (($hash[$offset + 2] -band 0xFF) -shl 8) -bor
                          ($hash[$offset + 3] -band 0xFF)

              # Calculate the OTP code
              $otp = $binary % [Math]::Pow(10, $Digits)

              # Format the OTP code with leading zeros
              # Fix: Use explicit int cast before ToString to avoid floating point issues
              $otpInt = [int]$otp
              $otpString = $otpInt.ToString("D$Digits")

              # Create a result object
              $result = [PSCustomObject]@{
                  OTP = $otpString
                  Counter = $currentCounter
                  Time = [DateTimeOffset]::FromUnixTimeSeconds($currentCounter * $TimeStep)
                  IsCurrentWindow = ($i -eq 0)
              }

              $results += $result
          }

          # Return the single result for the current time or an array if multiple windows
          if ($Window -eq 1) {
              return $results[0].OTP
          }
          else {
              return $results
          }
      }
      catch {
          Write-Error "Error generating TOTP: $_"
          return $null
      }
  }
}

# Helper function to check if a given TOTP code is valid for a secret
function Test-TOTP {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Secret,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Code,

        [Parameter()]
        [int]$Digits = 6,

        [Parameter()]
        [int]$TimeStep = 30,

        [Parameter()]
        [int]$Window = 1,

        [Parameter()]
        [ValidateSet('Base32', 'Hex', 'Text')]
        [string]$InputFormat = 'Base32',

        [Parameter()]
        [ValidateSet('SHA1', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA1'
    )

    try {
        # Ensure code is the expected length
        if ($Code.Length -ne $Digits) {
            Write-Warning "Code length mismatch: expected $Digits digits, got $($Code.Length)"
            return $false
        }

        # Get valid TOTPs for the current time window
        $validTotps = Get-TOTP -Secret $Secret -Digits $Digits -TimeStep $TimeStep -Window $Window -InputFormat $InputFormat -Algorithm $Algorithm

        # Handle single vs. multiple results
        if ($Window -eq 1) {
            return $validTotps -eq $Code
        }
        else {
            return $validTotps.OTP -contains $Code
        }
    }
    catch {
        Write-Error "Error validating TOTP: $_"
        return $false
    }
}
