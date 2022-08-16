<#
.SYNOPSIS
Prepares and installs all the necessary software for the design and execution of
Xenial project test cases.

.DESCRIPTION
This script performs the installation and configuration in silent mode of the following programs:
- Java SE Development Kit 8 Update 162 8.0.1620.12
- Android SDK (Includes the minimum packages required.)
- Android Studio 3.1.1
- NodeJs 7.0.0
- Git 2.16.1.4
- SourceTree 2.4.7
- Microsoft Visual C++ 2013 Redistributable 12.0.30501
- Python 3.5.4
- Microsoft Visual Studio Code 1.20.0 (Includes the minimum extensions required.)
- Pycharm Community 2017.3.3
- Appium 1.3.2
- MongoDb 3.6.2
- MongoDb Compass Community 1.12.1
- Docker for Windows 17.12.0-ce-win47
- Visual Studio Emulator for Android
- Sysinternals Suite
- Vysor 1.8.5
- Universal ADB Drivers 1.0.4
- ConEmu 18.03.09

Additionally this script clones and preconfigures the following repositories:
- https://bit.heartlandcommerce.com/scm/hc/tea-data-management-ui.git'
- https://bit.heartlandcommerce.com/scm/hc/tea-pos-app.git'
- https://bit.heartlandcommerce.com/scm/hc/pos-devices.git'

.NOTES
Author: Edwin Mantilla Santamaria
Copyright (C) 2018 Xenial & PSL S.A.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

.PREREQUISITES
This script required for your correct execution:
- Powershell v5.0 installed
- Run this script with Administrative Privilegies.
- Run this script in OS 64bits version.
- 7Zip installed in $Env:ProgramFiles or ${Env:ProgramFiles(x86)}.
- Microsoft Installer installed.
- For installation of Docker, OS is required Windows 10 Professional.
- For clone the repositories are required the Xenial Bitbucket Credentials.
- Access to Internet or access to the Shared Temporary Folder in Network of PSL.
- Disk free up to 8Gb.
- Some setup files require access to Internet for internal components update and register software.
- The clone operation the repositories always require access to internet.

.INPUTS
None

.OUTPUTS
None

.PARAMETER PathInstall
The destination full path where all software will be install.

**NOTES:**
- The Path to install all software not should contains spaces.
- Is advisable that the install path uses with short names.
- This parameter should be different value to RepositoryPath

.PARAMETER PathRepository
The destination full path where all repositories will be clone.

**NOTES:**
- The Path to clone all repositories not should contains spaces.
- Is advisable that the clone path uses with short names.
- This parameter should be different value to PathInstall

.PARAMETER UseSharedFolder
Indicates if the setup file will be download from Internet or the Shared
Temporary Folder in Network of PSL.

**NOTES:**
Use $True for download from Shared Temporary Folder, the script determine
if you are in the PSL office of Medellin or Bogota. Otherwise use $False
for download directly of internet.

.EXAMPLE
Set-ExecutionPolicy Bypass -Scope Process -Force;
InstallAppsXenial -PathInstall "D:\Apps" -PathRepository "D:\Xenial" -UseSharedFolder $False;
#>
Param
    (
        [parameter(Mandatory=$False, Position=0)][string]$PathInstall,
        [parameter(Mandatory=$False, Position=1)][string]$PathRepository,
        [parameter(Mandatory=$False, Position=2)][boolean]$UseSharedFolder = $False
    )



###########################
# Begin General Functions #
###########################
Function ConvertToText
{
    Param
    (
        [parameter(Mandatory=$False, Position=0)][Alias("Value")]$O,
        [parameter(Mandatory=$False, Position=1)][Int]$Depth = 9,
        [parameter(Mandatory=$False, Position=2)][Switch]$Type,
        [parameter(Mandatory=$False, Position=3)][Switch]$Expand,
        [parameter(Mandatory=$False, Position=4)][Int]$Strip = -1,
        [parameter(Mandatory=$False, Position=5)][String]$Prefix,
        [parameter(Mandatory=$False, Position=6)][Int]$Index
    )
	
    Function Iterate
    {
        Param
        (
            [parameter(Mandatory=$False, Position=0)]$Value,
            [parameter(Mandatory=$False, Position=1)][String]$Prefix,
            [parameter(Mandatory=$False, Position=2)][Int]$Index = $Index + 1
        )
        
        ConvertToText $Value -Depth:$Depth -Strip:$Strip -Type:$Type -Expand:$Expand -Prefix:$Prefix -Index:$Index;
    }

	$NewLine, $Space = If ($Expand)
                       {
                           "`r`n", ("`t" * $Index);
                       }
                       Else
                       {
                           $Null;
                       };
    $V = "";
    If ($Null -eq $O)
    {
        $V = '$Null';
    }
    Else
    {
        $V = If ($O -is "Boolean")
             {
                "`$$O";
             }
             ElseIf ($O -is "String")
             {
                If ($Strip -ge 0)
                {
                    '"' + (($O -replace "[\s]+", " ") -replace "(?<=[\s\S]{$Strip})[\s\S]+", "...") + '"';
                }
                Else
                {
                    """$O""";
                }
             }
             ElseIf ($O -is "DateTime")
             {
                $O.ToString("yyyy-MM-dd HH:mm:ss");
             }
             ElseIf ($O -is "ValueType" -or ($O.Value.GetTypeCode -and $O.ToString.OverloadDefinitions))
             {
                $O.ToString();
             }
             ElseIf ($O -is "Xml")
             {
                (@(Select-XML -Xml $O *) -join "$NewLine$Space") + $NewLine;
             }
             ElseIf ($Index -gt $Depth)
             {
                $Type = $True; "...";
             }
             ElseIf ($O -is "Array")
             {
                "@(", @(&{
                        For ($_ = 0; $_ -lt $O.Count; $_++)
                        {
                            Iterate $O[$_];
                        }
                    }), ", ", ")";
             }
             ElseIf ($O.GetEnumerator.OverloadDefinitions)
             {
                "@{", @(
                        ForEach ($_ In $O.Keys)
                        {
                            Iterate $O.$_ "$_ = ";
                        }
                    ), "; ", "}";
             }
             ElseIf ($O.PSObject.Properties -and !$O.value.GetTypeCode)
             {
                "{", @(
                        ForEach ($_ In $O.PSObject.Properties | Select-Object -ExpandProperty Name)
                        {
                            Iterate $O.$_ "$_`: ";
                        }
                    ), "; ", "}";
             }
             Else
             {
                $Type = $True; "?";
             }
    }
    If ($Type)
    {
        $Prefix += "[" + $(
                Try
                {
                    $O.GetType();
                }
                Catch
                {
                    $Error.Remove($Error[0]);
                    "$Var.PSTypeNames[0]";
                }
            ).ToString().Split(".")[-1] + "]";
    }
    "$Space$Prefix" + $(
            If ($V -is "Array")
            {
                $V[0] + $(
                        If ($V[1]) 
                        {
                            If ($NewLine)
                            {
                                $V[2] = $NewLine;
                            }
		    	            $NewLine + ($V[1] -join $V[2]) + $NewLine + $Space;
                        }
                        Else
                        {
                            "";
                        }
                    ) + $V[3];
            }
            Else
            {
                $V;
            }
        );
}



Function WriteInLog
{
    Param
    (
        $0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
        [ConsoleColor]$BackgroundColor = (Get-Host).Ui.RawUi.BackgroundColor,
        [ConsoleColor]$ForegroundColor = (Get-Host).Ui.RawUi.ForegroundColor,
        [String]$Separator = " ",
        [Switch]$NoNewline,
        [Int]$Indent = 0,
        [Int]$Strip = 80,
        [Switch]$QuoteString,
        [Int]$Depth = 1,
        [Switch]$Expand,
        [Switch]$Type,
        [Switch]$FlushErrors,
        [parameter(ValueFromRemainingArguments = $True)][Object[]]$IgnoredArguments
    )
    
	$Noun = ($MyInvocation.InvocationName -split "-")[-1];
    
    Function IsQ
    {
        Param
        (
            [parameter(Mandatory=$False, Position=0)]$Item
        )

        If ($Item -is [String])
        {
            $Item -eq "?";
        }
        Else
        {
            $False;
        }
    }

	$Arguments = $MyInvocation.BoundParameters;
    If (!$My.Log.ContainsKey("Location"))
    {
        SetLogFile "$Env:Temp\$($My.Name).log";
    }
    If (!$My.Log.ContainsKey("Buffer"))
    {
        $My.Log.ProcessStart = Get-Date ((Get-Process -Id $PID).StartTime) -Format "yyyy-MM-dd HH:mm:ss.ff";
        $My.Log.ScriptStart = Get-Date -Format "yyyy-MM-dd HH:mm:ss.ff";
        $My.Log.Buffer = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.ff") + " `tPowerShell version: $($PSVersionTable.PSVersion)`r`n";
        $My.Log.Buffer += (Get-Date -Format "yyyy-MM-dd HH:mm:ss.ff") + " `tProcess start: " + (ConvertToText $My.Log.ProcessStart) + "`r`n";
        $My.Log.Buffer += (Get-Date -Format "yyyy-MM-dd HH:mm:ss.ff") + "`t$($My.Name) version: $($My.Version)`r`n";
        $My.Log.Buffer += (Get-Date -Format "yyyy-MM-dd HH:mm:ss.ff") + "`tCommand line: $($My.Path) $($My.Arguments)`r`n";
    }
    If ($FlushErrors)
    {
        $My.Log.ErrorCount = $Error.Count;
    }
    ElseIf (!$My.Log.ContainsKey("ErrorCount"))
    {
        $My.Log.ErrorCount = 0;
    }
    While ($My.Log.ErrorCount -lt $Error.Count)
    {
		$Err = $Error[$Error.Count - ++$My.Log.ErrorCount];
        $My.Log.Buffer += @("`r`n")[!$My.Log.Inline] + "Error at $($Err.InvocationInfo.ScriptLineNumber),$($Err.InvocationInfo.OffsetInLine): $Err`r`n";
    }
    If ($My.Log.Inline)
    {
        $Items = @("");
    }
    Else
    {
        $Items = @();
    }
    For ($i = 0; $i -le 15; $i++)
    {
        If ($Arguments.ContainsKey("$i"))
        {
            $Argument = $Arguments.Item($i);
        }
        Else
        {
            $Argument = $Null;
        }
        If ($i)
        {
			$Text = ConvertToText $Value -Type:$Type -Depth:$Depth -Strip:$Strip -Expand:$Expand;
            If ($Value -is [String] -and !$QuoteString)
            {
                $Text = $Text -replace "^""" -replace """$";
            }
        }
        Else
        {
            $Text = $Null;
        }
        If (IsQ($Argument))
        {
            $Value;
        }
        Else
        {
            If (IsQ($Value))
            {
                $Text = $Null;
            }
        }
        If ($Text)
        {
            $Items += $Text;
        }
        If ($Arguments.ContainsKey("$i"))
        {
            $Value = $Argument;
        }
        Else
        {
            Break;
        }
	}
    If ($Arguments.ContainsKey("0") -and ($Noun -ne "Debug" -or $Script:Debug))
    {
        $Tabs = "`t" * $Indent;
        $Line = $Tabs + (($Items -join $Separator) -replace "`r`n", "`r`n$Tabs");
        If (!$My.Log.Inline)
        {
            $My.Log.Buffer += (Get-Date -Format "yyyy-MM-dd HH:mm:ss.ff") + "`t$Tabs";
        }
		$My.Log.Buffer += $Line -replace "`r`n", "`r`n           `t$Tabs";
        If ($Noun -ne "Verbose" -or $Script:Verbose)
        {
			$Write = "Write-Host `$Line" + $((Get-Command Write-Host).Parameters.Keys | Where-Object { $Arguments.ContainsKey($_) } | ForEach-Object { " -$_`:`$$_" });
			Invoke-Command ([ScriptBlock]::Create($Write));
		}
    }
    Else
    {
        $NoNewline = $False;
    }
	$My.Log.Inline = $NoNewline;
    If (($My.Log.Location -ne "") -and $My.Log.Buffer -and !$NoNewline)
    {
        If ((Add-Content $My.Log.Location $My.Log.Buffer -ErrorAction SilentlyContinue -PassThru).Length -gt 0)
        {
            $My.Log.Buffer = "";
        }
	}
}

Set-Alias Logs-Write    WriteInLog -Scope:Global;
Set-Alias Logs-Verbose  WriteInLog -Scope:Global -Description "By default, the verbose log entry is not displayed, but you can display it by changing the common -Verbose parameter.";
Set-Alias Logs-Debug    WriteInLog -Scope:Global -Description "By default, the debug log entry is not displayed and not recorded, but you can display it by changing the common -Debug parameter.";



Function SetLogFile
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][IO.FileInfo]$Location,
        [parameter(Mandatory=$False, Position=1)][Int]$Preserve = 100e3,
        [parameter(Mandatory=$False, Position=2)][String]$Divider = ""
    )

	$MyInvocation.BoundParameters.Keys | ForEach-Object { $My.Log.$_ = $MyInvocation.BoundParameters.$_ };
    If ($Location)
    {
        If ((Test-Path($Location)) -and $Preserve)
        {
			$My.Log.Length = (Get-Item($Location)).Length;
            If ($My.Log.Length -gt $Preserve)
            {
                # Prevent the log file to grow indefinitely
				$Content = [String]::Join("`r`n", (Get-Content $Location));
				$Start = $Content.LastIndexOf("`r`n$Divider`r`n", $My.Log.Length - $Preserve);
                If ($Start -gt 0)
                {
                    Set-Content $Location $Content.SubString($Start + $Divider.Length + 4);
                }
			}
            If ($My.Log.Length -gt 0)
            {
                Add-Content $Location $Divider;
            }
		}
	}
}

Set-Alias Logs-File SetLogFile -Scope:Global -Description "Redirects the log file to a custom location.";



Function WriteEndInLog
{
    Param
    (
        [parameter(Mandatory=$False, Position=0)][Switch]$Exit,
        [parameter(Mandatory=$False, Position=1)][Int]$ErrorLevel
    )
	Logs-Write "End" -NoNewline;
	Logs-Write ("(Execution time: " + ((Get-Date) - $My.Log.ScriptStart) + ", Process time: " + ((Get-Date) - $My.Log.ProcessStart) + ")");
    If ($Exit)
    {
        Exit $ErrorLevel;
    }
    Else
    {
        Break Script;
    }
}

Set-Alias Logs-End WriteEndInLog -Scope:Global -Description "Logs the remaining entries and errors and end the script."



# Validate if the Path is valid
Function ValidatePaths
{
    Param
    (
        [parameter(Mandatory=$False, Position=0)][string]$PathToValidate
    )

    $IsValid = $True;
    Logs-Debug "(ValidatePaths) Validating the path '$PathToValidate'.";
    If ([string]::IsNullOrEmpty($PathToValidate))
    {
        Write-Host "`r`n";
        Logs-Write "ERROR: Path parameter is null or empty." -ForegroundColor Red -BackgroundColor Black;
        $IsValid = $False;
    }
    If (-not (Test-Path -IsValid "$PathToValidate" -PathType Any))
    {
        Write-Host "`r`n";
        Logs-Write "ERROR: '$PathValidate' not is a path valid." -ForegroundColor Red -BackgroundColor Black;
        $IsValid = $False;
    }
    Logs-Debug "(ValidatePaths) Returning '$IsValid'.";
    Return $IsValid;
}



# Validate if the Path exist in the system
Function ExistsPaths
{
    Param
    (
        [parameter(Mandatory=$False, Position=0)][string]$PathToValidate,
        [parameter(Mandatory=$False, Position=1)][boolean]$PrintWarning = $False
    )

    Logs-Debug "(ExistsPaths) Validating if the path '$PathToValidate' exist.";
    $Exist = $True;
    If (-not (ValidatePaths $PathToValidate))
    {
        $Exist = $False;
    }
    Else
    {
        If (-not (Test-Path -Path "$PathToValidate" -PathType Any))
        {
            If ($PrintWarning)
            {
                Logs-Write "The path '$PathToValidate' not was found in the system.";
            }
            $Exist = $False;
        }
    }
    Logs-Debug "(ExistsPaths) Returning '$Exist'.";
    Return $Exist;
}



# Validate if path is Empty
Function PathIsEmpty
{
    Param
    (
        [parameter(Mandatory=$False, Position=0)][string]$PathToValidate
    )

    Logs-Debug "(PathIsEmpty) Validating if the path '$PathToValidate' not contains files.";
    $IsEmpty = $True;
    If (ExistsPaths $PathToValidate)
    {
        $IsEmpty = (Get-ChildItem $PathToValidate -File -Force -ErrorAction SilentlyContinue | Select-Object -First 1 | Measure-Object).Count -eq 0;
    }
    Logs-Debug "(PathIsEmpty) Returning '$Exist'.";
    Return $IsEmpty;
}



# Validate if Windows Service exists
Function ExistsService
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string]$ServiceName
    )

    Logs-Debug "(ExistsService) Validating if the service '$ServiceName' exist.";
    $Exist = [boolean](Get-Service $ServiceName -ErrorAction SilentlyContinue);
    Logs-Debug "(ExistsService) Returning '$Exist'.";
    Return $Exist;
}



# Validate if Application already installed
Function IsAppInstalled
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string]$AppName
    )

    Logs-Debug "(IsAppInstalled) Validating if the '$AppName' App is installed.";
    $Key = Get-UninstallRegistryKey "$AppName*" -WarningAction SilentlyContinue;    
    $IsInstalled = ($Null -ne $Key);
    Logs-Debug "(IsAppInstalled) Returning '$IsInstalled'.";
    Return $IsInstalled;
}



#Validate if the Address is an URI Web of the http or https protocols
Function IsURIWeb
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string]$Address
    )

    Logs-Debug "(IsURIWeb) Validating if '$Address' is a URI Web valid.";
    $Uri = $Address -as [System.URI];
    $IsUri = [boolean]($Null -ne $Uri.AbsoluteURI -and $Uri.Scheme -match '[http|https]');
    Logs-Debug "(IsURIWeb) Returning '$IsUri'.";
    Return $IsUri;
}



#Prepare the Directory for installation, If the Directory exist clean it (when $CrearDirectory=$True), otherwise create it
Function PrepareDirectory
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][string]$DirectoryPath,
        [parameter(Mandatory=$False, Position=1)][boolean]$ClearDirectory=$False
    )

    Logs-Debug "(PrepareDirectory) Preparing the '$DirectoryPath' directory.";
    If (-not (ExistsPaths $DirectoryPath $True))
    {
        Logs-Debug "(PrepareDirectory) The '$DirectoryPath' directory does not exist in the System. Creating it.";
        Logs-Write "Creating directory '$DirectoryPath'.";
        New-Item -Type Directory -Path $DirectoryPath -Force | Out-Null;
    }
    Else
    {
        If ($ClearDirectory)
        {
            Logs-Debug "(PrepareDirectory) The '$DirectoryPath' directory exist in the System. Cleaning it.";
            Clear-Content -Path $DirectoryPath -Force | Out-Null;
        }
        Else
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: The '$DirectoryPath' directory exist in the System. Some files could be replaced." -ForegroundColor DarkYellow;
            Logs-End -Exit -ErrorLevel -12345;
        }
    }
}



#Obtaint the short path for any path file or folder
Function Get-ShortPath
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string]$PathFile
    )

    $FileSystem = New-Object -ComObject Scripting.FileSystemObject;
    $ShortPath = [string]::Empty;
    Logs-Debug "(Get-ShortPath) Getting the Short Path from '$PathFile'.";
    If ($FileSystem.FileExists($PathFile) -eq $True)
    {
        Logs-Debug "(Get-ShortPath) Path found like a File.";
        $FileInfo = $FileSystem.GetFile($PathFile);
        $ShortPath = $FileInfo.ShortPath;
    }
    Else
    {
        If ($FileSystem.FolderExists($PathFile) -eq $True)
        {
            Logs-Debug "(Get-ShortPath): Path found like a Folder.";
            $FileInfo = $FileSystem.GetFolder($PathFile);
            $ShortPath = $FileInfo.ShortPath;
        }
        Else
        {
            Logs-Write "The '$PathFile' Path was not found in the System." -ForegroundColor Red -BackgroundColor Black;
        }
    }
    Logs-Debug "(Get-ShortPath) Returning '$ShortPath'.";
    Return $ShortPath;
}



Function Test-ProcessAdminRights
{
    Logs-Debug "(Test-ProcessAdminRights) Validating if current user have Admin rights.";
    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent([Security.Principal.TokenAccessLevels]'Query,Duplicate'));
    $IsAdmin = $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
    Logs-Debug "(Test-ProcessAdminRights) Returning '$IsAdmin'.";
    Return $IsAdmin;
}



Function Update-SessionEnvironment
{
    Param
    (
        [parameter(Mandatory=$False, Position=0)][boolean]$PrintMessage = $True
    )

    If ($PrintMessage)
    {
        Logs-Write "Refreshing environment variables for the current process (from the windows registry).";
    }
    $UserName = $Env:UserName;
    $Architecture = $Env:Processor_Architecture;
    $Path = $Env:Path;
    $PsModulePath = $Env:PSModulePath;
    #Ordering is important here, $User comes after so we can override $Machine
    'Process', 'Machine', 'User' |
        ForEach-Object {
            $Scope = $_;
            Get-EnvironmentVariableNames -Scope $Scope | ForEach-Object {
                    $ValueToRefresh = (Get-EnvironmentVariable -Name $_ -Scope $Scope);
                    Logs-Debug "(Update-SessionEnvironment) Refresh environment variable 'Env:$($_)' = '$ValueToRefresh'."
                    Set-Item "Env:$($_)" -Value $ValueToRefresh;
            }
        };
    #Path gets special treatment b/c it munges the two together
    $Paths = 'Machine', 'User' | ForEach-Object {
            (Get-EnvironmentVariable -Name 'PATH' -Scope $_) -split ';';
        } | Select-Object -Unique;
    $Env:Path = $Paths -join ';';
    Logs-Debug "(Update-SessionEnvironment) Refresh environment variable 'PATH' = '$Env:Path'."
    #PSModulePath is almost always updated by process, so we want to preserve it.
    $Env:PSModulePath = $PsModulePath;
    Logs-Debug "(Update-SessionEnvironment) Refresh environment variable 'PSMODULEPATH' = '$Env:PSModulePath'."
    #Reset user and architecture
    If ($UserName)
    {
        $Env:UserName = $UserName;
        Logs-Debug "(Update-SessionEnvironment) Refresh environment variable 'USERNAME' = '$Env:UserName'."
    }
    If ($Architecture)
    {
        $Env:Processor_Architecture = $Architecture;
        Logs-Debug "(Update-SessionEnvironment) Refresh environment variable 'PROCESSOR_ARCHITECTURE' = '$Env:Processor_Architecture'."
    }
}



Function Get-EnvironmentVariableNames
{
    Param
    (
        [parameter(Mandatory=$False, Position=0)][System.EnvironmentVariableTarget]$Scope = "User"
    )

    Logs-Debug "(Get-EnvironmentVariableNames) Getting environment variables from '$Scope' Scope."
    Switch ($Scope)
    {
        'User'
        {
            $Variables = Get-Item 'HKCU:\Environment' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property;
        }
        'Machine'
        {
            $Variables = Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property;
        }
        'Process'
        {
            $Variables = Get-ChildItem Env:\ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Key;
        }
        default
        {
            $Variables = @();
            Write-Host "`r`n";
            Logs-Write "ERROR: Unsupported environment scope: $Scope." -ForegroundColor Red -BackgroundColor Black;
        }
    }
    Logs-Debug "(Get-EnvironmentVariableNames) Environment variables found in '$Scope' Scope:"
    Logs-Debug $Variables -Expand;
}



Function Get-EnvironmentVariable
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $Name,
        [parameter(Mandatory=$True, Position=1)][System.EnvironmentVariableTarget] $Scope,
        [parameter(Mandatory=$False, Position=2)][switch] $PreserveVariables = $False,
        [parameter(ValueFromRemainingArguments = $True)][Object[]] $IgnoredArguments
    )

    $Machine_Environment_Registry_Key_Name = "SYSTEM\CurrentControlSet\Control\Session Manager\Environment\";
    $Win32RegistryKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Machine_Environment_Registry_Key_Name);
    If ($Scope -eq [System.EnvironmentVariableTarget]::User)
    {
        $User_Environment_Registry_Key_Name = "Environment";
        $Win32RegistryKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($User_Environment_Registry_Key_Name);
    }
    ElseIf ($Scope -eq [System.EnvironmentVariableTarget]::Process)
    {
        Return [Environment]::GetEnvironmentVariable($Name, $Scope);
    }
    $RegistryValueOptions = [Microsoft.Win32.RegistryValueOptions]::None;
    If ($PreserveVariables)
    {
        Logs-Debug "Choosing not to expand environment names.";
        $RegistryValueOptions = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames;
    }
    $EnvironmentVariableValue = [string]::Empty;
    Try
    {
        If ($Null -ne $Win32RegistryKey)
        {
            #Some versions of Windows do not have HKCU:\Environment
            $EnvironmentVariableValue = $Win32RegistryKey.GetValue($Name, [string]::Empty, $RegistryValueOptions);
        }
    }
    Catch
    {
        Logs-Debug "Unable to retrieve the $Name environment variable. Details: $_.";
    }
    Finally
    {
        If ($Null -ne $Win32RegistryKey)
        {
            $Win32RegistryKey.Close();
        }
    }
    If ($Null -eq $EnvironmentVariableValue -or $EnvironmentVariableValue -eq '')
    {
        $EnvironmentVariableValue = [Environment]::GetEnvironmentVariable($Name, $Scope);
    }
    Return $EnvironmentVariableValue;
}


Function Set-EnvironmentVariable
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $Name,
        [parameter(Mandatory=$False, Position=1)][string] $Value,
        [parameter(Mandatory=$False, Position=2)][System.EnvironmentVariableTarget] $Scope,
        [parameter(ValueFromRemainingArguments = $True)][Object[]] $IgnoredArguments
    )

	If ($Name.ToUpper().Trim() -ne 'PATH')
    {
		Logs-Write "Setting Environment Variable $Name with the value $Value in `'$Scope`'.";
	}
    If ($Scope -eq [System.EnvironmentVariableTarget]::Process -or $Null -eq $Value -or $Value -eq '')
    {
        Return [Environment]::SetEnvironmentVariable($Name, $Value, $Scope);
    }
    $KeyHive = 'HKEY_LOCAL_MACHINE';
    $RegistryKey = "SYSTEM\CurrentControlSet\Control\Session Manager\Environment\";
    $Win32RegistryKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($RegistryKey);
    If ($Scope -eq [System.EnvironmentVariableTarget]::User)
    {
        $KeyHive = 'HKEY_CURRENT_USER';
        $RegistryKey = "Environment";
        $Win32RegistryKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($RegistryKey);
    }
    $RegistryType = [Microsoft.Win32.RegistryValueKind]::String;
    Try
    {
        If ($Win32RegistryKey.GetValueNames() -contains $Name)
        {
            $RegistryType = $Win32RegistryKey.GetValueKind($Name);
        }
    }
    Catch
    {
        # The value doesn't yet exist move along, nothing to see here.
    }
    Logs-Debug "Registry type for $Name is/will be $RegistryType";
    If ($Name -eq 'PATH')
    {
        $RegistryType = [Microsoft.Win32.RegistryValueKind]::ExpandString;
    }
    [Microsoft.Win32.Registry]::SetValue($KeyHive + "\" + $RegistryKey, $Name, $Value, $RegistryType);
    Try
    {
        #Make everything refresh because sometimes explorer.exe just doesn't get the message that things were updated.
        If (-not ("Win32.NativeMethods" -as [Type]))
        {
            #Import SendMessageTimeOut from Win32
            Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition "[DllImport(""user32.dll"", SetLastError = true, CharSet = CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);";
        }
        $Hwnd_BroadCast = [intptr]0xffff;
        $Wm_SettingChange = 0x1a;
        $Result = [uintptr]::zero;
        #Notify all windows of environment block change
        [Win32.NativeMethods]::SendMessageTimeout($Hwnd_BroadCast, $Wm_SettingChange,  [uintptr]::Zero, "Environment", 2, 5000, [ref]$Result) | Out-Null;
    }
    Catch
    {
        Logs-Write "Failure attempting to let Explorer know about updated environment settings.`n  $($_.Exception.Message)" -ForegroundColor DarkYellow;
    }
    Update-SessionEnvironment;
}


Function UnInstall-EnvironmentVariablePath
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $PathToUnInstall,
        [parameter(Mandatory=$False, Position=1)][System.EnvironmentVariableTarget] $PathType = [System.EnvironmentVariableTarget]::User
    )

    Logs-Write "Finding the Path to UnInstall: `'$PathToUnInstall`'.";
    #Get the PATH variable
    $EnvPath = $Env:PATH;
    If ($EnvPath.ToLower().Contains($PathToUnInstall.ToLower()))
    {
        $StatementTerminator = ';';
        Logs-Write "PATH environment variable contains $PathToUnInstall. Removing.";
        $ActualPath = [System.Collections.ArrayList](Get-EnvironmentVariable -Name 'Path' -Scope $PathType).Split($StatementTerminator);
        $ActualPath.Remove($PathToUnInstall);
        $NewPath = $ActualPath -Join $StatementTerminator;
        If ($PathType -eq [System.EnvironmentVariableTarget]::Machine)
        {
            If (Test-ProcessAdminRights)
            {
                Set-EnvironmentVariable -Name 'Path' -Value $NewPath -Scope $PathType;
            }
            Else
            {
                Logs-Write "Run Powershell with Administrative Privilegies for uninstall `'$PathToUnInstall`' from `'$PathType`' PATH. Could not remove." -ForegroundColor DarkYellow;
            }
        }
        Else
        {
            Set-EnvironmentVariable -Name 'Path' -Value $NewPath -Scope $PathType;
        }
    }
    Else
    {
        Logs-Write "The path to uninstall `'$PathToUnInstall`' was not found in the `'$PathType`' PATH. Could not remove.";
    }    
}


Function Install-EnvironmentVariable
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $VariableName,
        [parameter(Mandatory=$True, Position=1)][ValidateNotNullOrEmpty()][string] $VariableValue,
        [parameter(Mandatory=$False, Position=2)][System.EnvironmentVariableTarget] $VariableType = [System.EnvironmentVariableTarget]::User,
        [parameter(ValueFromRemainingArguments = $True)][Object[]] $IgnoredArguments
    )

    Logs-Write "Creating Environment Variable $VariableName with the value $VariableValue in `'$VariableType`'.";
    If ($VariableType -eq [System.EnvironmentVariableTarget]::Machine)
    {
        If (Test-ProcessAdminRights)
        {
            Set-EnvironmentVariable -Name $VariableName -Value $VariableValue -Scope $VariableType;
        }
        Else
        {
            Logs-Write "Run Powershell with Administrative Privilegies for install `'$VariableName`' from `'$VariableType`' Environment Variable. Could not add." -ForegroundColor DarkYellow;
        }
    }
    Else
    {
        Try
        {
            Set-EnvironmentVariable -Name $VariableName -Value $VariableValue -Scope $VariableType;
        }
        Catch
        {
            If (Test-ProcessAdminRights)
            {
                # HKCU:\Environment may not exist, which happens sometimes with Server Core
                Set-EnvironmentVariable -Name $VariableName -Value $VariableValue -Scope Machine;
            }
            Else
            {
                Logs-Write "Run Powershell with Administrative Privilegies for install `'$VariableName`' from `'$VariableType`' Environment Variable. Could not add." -ForegroundColor DarkYellow;
            }
        }
    }
    Set-Content Env:\$VariableName $VariableValue;
}



Function VerifyEnvironmentVariablePath
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $PathToVerify,
        [parameter(ValueFromRemainingArguments = $True)][Object[]] $IgnoredArguments
    )

    #Get the PATH variable
    Update-SessionEnvironment $False;
    $EnvPath = $Env:PATH;
    Return ($EnvPath.ToLower().Contains($PathToVerify.ToLower()))
}



Function Install-EnvironmentVariablePath
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $PathToInstall,
        [parameter(Mandatory=$False, Position=1)][System.EnvironmentVariableTarget] $PathType = [System.EnvironmentVariableTarget]::User,
        [parameter(ValueFromRemainingArguments = $True)][Object[]] $IgnoredArguments
    )

    #Get the PATH variable
    Update-SessionEnvironment $False;
    $EnvPath = $Env:PATH;
    If (-not ($EnvPath.ToLower().Contains($PathToInstall.ToLower())))
    {
        Logs-Write "PATH environment variable does not have $pathToInstall in it. Adding.";
        $ActualPath = Get-EnvironmentVariable -Name 'Path' -Scope $PathType -PreserveVariables;
        $StatementTerminator = ";";
        #Does the path end in ';'?
        $HasStatementTerminator = $Null -ne $ActualPath -and $ActualPath.EndsWith($StatementTerminator);
        #If the last digit is not ;, then we are adding it
        If (-not $HasStatementTerminator -and $Null -ne $ActualPath)
        {
            $PathToInstall = $StatementTerminator + $PathToInstall;
        }
        If (-not $PathToInstall.EndsWith($StatementTerminator))
        {
            $PathToInstall = $PathToInstall + $StatementTerminator;
        }
        $ActualPath = $ActualPath + $PathToInstall;
        If ($PathType -eq [System.EnvironmentVariableTarget]::Machine)
        {
            If (Test-ProcessAdminRights)
            {
                Set-EnvironmentVariable -Name 'Path' -Value $ActualPath -Scope $PathType;
            }
            Else
            {
                Logs-Write "Run Powershell with Administrative Privilegies for uninstall `'$PathToInstall`' from `'$PathType`' PATH. Could not remove." -ForegroundColor DarkYellow;
            }
        }
        Else
        {
            Set-EnvironmentVariable -Name 'Path' -Value $ActualPath -Scope $PathType;
        }
        #Add it to the local path as well so users will be off and running
        $EnvPSPath = $Env:Path;
        $Env:Path = $EnvPSPath + $StatementTerminator + $PathToInstall;
    }
}



Function Get-UninstallRegistryKey
{
    Param
    (
        [parameter(Mandatory=$True, Position=0, ValueFromPipeline=$True)][ValidateNotNullOrEmpty()][string] $SoftwareName,
        [parameter(ValueFromRemainingArguments = $True)][Object[]] $IgnoredArguments
    )

    If ($Null -eq $SoftwareName -or $SoftwareName -eq '')
    {
        Throw "$SoftwareName cannot be empty for Get-UninstallRegistryKey";
    }
    $ErrorActionPreference = 'Stop';
    $Local_Key       = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*';
    $Machine_Key     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*';
    $Machine_Key6432 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*';

    Logs-Verbose "Retrieving all uninstall registry keys";
    [array]$Keys = Get-ChildItem -Path @($Machine_Key6432, $Machine_Key, $Local_Key) -ErrorAction SilentlyContinue;
    Logs-Debug "Registry uninstall keys on system: $($keys.Count)";
    Logs-Debug "Error handling check: `'Get-ItemProperty`' fails if a registry key is encoded incorrectly.";
    $MaxAttempts = $Keys.Count;
    For ([int]$Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++)
    {
        $Success = $False;
        $KeyPaths = $Keys | Select-Object -ExpandProperty PSPath;
        Try
        {
            [array]$FoundKey = Get-ItemProperty -Path $KeyPaths -ErrorAction Stop | Where-Object { $_.DisplayName -like $SoftwareName };
            $Success = $True;
        }
        Catch
        {
            Logs-Debug "Found bad key.";
            ForEach ($Key In $Keys)
            {
                Try
                {
                    Get-ItemProperty $Key.PsPath > $Null;
                }
                Catch
                {
                    $BadKey = $Key.PsPath;
                }
            }
            Logs-Verbose "Skipping bad key: $BadKey";
            [array]$Keys = $Keys | Where-Object { $BadKey -NotContains $_.PsPath };
        }
        If ($Success)
        {
            Break;
        }
        If ($Attempt -ge 10)
        {
            Logs-Write "Found 10 or more bad registry keys. Run command again with `'--verbose --debug`' for more info." -ForegroundColor DarkYellow;
        }
    }
    If ($Null -eq $FoundKey -or $Foundkey.Count -eq 0)
    {
        Logs-Write "No registry key found based on '$SoftwareName'" -ForegroundColor DarkYellow;
    }
    Logs-Debug "Found $($FoundKey.Count) uninstall registry key(s) with SoftwareName:`'$SoftwareName`'";
    Return $FoundKey;
}


#Update the path from Uninstall Package
function Update-UnInstallPath
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $DisplayName,
        [parameter(Mandatory=$True, Position=1)][ValidateNotNullOrEmpty()][string] $PropertyName,
        [parameter(Mandatory=$True, Position=2)][ValidateNotNullOrEmpty()][string] $OldValue,
        [parameter(Mandatory=$False, Position=3)][string] $NewValue = [string]::Empty
    )

    $DisplayNameRex = [System.String]::Concat($DisplayName, '*');
    [Array]$Keys = Get-UninstallRegistryKey $DisplayNameRex;
    If ($Keys.Count -ge 1)
    {
        For ([int]$i = 0; $i -lt $Keys.Count; $i++)
        {
            Try
            {
                If ((Get-ItemProperty -Path $Keys[$i].PSPath).PSObject.Properties.Name -contains $PropertyName)
                {
                    [PSCustomObject]$Key = Get-ItemProperty -Path $Keys[$i].PSPath -Name $PropertyName;
                    [string]$Value = $Key.$PropertyName.Replace($OldValue, $NewValue);
                    Set-ItemProperty -Path $Keys[$i].PSPath -Name $PropertyName -Value $Value;
                }
            }
            Catch
            {
                #Nothing
            }
        }
    }
}


Function Install-PinnedTaskBarItem
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $TargetFilePath,
        [parameter(ValueFromRemainingArguments = $True)][Object[]]$IgnoredArguments
    )

    Logs-Debug "Running 'Install-PinnedTaskBarItem' with targetFilePath:`'$TargetFilePath`'";
    Try
    {
        If (Test-Path($TargetFilePath))
        {
            $Verb = "Pin To Taskbar";
            $Path = Split-Path $TargetFilePath;
            $Shell = New-Object -Com "Shell.Application";
            $Folder = $Shell.Namespace($Path);
            $Item = $Folder.ParseName((Split-Path $TargetFilePath -Leaf));
            $ItemVerb = $Item.Verbs() | Where-Object { $_.Name.Replace("&",[string]::Empty) -eq $Verb };
            If ($Null -eq $ItemVerb)
            {
                Logs-Write "TaskBar verb not found for $Item. It may have already been pinned.";
            }
            Else
            {
                $ItemVerb.DoIt();
            }
            Logs-Write "`'$TargetFilePath`' has been pinned to the task bar on your desktop.";
        }
        Else
        {
            $ErrorMessage = "`'$TargetFilePath`' does not exist, not able to pin to task bar.";
        }
        If ($ErrorMessage)
        {
            Logs-Write "$ErrorMessage" -ForegroundColor DarkYellow;
        }
    }
    Catch
    {
        Logs-Write "Unable to create pin. Error captured was $($_.Exception.Message)." -ForegroundColor DarkYellow;
    }
}


Function Install-Shortcut
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $ShortcutFilePath,
        [parameter(Mandatory=$True, Position=1)][ValidateNotNullOrEmpty()][string] $TargetPath,
        [parameter(Mandatory=$False, Position=2)][string] $WorkingDirectory,
        [parameter(Mandatory=$False, Position=3)][string] $Arguments,
        [parameter(Mandatory=$False, Position=4)][string] $IconLocation,
        [parameter(Mandatory=$False, Position=5)][string] $Description,
        [parameter(Mandatory=$False, Position=6)][int] $WindowStyle,
        [parameter(Mandatory=$False)][switch] $RunAsAdmin,
        [parameter(Mandatory=$False)][switch] $PinToTaskbar,
        [parameter(ValueFromRemainingArguments = $True)][Object[]]$IgnoredArguments
    )

    If (-not $ShortcutFilePath)
    {
        #Shortcut file path could be null if someone is trying to get special paths for LocalSystem (SYSTEM).
        Logs-Write "Unable to create shortcut. `$ShortcutFilePath can not be null." -ForegroundColor DarkYellow;
        Return;
    }
    $ShortcutDirectory = $([System.IO.Path]::GetDirectoryName($ShortcutFilePath));
    If (-not (Test-Path($ShortcutDirectory)))
    {
        [System.IO.Directory]::CreateDirectory($ShortcutDirectory) | Out-Null;
    }
    If (-not $TargetPath)
    {
      Throw "Install-ChocolateyShortcut - `$targetPath can not be null.";
    }
    If (-not (Test-Path($TargetPath)) -and -not(IsURIWeb($TargetPath)))
    {
        Logs-Write "'$TargetPath' does not exist. If it is not created the shortcut will not be valid." -ForegroundColor DarkYellow;
    }
    If ($IconLocation)
    {
        If (-not (Test-Path($IconLocation)))
        {
            Logs-Write "'$IconLocation' does not exist. A default icon will be used." -ForegroundColor DarkYellow;
        }
    }
    If ($WorkingDirectory)
    {
        If (-not (Test-Path($WorkingDirectory)))
        {
            [System.IO.Directory]::CreateDirectory($WorkingDirectory) | Out-Null;
        }
    }
    Logs-Debug "Creating Shortcut.";
    Try
    {
        $Global:WshShell = New-Object -Com "WScript.Shell";
        $Lnk = $Global:WshShell.CreateShortcut($ShortcutFilePath);
        $Lnk.TargetPath = $TargetPath;
        $Lnk.WorkingDirectory = $WorkingDirectory;
        $Lnk.Arguments = $Arguments;
        If ($IconLocation)
        {
            $Lnk.IconLocation = $IconLocation;
        }
        If ($Description)
        {
            $Lnk.Description = $Description;
        }
        If ($WindowStyle)
        {
            $Lnk.WindowStyle = $WindowStyle;
        }
        $Lnk.Save();
        Logs-Debug "Shortcut created.";
        [System.IO.FileInfo]$Path = $ShortcutFilePath;
        If ($RunAsAdmin)
        {
            #In order to enable the "Run as Admin" checkbox, this code reads the .LNK as a stream
            #  and flips a specific bit while writing a new copy.  It then replaces the original
            #  .LNK with the copy, similar to this example: http://poshcode.org/2513
            $TempFileName = [IO.Path]::GetRandomFileName();
            $TempFile = [IO.FileInfo][IO.Path]::Combine($Path.Directory, $TempFileName);
            $Writer = New-Object System.IO.FileStream $TempFile, ([System.IO.FileMode]::Create);
            $Reader = $Path.OpenRead();
            While ($Reader.Position -lt $Reader.Length)
            {
                $Byte = $Reader.ReadByte();
                If ($Reader.Position -eq 22)
                {
                    $Byte = 34;
                }
                $Writer.WriteByte($Byte);
            }
            $Reader.Close();
            $Writer.Close();
            $Path.Delete();
            Rename-Item -Path $TempFile -NewName $Path.Name | Out-Null;
        }
        If ($PinToTaskbar)
        {
            $PinVerb = (New-Object -com "Shell.Application").Namespace($(Split-Path -Parent $Path.FullName)).ParseName($(Split-Path -Leaf $Path.FullName)).Verbs() | Where-Object {$_.Name -eq 'Pin to Tas&kbar'};
            If ($PinVerb)
            {
                $PinVerb.DoIt();
            }
        }
    }
    Catch
    {
        Logs-Write "Unable to create shortcut. Error captured was $($_.Exception.Message)." -ForegroundColor DarkYellow;
    }
}


Function Start-ProcessInSilentMode
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $CommandToRun,
        [parameter(Mandatory=$False, Position=1)][string] $Parameters = [string]::Empty,
        [parameter(Mandatory=$False, Position=2)][boolean] $ShowOutput = $True
    )

    Logs-Write " >" $CommandToRun $Parameters -ForegroundColor DarkGray;
    # Setting process invocation parameters.
    $Psi = New-Object -TypeName System.Diagnostics.ProcessStartInfo;
	$Psi.CreateNoWindow = $True;
	$Psi.UseShellExecute = $False;
	$Psi.RedirectStandardOutput = $True;
	$Psi.RedirectStandardError = $True;
	$Psi.WorkingDirectory = $Global:PathAppsTemp;
	$Psi.FileName = $CommandToRun;
	If (-not [String]::IsNullOrEmpty($Parameters))
	{
	    $Psi.Arguments = $Parameters;
	}
    $Psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden;
	# Creating process object.
	$Process = New-Object -TypeName System.Diagnostics.Process;
    $Process.EnableRaisingEvents = $True;
	$Process.StartInfo = $Psi;
	# Creating string builders to store stdout and stderr.
	$StdOutBuilder = New-Object -TypeName System.Text.StringBuilder;
	$StdErrBuilder = New-Object -TypeName System.Text.StringBuilder;
	# Adding event handers for stdout and stderr.
	$ScripBlockOut = {
	        If ($Null -ne $EventArgs.Data)
	        {
                Write-Verbose $EventArgs.Data
    	        $Event.MessageData.AppendLine($EventArgs.Data);
	        }
		};
    $ScripBlockError = {
	        If ($Null -ne $EventArgs.Data)
            {
                Write-Error "$($EventArgs.Data)"
            }

		};
	$StdOutEvent = Register-ObjectEvent -InputObject $Process -Action $ScripBlockOut -EventName 'OutputDataReceived' -MessageData $StdOutBuilder;
	$StdErrEvent = Register-ObjectEvent -InputObject $Process -Action $ScripBlockError -EventName 'ErrorDataReceived' -MessageData $StdErrBuilder;
	# Starting process.
	$Process.Start() > $Null;
	$Process.BeginOutputReadLine() > $Null;
	$Process.BeginErrorReadLine() > $Null;
	$Process.WaitForExit() > $Null;
	# Unregistering events to retrieve process output.
	Unregister-Event -SourceIdentifier $StdOutEvent.Name;
	Unregister-Event -SourceIdentifier $StdErrEvent.Name;
	$Result = New-Object -TypeName PSObject -Property ([Ordered]@{
	        "ExeFile"  = $CommandToRun;
		    "Args"     = $Parameters;
		    "ExitCode" = $Process.ExitCode;
		    "StdOut"   = $StdOutBuilder.ToString().Trim();
		    "StdErr"   = $StdErrBuilder.ToString().Trim()
		});
    $ExitCode = $Result.ExitCode;
    $ErrorLevel = $(If ($CommandToRun -eq $Global:RoboCopy) { 7 } Else { 0 });
    If ($Null -ne $Result.StdOut -and $ShowOutput -or $ExitCode -gt $ErrorLevel)
    {
	    Logs-Write $Result.StdOut;
    }
    Logs-Debug $Result.StdOut;
    If ($ExitCode -gt $ErrorLevel)
	{					
        Write-Warning "Exited with status code ($ExitCode)";
        If ($Null -ne $Result.StdErr)
        {
            Logs-Write $Result.StdErr;
        }
	}
    Logs-Debug $Result.StdErr;
    Return $ExitCode;
}


Function UnzipFile
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $FileFullPath,
        [parameter(Mandatory=$True, Position=1)][ValidateNotNullOrEmpty()][string] $Destination,
        [parameter(Mandatory=$False, Position=2)][string] $SpecificFolder,
        [parameter(ValueFromRemainingArguments = $True)][Object[]] $IgnoredArguments
    )

    Logs-Write "Extracting $FileFullPath to $Destination.";
    If ([IntPtr]::Size -ne 4)
    {
        $FileFullPathNoRedirection = $FileFullPath -ireplace ([System.Text.RegularExpressions.Regex]::Escape([Environment]::GetFolderPath('System'))),(Join-Path $Env:SystemRoot 'SysNative');
        $DestinationNoRedirection = $Destination -ireplace ([System.Text.RegularExpressions.Regex]::Escape([Environment]::GetFolderPath('System'))),(Join-Path $Env:SystemRoot 'SysNative');
    }
    Else
    {
        $FileFullPathNoRedirection = $FileFullPath;
        $DestinationNoRedirection = $Destination;
    }
    $Params = "x -aoa -bd -bb1 -o`"$DestinationNoRedirection`" -y `"$FileFullPathNoRedirection`"";
    If ($SpecificFolder)
    {
        $Params += " `"$SpecificFolder`"";
    }    
    $ExitCode = Start-ProcessInSilentMode $Global:SevenZip $Params $False;
    Switch ($ExitCode)
    {
        0
        {
            Break;
        }
        1
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: Some files could not be extracted." -ForegroundColor Red;
        }
        2
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: 7-Zip encountered a fatal error while extracting the files." -ForegroundColor Red;
        }
        7
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: 7-Zip command line error." -ForegroundColor Red;
        }
        8
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: 7-Zip out of memory." -ForegroundColor Red;
        }
        255
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: Extraction cancelled by the user." -ForegroundColor Red;
        }
        default
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: 7-Zip signalled an unknown error (code $ExitCode)." -ForegroundColor Red;
        }
    }
    Return $Destination
}


Function DownloadFile
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string]$FileName,
        [parameter(Mandatory=$True, Position=1)][ValidateNotNullOrEmpty()][string]$Url,
        [parameter(Mandatory=$False, Position=2)][HashTable]$Headers = @{}
    )

    $OutputFilename = Join-Path $Global:PathAppsTemp $Filename;
    If (-not (ValidatePaths $OutputFilename) -and -not (ExistsPaths $OutputFilename))
    {
        Logs-Write "Downloading File in $OutputFilename.";
        Logs-Write "Downloading File from $Url.";
        Try
        {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True };
            [Net.ServicePointManager]::SecurityProtocol =  [System.Security.Authentication.SslProtocols] "tls, tls11, tls12";
            $Client = New-Object Net.WebClient;
            If ($Headers.Count -gt 0)
            {
                ForEach($Item In $Headers.GetEnumerator())
                {
                    $Client.Headers.Add($Item.Key, $Item.Value);
                }
            }
            $Creds = [System.Net.CredentialCache]::DefaultCredentials;
            If ($Null -ne $Creds)
            {
                $Client.Credentials = $Creds;
            }
            $Client.DownloadFile($Url, $OutputFilename);
        }
        Catch
        {
            Logs-Write "Unable to download file. Error captured was $($_.Exception.Message)." -ForegroundColor DarkYellow;
            $OutputFilename = [string]::Empty;
        }
        Finally
        {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $Null;
        }
    }
    Else
    {
        Logs-Write "File $OutputFilename already exist. Discard download.";
    }
    Return $OutputFilename
}



Function Ping-Machine
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string]$Computer,
        [parameter(Mandatory=$False, Position=1)][int]$Count = 4
    )
    
    [System.Collections.ArrayList]$Response = New-Object System.Collections.ArrayList;
    Logs-Verbose "Beginning Ping monitoring of $Computer for $Count tries:";
    While ($Count -gt 0)
    {
        $Ping = Get-WmiObject Win32_PingStatus -Filter "Address = '$Computer' and TimeOut = 100 and BufferSize = 16" |
                Select-Object @{Label="TimeStamp"; Expression={Get-Date}},
                              @{Label="Source"; Expression={ $_.__Server }},
                              @{Label="Destination"; Expression={ $_.Address }},
                              IPv4Address,
                              @{Label="Status"; Expression={ If ($_.StatusCode -ne 0) {"Failed"} Else {""}}},
                              ResponseTime;
        $Result = $Ping | Select-Object TimeStamp,Source,Destination,IPv4Address,Status,ResponseTime;
        $Response.Add($Result) | Out-Null;
        Write-verbose ($Ping | Select-Object TimeStamp,Source,Destination,IPv4Address,Status,ResponseTime | Format-Table -AutoSize | Out-String);
        $Count --;
    }
    Return $Response;
}



Function CalculateResponseTime
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][System.Collections.ArrayList]$Pings
    )

    If ($Pings.Count -gt 0)
    {
        $ResponseTime = 0;
        ForEach ($Ping In $Pings)
        {
            If ($Null -ne $Ping.ResponseTime)
            {
                $ResponseTime = $ResponseTime + $Ping.ResponseTime.ToInt32($Null);
            }
            Else
            {
                $ResponseTime = $ResponseTime + 99;
            }
        }
        $ResponseTime = $ResponseTime / $Pings.Count;
    }
    Else
    {
        $ResponseTime = 99;
    }
    Return $ResponseTime;
}



Function Install-AndroidSdkPackage
{
    Param
    (
        [parameter(Mandatory=$True, Position=0)][String]$AndroidSdkDir,
        [parameter(Mandatory=$True, Position=1)][String]$PackageName,
        [parameter(Mandatory=$True, Position=2)][String]$PackageSource
    )

    ValidatePaths $AndroidSdkDir;
    If (ExistsPaths $AndroidSdkDir)
    {
        $PackageFileName =  [System.IO.Path]::GetFileName($PackageSource);
        Write-Host "`r`n";
        Logs-Write "Installing Android SDK ($PackageName).";
        $SdkFile = DownloadFile $PackageFileName $PackageSource;
        If (-not ([string]::IsNullOrEmpty($SdkFile)))
        {
            $SdkPackageDir = Join-Path $AndroidSdkDir $PackageName.Replace(';','\');
            If (PathIsEmpty $SdkPackageDir)
            {
                UnzipFile $SdkFile $SdkPackageDir | Out-Null;
                $PropertiesFile = Get-ChildItem -Path $SdkPackageDir -Recurse -Include "source.properties" -Force -ErrorAction SilentlyContinue;
                If ($Null -ne $PropertiesFile)
                {
                    $OldPath = Split-Path $PropertiesFile.FullName;
                    $NewPath = $SdkPackageDir;
                    $ContentFile = Get-Content $PropertiesFile.FullName | Where-Object { $_.Contains("Pkg.Path") -or $_.Contains("Extra.Path") -or $_.Contains("Extra.VendorId") };
                    If ($Null -ne $ContentFile)
                    {
                        ForEach($Line In $ContentFile)
                        {
                            If ($Line.Contains("Pkg.Path"))
                            {
                                $NewPath = ($Line.Split("=")[1]).Replace(";","\");
                                $NewPath = Join-Path $AndroidSdkDir $NewPath;
                                Break;
                            }
                            ElseIf ($Line.Contains("Extra.Path"))
                            {
                                $NewPath = ($Line.Split("=")[1]).Replace(";","\");
                                $VendorId = "google";
                                ForEach($OtherLine In $ContentFile)
                                {
                                    If ($OtherLine.Contains("Extra.VendorId"))
                                    {
                                        $VendorId = ($OtherLine.Split("=")[1]);
                                        Break;
                                    }
                                }
                                $NewPath = "extras\" + (Join-Path $VendorId $NewPath);
                                $NewPath = Join-Path $AndroidSdkDir $NewPath;
                                Break;
                            }
                            ElseIf ($Line.Contains("Addon.Path"))
                            {
                                $NewPath = ($Line.Split("=")[1]).Replace(";","\");
                                $VendorId = "google";
                                ForEach($OtherLine In $ContentFile)
                                {
                                    If ($OtherLine.Contains("Addon.VendorId"))
                                    {
                                        $VendorId = ($OtherLine.Split("=")[1]);
                                        Break;
                                    }
                                }
                                $NewPath = Join-Path $VendorId $NewPath;
                                $NewPath = Join-Path $AndroidSdkDir $NewPath;
                                Break;
                            }
                        }
                    }
                    If ($OldPath -ne $NewPath)
                    {
                        Logs-Write "Moving files to the new destination '$NewPath'.";
                        Start-ProcessInSilentMode $Global:RoboCopy "`"$OldPath`" `"$NewPath`" /e /move /np" $False | Out-Null;
                    }
                }
            }
            Else
            {
                Logs-Write "Android SDK Package '$PackageName' already installed.";
            }
        }
        Else
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: An error occurred when downloading Android SDK. The package '$PackageName' in the path $PackageSource." -ForegroundColor Red;
        }
    }
    Else
    {
        Write-Host "`r`n";
        Logs-Write "ERROR: The Android SDK directory not was found." -ForegroundColor Red;
    }
}
#########################
# End General Functions #
#########################



$Error.Clear();
Set-Variable -Option ReadOnly My @{
	File = Get-ChildItem $MyInvocation.MyCommand.Path
	Contents = $MyInvocation.MyCommand.ScriptContents
	Log = @{}
};

If ($My.Contents -Match '^\s*\<#([\s\S]*?)#\>')
{ $My.Help = $Matches[1].Trim(); }
[RegEx]::Matches($My.Help, '(^|[\r\n])\s*\.(.+)\s*[\r\n]|$') | ForEach-Object {
    If ($Caption)
    { $My.$Caption = $My.Help.SubString($Start, $_.Index - $Start); }
	$Caption = $_.Groups[2].ToString().Trim();
	$Start = $_.Index + $_.Length;
};
$My.Title = $My.Synopsis.Trim().Split("`r`n")[0].Trim();
$My.Id = (Get-Culture).TextInfo.ToTitleCase($My.Title) -Replace "\W", "";
$My.Notes -Split("\r\n") | ForEach-Object { $Note = $_ -Split(":", 2); If ($Note.Count -gt 1) { $My[$Note[0].Trim()] = $Note[1].Trim() } };
$My.Path = $My.File.FullName;
$My.Folder = $My.File.DirectoryName;
$My.Name = $My.File.BaseName;
$My.Arguments = (($MyInvocation.Line + " ") -Replace ("^.*\\" + $My.File.Name.Replace(".", "\.") + "['"" ]"), "").Trim();
$Script:Debug = $MyInvocation.BoundParameters.Debug.IsPresent;
$Script:Verbose = $MyInvocation.BoundParameters.Verbose.IsPresent;
$MyInvocation.MyCommand.Parameters.Keys | Where-Object { Test-Path Variable:"$_" } | ForEach-Object {
	$Value = Get-Variable -ValueOnly $_;
    If ($Value -is [IO.FileInfo])
    { Set-Variable $_ -Value ([Environment]::ExpandEnvironmentVariables($Value)); }
};


###############################################
# Validating pre-requisites for installation. #
###############################################
Log-File .\InstallApssXenial.log
Write-Host "`r`n`r`n";
Logs-Write "###############################################";
Logs-Write "# Validating pre-requisites for installation. #";
Logs-Write "###############################################";
If (-not (Test-ProcessAdminRights))
{
    Write-Host "`r`n";
    Logs-Write "ERROR: Run Powershell with Administrative Privilegies for install applications." -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
If ([System.IntPtr]::Size -eq 4)
{
    Write-Host "`r`n";
    Logs-Write "ERROR: Your OS is 32bits. This script only Run in OS 64bits version." -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
IF ([System.Version]$PsVersionTable.PSVersion -lt [System.Version]"5.0.0.0")
{
    Write-Host "`r`n";
    Logs-Write "ERROR: Your PowerShell version is less that 5.0.0.0. This script only Run over PowerShell versions grant or equals to 5.0.0.0." -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
$PathInstall = $PathInstall.Trim();
ValidatePaths $PathInstall;
If ($PathInstall.Contains(' '))
{
    Write-Host "`r`n";
    Logs-Write "ERROR: The Path to install the applications contains spaces. `'$PathInstall`'" -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
$PathRepository = $PathRepository.Trim();
ValidatePaths $PathRepository;
If ($PathRepository.Contains(' '))
{
    Write-Host "`r`n";
    Logs-Write "ERROR: The Path to clone the repositories contains spaces. `'$PathRepository`'" -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
If ($PathInstall.ToLower() -eq $PathRepository.ToLower())
{
    Write-Host "`r`n";
    Logs-Write "ERROR: The paths to install the applications and clones the repositories are equals. `'$PathInstall`'" -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
If ($UseSharedFolder)
{
    $PingAtalanta = Ping-Machine "atalanta" 4;
    If ((CalculateResponseTime $PingAtalanta) -lt 5)
    {
        $RepositoryLocal = '\\atalanta\Temporal\EMantillaS\Xenial';
        Logs-Write "Using '$RepositoryLocal' to download setup files.";
    }
    Else
    {
        $PingAtlas = Ping-Machine "atlas" 4;
        If ((CalculateResponseTime $PingAtlas) -lt 5)
        {
            $RepositoryLocal = '\\atlas\Temporal\MAguilar\Xenial';
            Logs-Write "Using '$RepositoryLocal' to download setup files.";            
        }
        Else
        {
            Logs-Write "The Shared Temporary Folders not are accessible. Will be Download setup files directly from Internet." -ForegroundColor DarkYellow;
            $UseSharedFolder = $False;
        }
    }
}
$Global:PathAppsTemp = Join-Path $PathInstall 'Temp';
$Count = 0;
Do
{
    $Count++;
    $Global:SevenZip = Get-UninstallRegistryKey '*7-Zip*' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
                        ForEach-Object {
                            If ($Null -ne $_ -and $Null -ne $_.UninstallString)
                            {
                                $InstalledId = Join-Path (Split-Path -Parent $_.UninstallString) '7z.exe';
                                If (([System.IO.File]::Exists($InstalledId)))
                                {
                                    return $InstalledId;
                                }
                            }
                        } | Select-Object -Unique;
    If ($Null -eq $Global:SevenZip)
    {
        If ($UseSharedFolder)
        {
            $UrlFile = $RepositoryLocal + '\7z1801-x64.exe';
        }
        Else
        {
            $UrlFile = 'https://www.7-zip.org/a/7z1801-x64.exe';
        }
        $ZipFile = DownloadFile '7z1801-x64.exe' $UrlFile;
        If (-not ([string]::IsNullOrEmpty($ZipFile)))
        {
            Write-Host "`r`n";
            Logs-Write "Installing 7-Zip.";
            $InstallOptions = '/S';
            Start-ProcessInSilentMode $ZipFile $InstallOptions | Out-Null;
        }
    }
} Until ($Null -ne $Global:SevenZip -or $Count -eq 2)
If ($Null -eq $Global:SevenZip)
{
    Write-Host "`r`n";
    Logs-Write "ERROR: 7Zip not found in $Env:ProgramFiles or ${Env:ProgramFiles(x86)}." -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
Logs-Write "7Zip found at `'$Global:SevenZip`'."
$Global:Msi = (Get-Command "msiexec.exe" -ErrorAction SilentlyContinue).Source;
If ([string]::IsNullOrEmpty($Global:Msi))
{
    Write-Host "`r`n";
    Logs-Write "ERROR: Microsoft Installer not found in $Env:SystemRoot\System32." -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
Logs-Write "Microsoft Installer found at `'$Global:Msi`'."
$Global:RoboCopy = (Get-Command "robocopy.exe" -ErrorAction SilentlyContinue).Source;
If ([string]::IsNullOrEmpty($Global:RoboCopy))
{
    Write-Host "`r`n";
    Logs-Write "ERROR: Robocopy.exe not found in $Env:SystemRoot\System32." -ForegroundColor Red -BackgroundColor Black;
    Logs-End -Exit -ErrorLevel -12345;
}
PrepareDirectory $PathInstall;
PrepareDirectory $Global:PathAppsTemp;



####################################
# Processing installation of JDK8. #
####################################
Write-Host "`r`n`r`n";
Logs-Write "####################################";
Logs-Write "# Processing installation of JDK8. #";
Logs-Write "####################################";
$AppName = "Java SE Development Kit 8";
If (-not (IsAppInstalled $AppName))
{
    $JavaDir = Join-Path $PathInstall 'Java8';
    $JavaBin = Join-Path $JavaDir 'bin';
    If ($UseSharedFolder)
    {
        $Headers = @{ };
        $UrlFile = $RepositoryLocal + '\jdk-8u162-windows-x64.exe';
    }
    Else
    {
        $Headers = @{'Cookie' = 'gpw_e24=http://www.oracle.com; oraclelicense=accept-securebackup-cookie'};
        $UrlFile = 'http://download.oracle.com/otn-pub/java/jdk/8u162-b12/0da788060d494f5095bf8624735fa2f1/jdk-8u162-windows-x64.exe';
    }
    $JdkFile = DownloadFile 'jdk-8u162-windows-x64.exe' $UrlFile $Headers;
    If (-not ([string]::IsNullOrEmpty($JdkFile)))
    {
        Write-Host "`r`n";
        Logs-Write "Installing JDK8.";
        $InstallOptions = '/s STATIC=1 ADDLOCAL="ToolsFeature,SourceFeature" INSTALLDIR="' + $JavaDir + '"';
        Start-ProcessInSilentMode $JdkFile $InstallOptions | Out-Null;
        Logs-Write "Updating Environment Variables PATH, JAVA_HOME and CLASSPATH.";
        Install-EnvironmentVariablePath $JavaBin 'Machine';
        If ($Null -eq [Environment]::GetEnvironmentVariable('CLASSPATH','Machine'))
        {
            Install-EnvironmentVariable 'CLASSPATH' '.;' 'Machine';
        }
        Install-EnvironmentVariable 'JAVA_HOME' $JavaDir 'Machine';
    }
    Else
    {
        Write-Host "`r`n";
        Logs-Write "ERROR: An error occurred when downloading JDK8." -ForegroundColor Red -BackgroundColor Black;
        Logs-End -Exit -ErrorLevel -12345;
    }
}
Else
{
    Write-Host "`r`n";
    Logs-Write "JDK8 is already installed.";
    Write-Host "`r`n";
    Logs-Write "Validating the installation.";
    $OldPath = (Get-Command "java.exe" -ErrorAction SilentlyContinue).Source;
    If ($Null -eq $OldPath)
    {
        $Key = Get-UninstallRegistryKey "$AppName*" -WarningAction SilentlyContinue;
        If ($Null -ne $Key -and $Null -ne $Key.InstallLocation -and [System.IO.Directory]::Exists($Key.InstallLocation))
        {
            $OldPath = Join-Path $Key.InstallLocation "bin";
            Logs-Write "Java.exe found in '$OldPath'";
            If (-not (VerifyEnvironmentVariablePath $OldPath))
            {
                Install-EnvironmentVariablePath $OldPath 'Machine';
            }
            Else
            {
                Logs-Write "PATH environment variable already contains the value '$OldPath'";
            }
        }
        Else
        {
            Write-Warning "Java.exe not found in the system. It is not possible to configure the PATH, JAVA_HOME and CLASSPATH environments variables";
        }
    }
    Else
    {
        Logs-Write "PATH environment variable already contains the value '$OldPath'";
    }
    $Variable = [Environment]::GetEnvironmentVariable('JAVA_HOME','Machine');
    If ($Null -eq $Variable)
    {
        Write-Warning "'JAVA_HOME' not is set in the environments variables."
        If ($Null -ne $OldPath)
        {
            $NewPath = Split-Path -Parent $OldPath;
            Install-EnvironmentVariable 'JAVA_HOME' $NewPath 'Machine';
        }
    }
    Else
    {
        Logs-Write "JAVA_HOME environment variable is set with the value '$Variable'";
        If (-not ([System.IO.Directory]::Exists($Variable)))
        {
            Write-Host "`r`n";
            Logs-Write "ERROR: 'JAVA_HOME' is bad set in the environments variables." -ForegroundColor Red -BackgroundColor Black;
            Logs-End -Exit -ErrorLevel -12345;
        }
    }
    $Variable = [Environment]::GetEnvironmentVariable('CLASSPATH','Machine');
    If ($Null -eq $Variable)
    {
        Write-Warning "'CLASSPATH' not is set in the environments variables."
        Install-EnvironmentVariable 'CLASSPATH' '.;' 'Machine';
    }
    Else
    {
        Logs-Write "CLASSPATH environment variable is set with the value '$Variable'";
    }
}



###########################################
# Processing installation of Android SDK. #
###########################################
Write-Host "`r`n`r`n";
Logs-Write "###########################################";
Logs-Write "# Processing installation of Android SDK. #";
Logs-Write "###########################################";
$AlreadyInstall = $False;
$NewPath = [Environment]::GetEnvironmentVariable('ANDROID_HOME','Machine');
If ($Null -ne $NewPath)
{   
    If (-not (PathIsEmpty($NewPath)))
    {
        $AlreadyInstall = $True;
        Write-Host "`r`n";
        Logs-Write "Android SDK is already installed in $NewPath.";
    }
}
If (-not $AlreadyInstall)
{
    $AndroidDir = Join-Path $PathInstall 'Android';
    PrepareDirectory $AndroidDir;
    $AndroidSdkDir = Join-Path $AndroidDir 'Sdk';
    PrepareDirectory $AndroidSdkDir;
    If(PathIsEmpty($AndroidSdkDir))
    {
        Write-Host "`r`n";
        Logs-Write "Preparing User Android Directory.";
        $NewPath = Join-Path $Env:UserProfile '.android';
        PrepareDirectory $NewPath;
        $NewPath = Join-Path $NewPath 'repositories.cfg';
        If (-not [System.IO.File]::Exists($NewPath))
        {
            New-Item -Path $NewPath -ItemType File -Force | Out-Null;
        }

        If (ExistsPaths(Join-Path $AndroidSdkDir 'tools\bin\sdkmanager.bat'))
        {
            Write-Host "`r`n";
            Logs-Write "Installing additional Android SDK packages.";
            # Using for Updates
            #   https://dl.google.com/android/repository/repository2-1.xml
            #   https://dl.google.com/android/repository/extras/intel/addon2-1.xml
            #   https://dl.google.com/android/repository/addon2-1.xml
            #   https://dl.google.com/android/repository/sys-img/google_apis/sys-img2-1.xml
            $TextFile = ("patcher;v4|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\3534162-studio.sdk-patcher.zip.bak'; } Else { 'https://dl.google.com/android/repository/3534162-studio.sdk-patcher.zip.bak'; })),
                        ("platform-tools|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\platform-tools-latest-windows.zip'; } Else { 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'; })),
                        ("extras;intel;Hardware_Accelerated_Execution_Manager|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\haxm-windows_r6_2_1.zip'; } Else { 'https://dl.google.com/android/repository/extras/intel/haxm-windows_r6_2_1.zip'; })),
                        ("emulator|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\emulator-windows-4623001.zip'; } Else { 'https://dl.google.com/android/repository/emulator-windows-4623001.zip'; })),
                        ("tools|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\sdk-tools-windows-4333796'; } Else { 'https://dl.google.com/android/repository/sdk-tools-windows-4333796.zip'; })),
                        ("platforms;android-25|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\platform-25_r03.zip'; } Else { 'https://dl.google.com/android/repository/platform-25_r03.zip'; })),
                        ("platforms;android-26|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\platform-26_r02.zip'; } Else { 'https://dl.google.com/android/repository/platform-26_r02.zip'; })),
                        ("platforms;android-27|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\platform-27_r01.zip'; } Else { 'https://dl.google.com/android/repository/platform-27_r01.zip'; })),
                        ("build-tools;25.0.3|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\build-tools_r25.0.3-windows.zip'; } Else { 'https://dl.google.com/android/repository/build-tools_r25.0.3-windows.zip'; })),
                        ("build-tools;26.0.3|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\build-tools_r26.0.3-windows.zip'; } Else { 'https://dl.google.com/android/repository/build-tools_r26.0.3-windows.zip'; })),
                        ("build-tools;27.0.3|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\build-tools_r27.0.3-windows.zip'; } Else { 'https://dl.google.com/android/repository/build-tools_r27.0.3-windows.zip'; })),
                        ("docs|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\docs-24_r01.zip'; } Else { 'https://dl.google.com/android/repository/docs-24_r01.zip'; })),
                        ("add-ons;addon-google_apis-google-24|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\google_apis-24_r1.zip'; } Else { 'https://dl.google.com/android/repository/google_apis-24_r1.zip'; })),
                        ("extras;google;google_play_services|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\google_play_services_3265130_r12.zip'; } Else { 'https://dl.google.com/android/repository/google_play_services_3265130_r12.zip'; })),
                        ("extras;google;simulators|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\simulator_r01.zip'; } Else { 'https://dl.google.com/android/repository/simulator_r01.zip'; })),
                        ("extras;google;usb_driver|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\usb_driver_r11-windows.zip'; } Else { 'https://dl.google.com/android/repository/usb_driver_r11-windows.zip'; })),
                        ("extras;google;webdriver|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\webdriver_r02.zip'; } Else { 'https://dl.google.com/android/repository/webdriver_r02.zip'; })),
                        ("extras;google;instantapps|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\aiasdk-1.1.0.zip'; } Else { 'https://dl.google.com/android/repository/aiasdk-1.1.0.zip'; })),
                        ("extras;android;m2repository|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\android_m2repository_r47.zip'; } Else { 'https://dl.google.com/android/repository/android_m2repository_r47.zip'; })),
                        ("extras;google;m2repository|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\google_m2repository_gms_v11_3_rc05_wear_2_0_5.zip'; } Else { 'https://dl.google.com/android/repository/google_m2repository_gms_v11_3_rc05_wear_2_0_5.zip'; })),
                        ("system-images;android-25;google_apis;x86|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\x86_64-25_r12.zip'; } Else { 'https://dl.google.com/android/repository/sys-img/google_apis/x86_64-25_r12.zip'; })),
                        ("system-images;android-26;google_apis;x86|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\x86-26_r09.zip'; } Else { 'https://dl.google.com/android/repository/sys-img/google_apis/x86-26_r09.zip'; })),
                        ("system-images;android-27;google_apis;x86|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\x86-27_r05.zip'; } Else { 'https://dl.google.com/android/repository/sys-img/google_apis/x86-27_r05.zip'; })),
                        ("sources;android-27|" + $(If ($UseSharedFolder) { $RepositoryLocal + '\sources-27_r01.zip'; } Else { 'https://dl.google.com/android/repository/sources-27_r01.zip'; }))
            $Command = Join-Path $AndroidSdkDir 'tools\bin\sdkmanager.bat';
            ForEach($Package In $TextFile)
            {
                Install-AndroidPackage $Package.Split('|')[0] $Package.Split('|')[1]
            }
            $InstallOptions = '--update';
            Start-ProcessInSilentMode $Command $InstallOptions $False | Out-Null;
        }


        #Logs-Write "Updating Environment Variables PATH and ANDROID_HOME.";
        #Install-EnvironmentVariablePath $NewPath 'Machine';
        #$NewPath = Join-Path $AndroidSdkDir 'tools\bin';
        #Install-EnvironmentVariablePath $NewPath 'Machine';
        #Install-EnvironmentVariable 'ANDROID_HOME' $AndroidSdkDir 'Machine';
        #$NewPath = Join-Path $AndroidSdkDir 'platform-tools';
        #If (ExistsPaths $NewPath)
        #{
        #    Logs-Write "Updating Environment Variable PATH.";
        #    Install-EnvironmentVariablePath $NewPath 'Machine';
        #}

        #$InstallOptions = ' --licenses';
        #Write-Host "`r`n";
        #Logs-Write "Accepting Android licenses.";
        #$Command = 'echo y y y y y y y | ' + (Join-Path $AndroidSdkDir 'tools\bin\sdkmanager.bat') + $InstallOptions;
        #Logs-Write " >" $Command -ForegroundColor DarkGray;
        #Invoke-Expression $Command;
        #Start-Sleep -S 2;

    }
}



##############################################
# Processing installation of Android Studio. #
##############################################
Write-Host "`r`n`r`n";
Logs-Write "##############################################";
Logs-Write "# Processing installation of Android Studio. #";
Logs-Write "##############################################";
$AppName = "Android Studio";
If (-not (IsAppInstalled $AppName))
{
    $AndroidStudioDir = Join-Path $PathInstall 'Android';
    PrepareDirectory $AndroidStudioDir;
    If ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\android-studio-ide-173.4697961-windows.zip';
    }
    Else
    {
        $UrlFile = 'https://dl.google.com/dl/android/studio/ide-zips/3.1.1.0/android-studio-ide-173.4697961-windows.zip';
    }
    $AndroidFile = DownloadFile 'android-studio-ide-173.4697961-windows.zip' $UrlFile;
    If (-not ([string]::IsNullOrEmpty($AndroidFile)))
    {
        Write-Host "`r`n";
        Logs-Write "Installing Android Studio.";
        UnzipFile $AndroidFile $AndroidStudioDir | Out-Null;
        $OldPath = Join-Path $AndroidStudioDir 'android-studio';
        $AndroidStudioDir = Join-Path $AndroidStudioDir 'Studio';
        If (-not (ExistsPaths $AndroidStudioDir))
        {
            Write-Host "`r`n";
            Logs-Write "Configurating Android Studio.";
            Rename-Item -NewName $AndroidStudioDir -Path $OldPath -Force | Out-Null;
            $NewPath = Join-Path $AndroidStudioDir 'bin';
            $IconPath = $NewPath + '\studio.ico';
            $StudioExe = $NewPath + '\studio64.exe';
            $DesktopPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Android Studio.lnk";
            Install-Shortcut -ShortcutFilePath $DesktopPath -TargetPath $StudioExe -IconLocation $IconPath;
            $Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Android Studio';
            New-Item -Path $Key | Out-Null;
            New-ItemProperty -Path $Key -Name 'DisplayIcon' -PropertyType String -Value $StudioExe | Out-Null;
            New-ItemProperty -Path $Key -Name 'DisplayName' -PropertyType String -Value 'Android Studio' | Out-Null;
            New-ItemProperty -Path $Key -Name 'DisplayVersion' -PropertyType String -Value '1.0' | Out-Null;
            New-ItemProperty -Path $Key -Name 'NoModify' -PropertyType DWord -Value 1 | Out-Null;
            New-ItemProperty -Path $Key -Name 'NoRepair' -PropertyType DWord -Value 1 | Out-Null;
            New-ItemProperty -Path $Key -Name 'Publisher' -PropertyType String -Value 'Google Inc.' | Out-Null;
            New-ItemProperty -Path $Key -Name 'UninstallString' -PropertyType String -Value (Join-Path $AndroidStudioDir 'uninstall.exe') | Out-Null;
            New-ItemProperty -Path $Key -Name 'URLInfoAbout' -PropertyType String -Value 'http://developer.android.com' | Out-Null;
        }
    }
    Else
    {
        Write-Host "`r`n";
        Logs-Write "ERROR: An error occurred when downloading Android Studio." -ForegroundColor Red -BackgroundColor Black;
    }
}
Else
{
    Write-Host "`r`n";
    Logs-Write "Android Studio is already installed.";
}



# ######################################
# # Processing installation of NodeJs. #
# ######################################
# Write-Host "`r`n`r`n";
# Logs-Write "######################################";
# Logs-Write "# Processing installation of NodeJs. #";
# Logs-Write "######################################";
# $Key = Get-UninstallRegistryKey 'Node.js*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $NodeJsDir = Join-Path $PathInstall 'NodeJs';
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\node-v7.0.0-x64.msi';
#     }
#     Else
#     {
#         $UrlFile = 'https://nodejs.org/dist/v7.0.0/node-v7.0.0-x64.msi';
#     }
#     $NodeJsFile = DownloadFile 'node-v7.0.0-x64.msi' $UrlFile;
#     $InstallOptions = '/i "' + $NodeJsFile + '" INSTALLDIR="' + $NodeJsDir + '" /quiet /qn /norestart /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-NodeJs.log') + '"';
#     If (-not ([string]::IsNullOrEmpty($NodeJsFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing NodeJs.";
#         Start-ProcessInSilentMode $Global:Msi $InstallOptions | Out-Null;
#         Update-SessionEnvironment;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing the NodeJs." -ForegroundColor Red -BackgroundColor Black;
#         Logs-End -Exit -ErrorLevel -12345;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "NodeJs is already installed.";
# }



# ###################################
# # Processing installation of Git. #
# ###################################
# Write-Host "`r`n`r`n";
# Logs-Write "###################################";
# Logs-Write "# Processing installation of Git. #";
# Logs-Write "###################################";
# $Key = Get-UninstallRegistryKey 'Git version*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $GitDir = Join-Path $PathInstall 'Git';
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\Git-2.16.1.4-64-bit.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://github.com/git-for-windows/git/releases/download/v2.16.1.windows.4/Git-2.16.1.4-64-bit.exe';
#     }
#     $GitFile = DownloadFile 'Git-2.16.1.4-64-bit.exe' $UrlFile;
#     $InstallOptions = '/verysilent /suppressmsgboxes /norestart /nocancel /sp- /closeapplications /restartapplications /components="icons,assoc,assoc_sh,ext,ext\shellhere,ext\guihere,icons\quicklaunch" /DIR="' + $GitDir + '" /LOG="' + (Join-Path $Global:PathAppsTemp '\Install-Git.log') + '"';
#     If (-not ([string]::IsNullOrEmpty($GitFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing Git.";
#         Start-ProcessInSilentMode $GitFile $InstallOptions | Out-Null;
#         Update-SessionEnvironment;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Git." -ForegroundColor Red -BackgroundColor Black;
#         Logs-End -Exit -ErrorLevel -12345;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Git is already installed.";
# }



# ##########################################
# # Processing installation of SourceTree. #
# ##########################################
# Write-Host "`r`n`r`n";
# Logs-Write "##########################################";
# Logs-Write "# Processing installation of SourceTree. #";
# Logs-Write "##########################################";
# $Key = Get-UninstallRegistryKey 'SourceTree*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\SourceTreeSetup-2.4.7.0.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://downloads.atlassian.com/software/sourcetree/windows/ga/SourceTreeSetup-2.4.7.0.exe';
#     }
#     $SourceTreeFile = DownloadFile 'SourceTreeSetup-2.4.7.0.exe' $UrlFile;
#     $InstallOptions = '/passive';
#     If (-not ([string]::IsNullOrEmpty($SourceTreeFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing SourceTree.";
#         Start-ProcessInSilentMode $SourceTreeFile $InstallOptions | Out-Null;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing SourceTree." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "SourceTree is already installed.";
# }



# #########################################################################
# # Processing installation of Microsoft Visual C++ Redistributable 2013. #
# #########################################################################
# Write-Host "`r`n`r`n";
# Logs-Write "#########################################################################";
# Logs-Write "# Processing installation of Microsoft Visual C++ Redistributable 2013. #";
# Logs-Write "#########################################################################";
# $Key = Get-UninstallRegistryKey 'Microsoft Visual C++ 2013 Redistributable*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\vcredist_x64.exe';
#     }
#     Else
#     {
#         $UrlFile = 'http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe';
#     }
#     $VCFile = DownloadFile 'vcredist_x64.exe' $UrlFile;
#     $InstallOptions = '/install /quiet /norestart /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-VCRedist.log') + '"';
#     If (-not ([string]::IsNullOrEmpty($VCFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing Microsoft Visual C++ Redistributable 2013.";
#         Start-ProcessInSilentMode $VCFile $InstallOptions | Out-Null;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Microsoft Visual C++ Redistributable 2013." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Microsoft Visual C++ Redistributable 2013 is already installed.";
# }



# #######################################
# # Processing installation of Python3. #
# #######################################
# Write-Host "`r`n`r`n";
# Logs-Write "#######################################";
# Logs-Write "# Processing installation of Python3. #";
# Logs-Write "#######################################";
# $Key = Get-UninstallRegistryKey 'Python 3.5.4 (64-bit)*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $PythonDir = Join-Path $PathInstall 'Python3';
#     PrepareDirectory $PythonDir;
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\python-3.5.4-amd64.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://www.python.org/ftp/python/3.5.4/python-3.5.4-amd64.exe';
#     }
#     $PythonFile = DownloadFile 'python-3.5.4-amd64.exe' $UrlFile;
#     $InstallOptions = '/quiet InstallAllUsers=0 PrependPath=1 TargetDir="' + $PythonDir + '"';
#     If (-not ([string]::IsNullOrEmpty($PythonFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing Python3.";
#         Start-ProcessInSilentMode $PythonFile $InstallOptions | Out-Null;
#         Update-SessionEnvironment;
#         If (ExistsPaths $PythonDir)
#         {
#             Logs-Write "Updating Environment Variable PATH.";
#             Install-EnvironmentVariablePath $PythonDir 'Machine';
#             $NewPath = Join-Path $PythonDir 'Scripts';
#             Install-EnvironmentVariablePath $NewPath 'Machine';
#             Write-Host "`r`n";
#             Logs-Write "Installing Pip.";
#             If ($UseSharedFolder)
#             {
#                 $UrlFile = $RepositoryLocal + '\get-pip.py';
#             }
#             Else
#             {
#                 $UrlFile = 'https://bootstrap.pypa.io/get-pip.py';
#             }
#             $PipFile = DownloadFile 'get-pip.py' $UrlFile;
#             If (-not ([string]::IsNullOrEmpty($PipFile)))
#             {
#                 Logs-Write " > python $PipFile" -ForegroundColor DarkGray;
#                 Invoke-Expression "python $PipFile";
#                 Logs-Write " > python -m pip install -U pip" -ForegroundColor DarkGray;
#                 Invoke-Expression "python -m pip install -U pip";
#             }
#             Else
#             {
#                 Write-Host "`r`n";
#                 Logs-Write "ERROR: An error occurred when installing Pip." -ForegroundColor Red -BackgroundColor Black;
#                 Logs-End -Exit -ErrorLevel -12345;
#             }
#         }
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Python3." -ForegroundColor Red -BackgroundColor Black;
#         Logs-End -Exit -ErrorLevel -12345;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Python is already installed.";
# }



# ##################################################
# # Processing installation of Visual Studio Code. #
# ##################################################
# Write-Host "`r`n`r`n";
# Logs-Write "##################################################";
# Logs-Write "# Processing installation of Visual Studio Code. #";
# Logs-Write "##################################################";
# $Key = Get-UninstallRegistryKey 'Microsoft Visual Studio Code*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $VSCodeDir = Join-Path $PathInstall 'VSCode';
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\VSCodeSetup-x64-1.20.0.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://az764295.vo.msecnd.net/stable/c63189deaa8e620f650cc28792b8f5f3363f2c5b/VSCodeSetup-x64-1.20.0.exe';
#     }
#     $VSCodeFile = DownloadFile 'VSCodeSetup-x64-1.20.0.exe' $UrlFile;
#     $InstallOptions = '/verysilent /suppressmsgboxes /closeapplications /restartapplications /mergetasks="!runCode, desktopicon, quicklaunchicon, addcontextmenufiles, !addcontextmenufolders, addtopath" /DIR="' + $VSCodeDir + '" /LOG="' + (Join-Path $Global:PathAppsTemp '\Install-VSCode.log') + '"';
#     If (-not ([string]::IsNullOrEmpty($VSCodeFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing Visual Studio Code.";
#         Start-ProcessInSilentMode $VSCodeFile $InstallOptions | Out-Null;
#         Update-SessionEnvironment;
#         $Command = (Get-Command "code.cmd" -ErrorAction SilentlyContinue).Source
#         If ([string]::IsNullOrEmpty($Command))
#         {
#             Write-Host "`r`n";
#             Logs-Write "ERROR: code.cmd no found in $VSCodeDir\bin." -ForegroundColor Red -BackgroundColor Black;
#         }
#         Logs-Write "Adding Visual Studio Code Extensions.";
#         $TextFile = "ms-python.python", "ms-vscode.csharp", "PeterJausovec.vscode-docker", "formulahendry.docker-explorer", "ms-azuretools.vscode-cosmosdb",
#                     "ms-vscode.powershell", "ms-vscode.cpptools";
#         ForEach($Extension in $TextFile)
#         {
#             $InstallOptions = '--install-extension ' + $Extension;
#             Start-ProcessInSilentMode $Command $InstallOptions | Out-Null;
#         }
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Visual Studio Code." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Visual Studio Code is already installed.";
# }



# #######################################
# # Processing installation of PyCharm. #
# #######################################
# Write-Host "`r`n`r`n";
# Logs-Write "#######################################";
# Logs-Write "# Processing installation of PyCharm. #";
# Logs-Write "#######################################";
# $Key = Get-UninstallRegistryKey 'JetBrains PyCharm Community Edition*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $PyCharmDir = Join-Path $PathInstall 'PyCharm';
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\pycharm-community-2017.3.3.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://download.jetbrains.com/python/pycharm-community-2017.3.3.exe';
#     }
#     $PyCharmFile = DownloadFile 'pycharm-community-2017.3.3.exe' $UrlFile;
#     If (-not ([string]::IsNullOrEmpty($PyCharmFile)))
#     {
#         $TextFile = "mode=admin", "launcher32=0", "launcher64=1", "jre32=0", ".py=1" -Join "`n" | Out-File -Encoding ASCII ($Global:PathAppsTemp + "\silent.config");
#         $InstallOptions = '/S /CONFIG="' + $Global:PathAppsTemp + '\silent.config" /D=' + $PyCharmDir;
#         Write-Host "`r`n";
#         Logs-Write "Installing PyCharm.";
#         Start-ProcessInSilentMode $PyCharmFile $InstallOptions | Out-Null;
#         Update-SessionEnvironment;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing PyCharm." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "PyCharm is already installed.";
# }


# ######################################
# # Processing installation of Appium. #
# ######################################
# Write-Host "`r`n`r`n";
# Logs-Write "######################################";
# Logs-Write "# Processing installation of Appium. #";
# Logs-Write "######################################";
# $Key = Get-UninstallRegistryKey 'Appium *' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $AppiumDir = Join-Path $PathInstall 'Appium';
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\Appium.Setup.1.3.2.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://github.com/appium/appium-desktop/releases/download/v1.3.2/Appium.Setup.1.3.2.exe';
#     }
#     $AppiumFile = DownloadFile 'Appium.Setup.1.3.2.exe' $UrlFile;
#     If (-not ([string]::IsNullOrEmpty($AppiumFile)))
#     {
#         $InstallOptions = '/NCRC /S /D=' + $AppiumDir;
#         Write-Host "`r`n";
#         Logs-Write "Installing Appium.";
#         Start-ProcessInSilentMode $AppiumFile $InstallOptions | Out-Null;
#         $OldPath = Join-Path $Env:LocalAppData 'Programs\appium-desktop';
#         Start-ProcessInSilentMode $Global:RoboCopy "`"$OldPath`" `"$AppiumDir`" /e /move /np" $False | Out-Null;
#         Install-EnvironmentVariablePath $AppiumDir 'User';
#         Update-UnInstallPath 'Appium' 'DisplayIcon' $OldPath $AppiumDir;
#         Update-UnInstallPath 'Appium' 'UninstallString' $OldPath $AppiumDir;
#         $Key = (Get-UninstallRegistryKey 'Appium*' -WarningAction SilentlyContinue).PSChildName;
#         If (-not [string]::IsNullOrEmpty($Key))
#         {
#             Set-ItemProperty -Path "HKCU:\Software\$Key" -Name "InstallLocation" -Value $AppiumDir
#         }
#         $AppiumExe = $AppiumDir + '\Appium.exe';
#         $DesktopPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Appium.lnk";
#         Install-Shortcut -ShortcutFilePath $DesktopPath -TargetPath $AppiumExe -IconLocation $AppiumExe;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Appium." -ForegroundColor Red -BackgroundColor Black;
#         Logs-End -Exit -ErrorLevel -12345;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Appium is already installed.";
# }



# #######################################
# # Processing installation of MongoDb. #
# #######################################
# Write-Host "`r`n`r`n";
# Logs-Write "#######################################";
# Logs-Write "# Processing installation of MongoDb. #";
# Logs-Write "#######################################";
# $Key = Get-UninstallRegistryKey 'MongoDB *' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $MongoDir = Join-Path $PathInstall 'MongoDb';
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\mongodb-win32-x86_64-2008plus-ssl-3.6.2-signed.msi';
#     }
#     Else
#     {
#         $UrlFile = 'https://fastdl.mongodb.org/win32/mongodb-win32-x86_64-2008plus-ssl-3.6.2-signed.msi';
#     }
#     $MongoFile = DownloadFile 'mongodb-win32-x86_64-2008plus-ssl-3.6.2-signed.msi' $UrlFile;
#     If (-not ([string]::IsNullOrEmpty($MongoFile)))
#     {
#         $InstallOptions = '/q /i "' + $MongoFile + '" INSTALLLOCATION="' + $MongoDir + '" ADDLOCAL="All" /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-MongoDb.log') + '"';
#         Write-Host "`r`n";
#         Logs-Write "Installing MongoDb.";
#         Start-ProcessInSilentMode $Global:Msi $InstallOptions | Out-Null;
#         $MongoExe = Join-Path $MongoDir 'bin\mongod.exe';
#         If (ExistsPaths $MongoExe)
#         {
#             Logs-Write "Configurating MongoDb.";
#             $DatabaseDir = Join-Path $MongoDir 'databases';
#             PrepareDirectory $DatabaseDir;
#             $LogDir = Join-Path $MongoDir 'logs';
#             PrepareDirectory $LogDir;
#             $NewPath = Join-Path $MongoDir 'bin';
#             Install-EnvironmentVariablePath $NewPath 'Machine';            
#             $TextFile = "systemLog:", "    destination: file", "    path: $LogDir\mongod.log", "storage:", "    dbPath: $DatabaseDir" -Join "`n" | Out-File -Encoding ASCII ($MongoDir + "\bin\mongod.cfg");
#             $InstallOptions = '--config "' + $MongoDir + '\bin\mongod.cfg" --install';
#             Start-ProcessInSilentMode $MongoExe $InstallOptions | Out-Null;
#             Logs-Write "Initializing Service MongoDb.";
#             Start-ProcessInSilentMode "net" "start MongoDB" $True | Out-Null;
#         }
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing MongoDb." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "MongoDb is already installed.";
# }



# ######################################
# # Processing installation of Docker. #
# ######################################
# Write-Host "`r`n`r`n";
# Logs-Write "######################################";
# Logs-Write "# Processing installation of Docker. #";
# Logs-Write "######################################";
# $Key = Get-UninstallRegistryKey 'Docker for Windows*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     $DockerDir = Join-Path $PathInstall 'Docker';
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\Docker for Windows Installer.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe';
#     }
#     $DockerFile = DownloadFile 'Docker for Windows Installer.exe' $UrlFile;
#     $InstallOptions = 'install --quiet';
#     If (-not ([string]::IsNullOrEmpty($DockerFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing Docker.";
#         Start-ProcessInSilentMode $DockerFile $InstallOptions | Out-Null;
#         Update-SessionEnvironment;
#         $OldPath = Join-Path $Env:ProgramFiles 'Docker\Docker'
#         If (ExistsPaths $OldPath)
#         {
#             $ServiceName = 'com.docker.service';
#             If (ExistsService $ServiceName)
#             {
#                 Logs-Write "Stoping the Windows Service '$ServiceName'.";
#                 Stop-Service -Name $ServiceName -Force;
#                 While ((Get-Service $ServiceName).Status -ne "Stopped")
#                 {
#                     Logs-Write "Waiting for service '$ServiceName' to stop.";
#                     Start-Sleep -S 3;
#                 }
#             }
#             Logs-Write "Moving Docker to '$DockerDir'.";
#             $ParentDir = (Get-Item $OldPath).Parent.FullName;
#             Start-ProcessInSilentMode $Global:RoboCopy "`"$OldPath`" `"$DockerDir`" /e /move /np" $False | Out-Null;
#             Remove-Item -Recurse -Force $ParentDir | Out-Null;
#             Logs-Write "Adjusting the Windows Service '$ServiceName'.";
#             $NewPath = Join-Path $DockerDir $ServiceName;
#             Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\$ServiceName" -Name "ImagePath" -Value $NewPath
#             Logs-Write "Starting the Windows Service '$ServiceName'.";
#             Start-Service -Name $ServiceName;
#             Logs-Write "Adjusting the Windows Registry and Environment Variables.";
#             Update-UnInstallPath 'Docker for Windows' 'DisplayIcon' $OldPath $DockerDir;
#             Update-UnInstallPath 'Docker for Windows' 'InstallLocation' $OldPath $DockerDir;
#             Update-UnInstallPath 'Docker for Windows' 'UninstallString' $OldPath $DockerDir;
#             $BinPath = Join-Path $OldPath 'Resources\bin'
#             UnInstall-EnvironmentVariablePath $BinPath 'Machine';
#             $BinPath = Join-Path $DockerDir 'Resources\bin'
#             Install-EnvironmentVariablePath $BinPath 'Machine';
#             $DockerExe = Join-Path $DockerDir 'Docker for Windows.exe';
#             Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Docker for Windows" -Value $DockerExe
#             Set-ItemProperty -Path "HKLM:\SOFTWARE\Docker Inc.\Docker\1.0" -Name "AppPath" -Value $DockerDir
#             Set-ItemProperty -Path "HKLM:\SOFTWARE\Docker Inc.\Docker\1.0" -Name "BinPath" -Value $BinPath
#             $DesktopPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Docker for Windows.lnk";
#             Install-Shortcut -ShortcutFilePath $DesktopPath -TargetPath $DockerExe -IconLocation $DockerExe;
#             Logs-Write "Enabling the Hiper-V.";
#             $Command = (Get-Command "dism.exe" -ErrorAction SilentlyContinue).Source
#             If ([string]::IsNullOrEmpty($Command))
#             {
#                 Write-Host "`r`n";
#                 Logs-Write "ERROR: dism.exe no found in $Env:SystemRoot\System32." -ForegroundColor Red -BackgroundColor Black;
#             }
#             Else
#             {
#                 Logs-Write " > $Command /Online /Enable-Feature:Microsoft-Hyper-V /All /NoRestart" -ForegroundColor DarkGray;
#                 Invoke-Expression "$Command /Online /Enable-Feature:Microsoft-Hyper-V /All /NoRestart";
#             }
#             $Command = (Get-Command "bcdedit.exe" -ErrorAction SilentlyContinue).Source
#             If ([string]::IsNullOrEmpty($Command))
#             {
#                 Write-Host "`r`n";
#                 Logs-Write "ERROR: bcdedit.exe no found in $Env:SystemRoot\System32." -ForegroundColor Red -BackgroundColor Black;
#             }
#             Else
#             {
#                 Logs-Write " > $Command /set hypervisorlaunchtype auto" -ForegroundColor DarkGray;
#                 Invoke-Expression "$Command /set hypervisorlaunchtype auto";
#             }
#         }
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Docker." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Docker is already installed.";
# }


# ##################################################################
# # Processing installation of Visual Studio Emulator for Android. #
# ##################################################################
# Write-Host "`r`n`r`n";
# Logs-Write "##################################################################";
# Logs-Write "# Processing installation of Visual Studio Emulator for Android. #";
# Logs-Write "##################################################################";
# $Key = Get-UninstallRegistryKey 'Microsoft Visual Studio Emulator for Android*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\vs_emulatorsetup.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://download.microsoft.com/download/3/E/6/3E6568E8-D444-4B1B-9BA2-817DEA2196D6/20160622.2/vs_emulatorsetup.exe';
#     }
#     $VsEmulatorFile = DownloadFile 'vs_emulatorsetup.exe' $UrlFile;
#     If (-not ([string]::IsNullOrEmpty($VsEmulatorFile)))
#     {
#         $VsEmulatorDir = Join-Path $PathInstall 'VSEmulator';
#         $InstallOptions = '/Full /CustomInstallPath "' + $VsEmulatorDir + '" /L "' + (Join-Path $Global:PathAppsTemp '\Install-VSEmulator.log') + '" /NoRestart /Q /S';
#         Write-Host "`r`n";
#         Logs-Write "Installing Visual Studio Emulator for Android.";
#         Start-ProcessInSilentMode $VsEmulatorFile $InstallOptions | Out-Null;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Visual Studio Emulator for Android." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Visual Studio Emulator for Android is already installed.";
# }



# ##################################################
# # Processing installation of Sysinternals Suite. #
# ##################################################
# Write-Host "`r`n`r`n";
# Logs-Write "##################################################";
# Logs-Write "# Processing installation of Sysinternals Suite. #";
# Logs-Write "##################################################";
# $UsersKey = 'HKCU:\SOFTWARE\Sysinternals';
# [array]$Keys = Get-ChildItem -Path $UsersKey -ErrorAction SilentlyContinue;
# $Tools = "AccessChk", "Active Directory Explorer", "ADInsight", "Autologon", "AutoRuns", "BGInfo", "CacheSet", "ClockRes",
#          "Coreinfo", "Ctrl2cap", "DbgView", "Desktops", "Disk2Vhd", "Diskmon", "DiskView", "Du", "EFSDump", "FindLinks",
#          "Handle", "Hex2Dec", "Junction", "LdmDump", "ListDLLs", "LoadOrder", "Movefile", "PageDefrag", "PendMove",
#          "PipeList", "Portmon", "ProcDump", "Process Explorer", "Process Monitor", "PsExec", "psfile", "PsGetSid", "PsInfo",
#          "PsKill", "PsList", "PsLoggedon", "PsLoglist", "PsPasswd", "PsService", "PsShutdown", "PsSuspend", "RamMap", "RegDelNull",
#          "Regjump", "Regsize", "RootkitRevealer", "Share Enum", "ShellRunas", "SigCheck", "Streams", "Strings", "Sync",
#          "System Monitor", "TCPView", "VMMap", "VolumeID", "Whois", "Winobj", "ZoomIt";
# If ($Keys.Count -lt $Tools.Count)
# {
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\SysinternalsSuite.zip';
#     }
#     Else
#     {
#         $UrlFile = 'https://download.sysinternals.com/files/SysinternalsSuite.zip';
#     }
#     $SysinternalsFile = DownloadFile 'SysinternalsSuite.zip' $UrlFile;
#     If (-not ([string]::IsNullOrEmpty($SysinternalsFile)))
#     {
#         $SysinternalsDir = Join-Path $PathInstall 'Sysinternals';
#         PrepareDirectory $SysinternalsDir;
#         Write-Host "`r`n";
#         Logs-Write "Installing Sysinternals Suite.";
#         UnzipFile $SysinternalsFile $SysinternalsDir | Out-Null;
#         If (ExistsPaths $SysinternalsDir)
#         {
#             Write-Host "`r`n";
#             Logs-Write "Configurating Sysinternals Suite.";
#             New-Item -Path $UsersKey -ErrorAction SilentlyContinue | Out-Null;
#             ForEach ($Tool in $Tools)
#             {
#                 $NewKey = Join-Path $UsersKey $Tool;
#                 New-Item -Path $NewKey -ErrorAction SilentlyContinue | Out-Null;
#                 New-ItemProperty -Path $NewKey -Name EulaAccepted -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null;
#             } 
#             $NewKey = Join-Path $UsersKey "\SigCheck\VirusTotal";
#             New-Item -Path $NewKey -ErrorAction SilentlyContinue | Out-Null;
#             New-ItemProperty -Path $NewKey -Name VirusTotalTermsAccepted -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null;
#             Install-EnvironmentVariablePath $SysinternalsDir 'Machine';
#         }
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Sysinternals Suite." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Sysinternals Suite is already installed.";
# }


# #####################################
# # Processing installation of Vysor. #
# #####################################
# Write-Host "`r`n`r`n";
# Logs-Write "#####################################";
# Logs-Write "# Processing installation of Vysor. #";
# Logs-Write "#####################################";
# $Key = Get-UninstallRegistryKey 'Vysor*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\Vysor-win32-ia32.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://vysornuts.clockworkmod.com/download/win32';
#     }
#     $VysorFile = DownloadFile 'Vysor-win32-ia32.exe' $UrlFile;
#     $InstallOptions = '/passive';
#     If (-not ([string]::IsNullOrEmpty($VysorFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing Vysor.";
#         Start-ProcessInSilentMode $VysorFile $InstallOptions | Out-Null;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Vysor." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Vysor is already installed.";
# }



# ####################################################
# # Processing installation of Universal Adb Driver. #
# ####################################################
# Write-Host "`r`n`r`n";
# Logs-Write "####################################################";
# Logs-Write "# Processing installation of Universal Adb Driver. #";
# Logs-Write "####################################################";
# $Key = Get-UninstallRegistryKey 'Universal Adb Driver*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\UniversalAdbDriverSetup.msi';
#     }
#     Else
#     {
#         $UrlFile = 'http://download.clockworkmod.com/test/UniversalAdbDriverSetup.msi';
#     }
#     $AdbDriverFile = DownloadFile 'UniversalAdbDriverSetup.msi' $UrlFile;
#     If (-not ([string]::IsNullOrEmpty($AdbDriverFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing Universal AdbDriver.";
#         $InstallOptions = '/i "' + $AdbDriverFile + '" /quiet /qn /norestart /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-UniversalAdbDriver.log') + '"';
#         Start-ProcessInSilentMode $Global:Msi $InstallOptions | Out-Null;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing Universal AdbDriver." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "Universal AdbDriver is already installed.";
# }



# ######################################
# # Processing installation of ConEmu. #
# ######################################
# Write-Host "`r`n`r`n";
# Logs-Write "######################################";
# Logs-Write "# Processing installation of ConEmu. #";
# Logs-Write "######################################";
# $Key = Get-UninstallRegistryKey 'ConEmu*' -WarningAction SilentlyContinue;
# If ($Null -eq $Key)
# {
#     If ($UseSharedFolder)
#     {
#         $UrlFile = $RepositoryLocal + '\ConEmuSetup.180309.exe';
#     }
#     Else
#     {
#         $UrlFile = 'https://github.com/Maximus5/ConEmu/releases/download/v18.03.09/ConEmuSetup.180309.exe';
#     }
#     $ConEmuFile = DownloadFile 'ConEmuSetup.180309.exe' $UrlFile;
#     $ConEmuDir = Join-Path $PathInstall 'ConEmu'
#     If (-not ([string]::IsNullOrEmpty($ConEmuFile)))
#     {
#         Write-Host "`r`n";
#         Logs-Write "Installing ConEmu.";
#         $InstallOptions = '/p:x64,adm /quiet /qn /norestart APPLICATIONFOLDER="' + $ConEmuDir + '" /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-ConEmu.log') + '"';
#         Start-ProcessInSilentMode $ConEmuFile $InstallOptions | Out-Null;
#     }
#     Else
#     {
#         Write-Host "`r`n";
#         Logs-Write "ERROR: An error occurred when installing ConEmu." -ForegroundColor Red -BackgroundColor Black;
#     }
# }
# Else
# {
#     Write-Host "`r`n";
#     Logs-Write "ConEmu is already installed.";
# }



# ################################################
# # Cloning Repository 'tea-data-management-ui'. #
# ################################################
# Write-Host "`r`n`r`n";
# Logs-Write "################################################";
# Logs-Write "# Cloning Repository 'tea-data-management-ui'. #";
# Logs-Write "################################################";
# PrepareDirectory $PathRepository;
# $RepositoryName = 'tea-data-management-ui';
# If (ExistsPaths $PathRepository)
# {
#     $RepoDir = Join-Path $PathRepository $RepositoryName;
#     If((Get-ChildItem $RepoDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1 | Measure-Object).Count -eq 0)
#     {
#         Push-Location -Path $PathRepository;
#         $Command = "git";
#         $InstallOptions = 'clone https://bit.heartlandcommerce.com/scm/hc/' + $RepositoryName + '.git';
#         Logs-Write " >" $Command $InstallOptions -ForegroundColor DarkGray;
#         Invoke-Expression "$Command $InstallOptions";
#         If (ExistsPaths $RepoDir)
#         {
#             Push-Location -Path $RepoDir;
#             $Command = 'pip install virtualenv';
#             Logs-Write " >" $Command -ForegroundColor DarkGray;
#             Invoke-Expression $Command;
#             $Command = 'virtualenv ENV';
#             Logs-Write " >" $Command -ForegroundColor DarkGray;
#             Invoke-Expression $Command;
#             $Command = (Join-Path $RepoDir 'ENV\Scripts\activate.ps1') + ' | pip install -r requirements.txt';
#             Logs-Write " >" $Command -ForegroundColor DarkGray;
#             Invoke-Expression $Command;
#             Pop-Location;
#         }
#         Pop-Location;
#     }
# }



# #####################################
# # Cloning Repository 'tea-pos-app'. #
# #####################################
# Write-Host "`r`n`r`n";
# Logs-Write "#####################################";
# Logs-Write "# Cloning Repository 'tea-pos-app'. #";
# Logs-Write "#####################################";
# PrepareDirectory $PathRepository;
# $RepositoryName = 'tea-pos-app';
# If (ExistsPaths $PathRepository)
# {
#     $RepoDir = Join-Path $PathRepository $RepositoryName;
#     If((Get-ChildItem $RepoDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1 | Measure-Object).Count -eq 0)
#     {
#         Push-Location -Path $PathRepository;
#         $Command = "git";
#         $InstallOptions = 'clone https://bit.heartlandcommerce.com/scm/hc/' + $RepositoryName + '.git';
#         Logs-Write " >" $Command $InstallOptions -ForegroundColor DarkGray;
#         Invoke-Expression "$Command $InstallOptions";
#         If (ExistsPaths $RepoDir)
#         {
#             Push-Location -Path $RepoDir;
#             $Command = 'pip install virtualenv';
#             Logs-Write " >" $Command -ForegroundColor DarkGray;
#             Invoke-Expression $Command;
#             $Command = 'virtualenv ENV';
#             Logs-Write " >" $Command -ForegroundColor DarkGray;
#             Invoke-Expression $Command;
#             $Command = (Join-Path $RepoDir 'ENV\Scripts\activate.ps1') + ' | pip install -r requirements.txt';
#             Logs-Write " >" $Command -ForegroundColor DarkGray;
#             Invoke-Expression $Command;
#             Pop-Location;
#         }
#         Pop-Location;
#     }
# }



# #################################
# # Cloning Repository 'pos-app'. #
# #################################
# Write-Host "`r`n`r`n";
# Logs-Write "#################################";
# Logs-Write "# Cloning Repository 'pos-app'. #";
# Logs-Write "#################################";
# PrepareDirectory $PathRepository;
# $RepositoryName = 'pos-app';
# If (ExistsPaths $PathRepository)
# {
#     $RepoDir = Join-Path $PathRepository $RepositoryName;
#     If((Get-ChildItem $RepoDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1 | Measure-Object).Count -eq 0)
#     {
#         $Command = 'npm i -g npm@5';
#         Logs-Write " >" $Command -ForegroundColor DarkGray;
#         Invoke-Expression $Command;
#         $Command = 'npm i -g node-gyp';
#         Logs-Write " >" $Command -ForegroundColor DarkGray;
#         Invoke-Expression $Command;
#         $Command = 'npm config set registry https://npm.heartlandcommerce.com/repository/npm-all/';
#         Logs-Write " >" $Command -ForegroundColor DarkGray;
#         Invoke-Expression $Command;
#         $Command = 'npm login --registry=https://npm.heartlandcommerce.com/repository/npm-all/';
#         Logs-Write " >" $Command -ForegroundColor DarkGray;
#         Invoke-Expression $Command;
#         $Command = 'npm --loglevel info install @hc/hello-dev';
#         Logs-Write " >" $Command -ForegroundColor DarkGray;
#         Invoke-Expression $Command;
#         $Command = 'npm config set msvs_version 2015 -g';
#         Logs-Write " >" $Command -ForegroundColor DarkGray;
#         Invoke-Expression $Command;
#         Push-Location -Path $PathRepository;
#         $Command = "git";
#         $InstallOptions = 'clone https://bit.heartlandcommerce.com/scm/hc/' + $RepositoryName + '.git';
#         Logs-Write " >" $Command $InstallOptions -ForegroundColor DarkGray;
#         Invoke-Expression "$Command $InstallOptions";
#         If (ExistsPaths $RepoDir)
#         {
            
            
#             Push-Location -Path $RepoDir;
            

#             Pop-Location;
#         }
#         Pop-Location;
#     }
# }
Logs-End;
