<#
.SYNOPSIS
Prepares and installs all the necessary software for the design and execution of
Xenial project test cases.

.DESCRIPTION
This script performs the installation and configuration in silent mode of the following programs:
- Java SE Development Kit 8 Update 162 8.0.1620.12
- Android SDK (Includes the minimum packages required.)
- Android Studio 3.0.1
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
- Sysinternals Suite
- Vysor 1.8.5
- Universal ADB Drivers 1.0.4
- ConEmu 18.03.09

Additionally this script clones and preconfigures the following repositories:
- https://bit.heartlandcommerce.com/scm/hc/tea-data-management-ui.git'
- https://bit.heartlandcommerce.com/scm/hc/tea-pos-app.git'

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
- Powershell v2.0 installed
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
Use $true for download from Shared Temporary Folder, the script determine
if you are in the PSL office of Medellin or Bogota. Otherwise use $false
for download directly of internet.

.EXAMPLE
InstallAppsXenial -PathInstall "D:\Apps" -PathRepository "D:\Xenial" -UseSharedFolder $false
#>
param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $PathInstall,
        [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string] $PathRepository,
        [parameter(Mandatory=$false, Position=2)][bool] $UseSharedFolder = $false
    )

###########################
# Begin General Functions #
###########################
# Validate if the Path is valid
Function ValidatePaths
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][string] $PathToValidate
    )

    if ([string]::IsNullOrEmpty($PathToValidate))
    {
        Write-Host "`r`nERROR: Path parameter is null or empty." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
    if (-not (Test-Path -IsValid $PathToValidate))
    {
        Write-Host "`r`nERROR: $PathValidate not is a path valid." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
}


# Validate if the Path exist in the system
Function ExistsPaths
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $PathToValidate,
        [parameter(Mandatory=$false, Position=1)][boolean] $PrintWarning = $false
    )

    if (-not (Test-Path -Path "$PathToValidate"))
    {
        if ($PrintWarning)
        {
            Write-Host "$PathToValidate not found in the system.";
        }
        return $false;
    }
    return $true;
}



# Validate if Windows Service exists
Function ExistsService
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $ServiceName
    )

    return [bool](Get-Service $ServiceName -ErrorAction SilentlyContinue);
}



#Obtaint the short path for any path file or folder
Function Get-ShortPath
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $PathFile
    )

    $FileSystem = New-Object -ComObject Scripting.FileSystemObject;
    $ShortPath = [string]::Empty;
    if ($FileSystem.FileExists($PathFile) -eq $true)
    {
        $FileInfo = $FileSystem.GetFile($PathFile);
        $ShortPath = $FileInfo.ShortPath;
    }
    else
    {
        if ($FileSystem.FolderExists($PathFile) -eq $true)
        {
            $FileInfo = $FileSystem.GetFolder($PathFile);
            $ShortPath = $FileInfo.ShortPath;
        }
    }
    return $ShortPath;
}


Function IsURIWeb
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $Address
    )

    $Uri = $Address -as [System.URI];
    $Uri.AbsoluteURI -ne $null -and $Uri.Scheme -match '[http|https]';
}


Function PrepareDirectory
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][string] $DirectoryPath
    )

    ValidatePaths $DirectoryPath;
    if (-not (ExistsPaths $DirectoryPath $true))
    {
        Write-Host "Proceeding to create $DirectoryPath.";
        New-Item -Type Directory -Path $DirectoryPath -Force | Out-Null;
    }
}


Function Test-ProcessAdminRights
{
    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent([Security.Principal.TokenAccessLevels]'Query,Duplicate'));
    $IsAdmin = $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
    Write-Debug "Test-ProcessAdminRights: returning $IsAdmin";
    return $isAdmin;
}


Function Update-SessionEnvironment
{
    param
    (
        [parameter(Mandatory=$false, Position=0)][bool] $PrintMessage = $true
    )

    if ($PrintMessage)
    {
        Write-Host "Refreshing environment variables from the registry.";
    }
    $UserName = $Env:UserName;
    $Architecture = $Env:Processor_Architecture;
    $Path = $Env:Path;
    $PsModulePath = $Env:PSModulePath;
    #Ordering is important here, $User comes after so we can override $Machine
    'Process', 'Machine', 'User' |
        ForEach-Object { $Scope = $_
            Get-EnvironmentVariableNames -Scope $Scope |
            ForEach-Object {
                Set-Item "Env:$($_)" -Value (Get-EnvironmentVariable -Name $_ -Scope $Scope)
            }
        };
    #Path gets special treatment b/c it munges the two together
    $Paths = 'Machine', 'User' |
        ForEach-Object {
            (Get-EnvironmentVariable -Name 'PATH' -Scope $_) -Split ';'
        } | Select-Object -Unique;
    $Env:Path = $Paths -join ';';
    #PSModulePath is almost always updated by process, so we want to preserve it.
    $Env:PSModulePath = $PsModulePath;
    #Reset user and architecture
    if ($UserName)
    {
        $Env:UserName = $UserName;
    }
    if ($Architecture)
    {
        $Env:Processor_Architecture = $Architecture;
    }
}


Function Get-EnvironmentVariableNames
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][System.EnvironmentVariableTarget] $Scope
    )

    switch ($Scope)
    {
        'User'
        {
            Get-Item 'HKCU:\Environment' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property;
        }
        'Machine'
        {
            Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property;
        }
        'Process'
        {
            Get-ChildItem Env:\ -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Key;
        }
        default
        {
            Write-Host "`r`nERROR: Unsupported environment scope: $Scope." -ForegroundColor Yellow -BackgroundColor Red;
        }
  }
}


Function Get-EnvironmentVariable
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $Name,
        [parameter(Mandatory=$true, Position=1)][System.EnvironmentVariableTarget] $Scope,
        [parameter(Mandatory=$false, Position=2)][switch] $PreserveVariables = $false,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $IgnoredArguments
    )

    $Machine_Environment_Registry_Key_Name = "SYSTEM\CurrentControlSet\Control\Session Manager\Environment\";
    $Win32RegistryKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Machine_Environment_Registry_Key_Name);
    if ($Scope -eq [System.EnvironmentVariableTarget]::User)
    {
        $User_Environment_Registry_Key_Name = "Environment";
        $Win32RegistryKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($User_Environment_Registry_Key_Name);
    }
    elseif ($Scope -eq [System.EnvironmentVariableTarget]::Process)
    {
        return [Environment]::GetEnvironmentVariable($Name, $Scope);
    }
    $RegistryValueOptions = [Microsoft.Win32.RegistryValueOptions]::None;
    if ($PreserveVariables)
    {
        Write-Debug "Choosing not to expand environment names.";
        $RegistryValueOptions = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames;
    }
    $EnvironmentVariableValue = [string]::Empty;
    try
    {
        if ($Win32RegistryKey -ne $null)
        {
            #Some versions of Windows do not have HKCU:\Environment
            $EnvironmentVariableValue = $Win32RegistryKey.GetValue($Name, [string]::Empty, $RegistryValueOptions);
        }
    }
    catch
    {
        Write-Debug "Unable to retrieve the $Name environment variable. Details: $_.";
    }
    finally
    {
        if ($Win32RegistryKey -ne $null)
        {
            $Win32RegistryKey.Close();
        }
    }
    if ($EnvironmentVariableValue -eq $null -or $EnvironmentVariableValue -eq '')
    {
        $EnvironmentVariableValue = [Environment]::GetEnvironmentVariable($Name, $Scope);
    }
    return $EnvironmentVariableValue;
}


Function Set-EnvironmentVariable
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $Name,
        [parameter(Mandatory=$false, Position=1)][string] $Value,
        [parameter(Mandatory=$false, Position=2)][System.EnvironmentVariableTarget] $Scope,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $IgnoredArguments
    )

	if ($Name.ToUpper().Trim() -ne 'PATH')
    {
		Write-Host "Setting Environment Variable $Name with the value $Value in `'$Scope`'.";
	}
    if ($Scope -eq [System.EnvironmentVariableTarget]::Process -or $Value -eq $null -or $Value -eq '')
    {
        return [Environment]::SetEnvironmentVariable($Name, $Value, $Scope);
    }
    $KeyHive = 'HKEY_LOCAL_MACHINE';
    $RegistryKey = "SYSTEM\CurrentControlSet\Control\Session Manager\Environment\";
    $Win32RegistryKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($RegistryKey);
    if ($Scope -eq [System.EnvironmentVariableTarget]::User)
    {
        $KeyHive = 'HKEY_CURRENT_USER';
        $RegistryKey = "Environment";
        $Win32RegistryKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($RegistryKey);
    }
    $RegistryType = [Microsoft.Win32.RegistryValueKind]::String;
    try
    {
        if ($Win32RegistryKey.GetValueNames() -contains $Name)
        {
            $RegistryType = $Win32RegistryKey.GetValueKind($Name);
        }
    }
    catch
    {
        # The value doesn't yet exist move along, nothing to see here.
    }
    Write-Debug "Registry type for $Name is/will be $RegistryType";
    if ($Name -eq 'PATH')
    {
        $RegistryType = [Microsoft.Win32.RegistryValueKind]::ExpandString;
    }
    [Microsoft.Win32.Registry]::SetValue($KeyHive + "\" + $RegistryKey, $Name, $Value, $RegistryType);
    try
    {
        #Make everything refresh because sometimes explorer.exe just doesn't get the message that things were updated.
        if (-not ("Win32.NativeMethods" -as [Type]))
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
    catch
    {
        Write-Host "WARNING: Failure attempting to let Explorer know about updated environment settings.`n  $($_.Exception.Message)" -ForegroundColor Yellow;
    }
    Update-SessionEnvironment;
}


Function UnInstall-EnvironmentVariablePath
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $PathToUnInstall,
        [parameter(Mandatory=$false, Position=1)][System.EnvironmentVariableTarget] $PathType = [System.EnvironmentVariableTarget]::User
    )

    Write-Host "Finding the Path to UnInstall: `'$PathToUnInstall`'.";
    #Get the PATH variable
    $EnvPath = $Env:PATH;
    if ($EnvPath.ToLower().Contains($PathToUnInstall.ToLower()))
    {
        $StatementTerminator = ';';
        Write-Host "PATH environment variable contains $PathToUnInstall. Removing.";
        $ActualPath = [System.Collections.ArrayList](Get-EnvironmentVariable -Name 'Path' -Scope $PathType).Split($StatementTerminator);
        $ActualPath.Remove($PathToUnInstall);
        $NewPath = $ActualPath -Join $StatementTerminator;
        if ($PathType -eq [System.EnvironmentVariableTarget]::Machine)
        {
            if (Test-ProcessAdminRights)
            {
                Set-EnvironmentVariable -Name 'Path' -Value $NewPath -Scope $PathType;
            }
            else
            {
                Write-Host "Run Powershell with Administrative Privilegies for uninstall `'$PathToUnInstall`' from `'$PathType`' PATH. Could not remove." -ForegroundColor Yellow;
            }
        }
        else
        {
            Set-EnvironmentVariable -Name 'Path' -Value $NewPath -Scope $PathType;
        }
    }
    else
    {
        Write-Host "The path to uninstall `'$PathToUnInstall`' was not found in the `'$PathType`' PATH. Could not remove.";
    }
    
}


Function Install-EnvironmentVariable
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $VariableName,
        [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string] $VariableValue,
        [parameter(Mandatory=$false, Position=2)][System.EnvironmentVariableTarget] $VariableType = [System.EnvironmentVariableTarget]::User,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $IgnoredArguments
    )

    Write-Host "Creating Environment Variable $VariableName with the value $VariableValue in `'$VariableType`'.";
    if ($VariableType -eq [System.EnvironmentVariableTarget]::Machine)
    {
        if (Test-ProcessAdminRights)
        {
            Set-EnvironmentVariable -Name $VariableName -Value $VariableValue -Scope $VariableType;
        }
        else
        {
            Write-Host "Run Powershell with Administrative Privilegies for install `'$VariableName`' from `'$VariableType`' Environment Variable. Could not add." -ForegroundColor Yellow;
        }
    }
    else
    {
        try
        {
            Set-EnvironmentVariable -Name $VariableName -Value $VariableValue -Scope $VariableType;
        }
        catch
        {
            if (Test-ProcessAdminRights)
            {
                # HKCU:\Environment may not exist, which happens sometimes with Server Core
                Set-EnvironmentVariable -Name $VariableName -Value $VariableValue -Scope Machine;
            }
            else
            {
                Write-Host "Run Powershell with Administrative Privilegies for install `'$VariableName`' from `'$VariableType`' Environment Variable. Could not add." -ForegroundColor Yellow;
            }
        }
    }
    Set-Content Env:\$VariableName $VariableValue;
}


Function Install-EnvironmentVariablePath
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $PathToInstall,
        [parameter(Mandatory=$false, Position=1)][System.EnvironmentVariableTarget] $PathType = [System.EnvironmentVariableTarget]::User,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $IgnoredArguments
    )

    #Get the PATH variable
    Update-SessionEnvironment $false;
    $EnvPath = $Env:PATH;
    if (!$EnvPath.ToLower().Contains($PathToInstall.ToLower()))
    {
        Write-Host "PATH environment variable does not have $pathToInstall in it. Adding.";
        $ActualPath = Get-EnvironmentVariable -Name 'Path' -Scope $PathType -PreserveVariables;
        $StatementTerminator = ";";
        #Does the path end in ';'?
        $HasStatementTerminator = $ActualPath -ne $null -and $ActualPath.EndsWith($StatementTerminator);
        #If the last digit is not ;, then we are adding it
        If (!$HasStatementTerminator -and $ActualPath -ne $null)
        {
            $PathToInstall = $StatementTerminator + $PathToInstall;
        }
        if (!$PathToInstall.EndsWith($StatementTerminator))
        {
            $PathToInstall = $PathToInstall + $StatementTerminator;
        }
        $ActualPath = $ActualPath + $PathToInstall;
        if ($PathType -eq [System.EnvironmentVariableTarget]::Machine)
        {
            if (Test-ProcessAdminRights)
            {
                Set-EnvironmentVariable -Name 'Path' -Value $ActualPath -Scope $PathType;
            }
            else
            {
                Write-Host "Run Powershell with Administrative Privilegies for uninstall `'$PathToInstall`' from `'$PathType`' PATH. Could not remove." -ForegroundColor Yellow;
            }
        }
        else
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
    param
    (
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)][ValidateNotNullOrEmpty()][string] $SoftwareName,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $IgnoredArguments
    )

    if ($SoftwareName -eq $null -or $SoftwareName -eq '')
    {
        throw "$SoftwareName cannot be empty for Get-UninstallRegistryKey";
    }
    $ErrorActionPreference = 'Stop';
    $Local_Key       = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*';
    $Machine_Key     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*';
    $Machine_Key6432 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*';

    Write-Verbose "Retrieving all uninstall registry keys";
    [array]$Keys = Get-ChildItem -Path @($Machine_Key6432, $Machine_Key, $Local_Key) -ErrorAction SilentlyContinue;
    Write-Debug "Registry uninstall keys on system: $($keys.Count)";
    Write-Debug "Error handling check: `'Get-ItemProperty`' fails if a registry key is encoded incorrectly.";
    $MaxAttempts = $Keys.Count;
    for ([int]$Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++)
    {
        $Success = $false;
        $KeyPaths = $Keys | Select-Object -ExpandProperty PSPath;
        try
        {
            [array]$FoundKey = Get-ItemProperty -Path $KeyPaths -ErrorAction Stop | Where-Object { $_.DisplayName -like $SoftwareName };
            $Success = $true;
        }
        catch
        {
            Write-Debug "Found bad key.";
            foreach ($Key in $Keys)
            {
                try
                {
                    Get-ItemProperty $Key.PsPath > $null;
                }
                catch
                {
                    $BadKey = $Key.PsPath;
                }
            }
            Write-Verbose "Skipping bad key: $BadKey";
            [array]$Keys = $Keys | Where-Object { $BadKey -NotContains $_.PsPath };
        }
        if ($Success)
        {
            break;
        }
        if ($Attempt -ge 10)
        {
            Write-Warning "Found 10 or more bad registry keys. Run command again with `'--verbose --debug`' for more info.";
        }
    }
    if ($FoundKey -eq $null -or $Foundkey.Count -eq 0)
    {
        Write-Warning "No registry key found based on '$SoftwareName'";
    }
    Write-Debug "Found $($FoundKey.Count) uninstall registry key(s) with SoftwareName:`'$SoftwareName`'";
    return $FoundKey;
}


#Update the path from Uninstall Package
function Update-UnInstallPath
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $DisplayName,
        [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string] $PropertyName,
        [parameter(Mandatory=$true, Position=2)][ValidateNotNullOrEmpty()][string] $OldValue,
        [parameter(Mandatory=$false, Position=3)][string] $NewValue = [string]::Empty
    )

    $DisplayNameRex = [System.String]::Concat($DisplayName, '*');
    [Array]$Keys = Get-UninstallRegistryKey $DisplayNameRex;
    if ($Keys.Count -ge 1)
    {
        for ([int]$i = 0; $i -lt $Keys.Count; $i++)
        {
            try
            {
                if ((Get-ItemProperty -Path $Keys[$i].PSPath).PSObject.Properties.Name -contains $PropertyName)
                {
                    [PSCustomObject]$Key = Get-ItemProperty -Path $Keys[$i].PSPath -Name $PropertyName;
                    [string]$Value = $Key.$PropertyName.Replace($OldValue, $NewValue);
                    Set-ItemProperty -Path $Keys[$i].PSPath -Name $PropertyName -Value $Value;
                }
            }
            catch
            {
                #Nothing
            }
        }
    }
}


Function Install-PinnedTaskBarItem
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $TargetFilePath,
        [parameter(ValueFromRemainingArguments = $true)][Object[]]$IgnoredArguments
    )

    Write-Debug "Running 'Install-PinnedTaskBarItem' with targetFilePath:`'$TargetFilePath`'";
    try
    {
        if (Test-Path($TargetFilePath))
        {
            $Verb = "Pin To Taskbar";
            $Path = Split-Path $TargetFilePath;
            $Shell = New-Object -Com "Shell.Application";
            $Folder = $Shell.Namespace($Path);
            $Item = $Folder.ParseName((Split-Path $TargetFilePath -Leaf));
            $ItemVerb = $Item.Verbs() | Where-Object { $_.Name.Replace("&",[string]::Empty) -eq $Verb };
            if($ItemVerb -eq $null)
            {
                Write-Host "TaskBar verb not found for $Item. It may have already been pinned.";
            }
            else
            {
                $ItemVerb.DoIt();
            }
            Write-Host "`'$TargetFilePath`' has been pinned to the task bar on your desktop.";
        }
        else
        {
            $ErrorMessage = "`'$TargetFilePath`' does not exist, not able to pin to task bar.";
        }
        if ($ErrorMessage)
        {
            Write-Warning $ErrorMessage;
        }
    }
    catch
    {
        Write-Warning "Unable to create pin. Error captured was $($_.Exception.Message).";
    }
}


Function Install-Shortcut
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $ShortcutFilePath,
        [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string] $TargetPath,
        [parameter(Mandatory=$false, Position=2)][string] $WorkingDirectory,
        [parameter(Mandatory=$false, Position=3)][string] $Arguments,
        [parameter(Mandatory=$false, Position=4)][string] $IconLocation,
        [parameter(Mandatory=$false, Position=5)][string] $Description,
        [parameter(Mandatory=$false, Position=6)][int] $WindowStyle,
        [parameter(Mandatory=$false)][switch] $RunAsAdmin,
        [parameter(Mandatory=$false)][switch] $PinToTaskbar,
        [parameter(ValueFromRemainingArguments = $true)][Object[]]$IgnoredArguments
    )

    if (!$ShortcutFilePath)
    {
        #Shortcut file path could be null if someone is trying to get special paths for LocalSystem (SYSTEM).
        Write-Warning "Unable to create shortcut. `$ShortcutFilePath can not be null.";
        return;
    }
    $ShortcutDirectory = $([System.IO.Path]::GetDirectoryName($ShortcutFilePath));
    if (!(Test-Path($ShortcutDirectory)))
    {
        [System.IO.Directory]::CreateDirectory($ShortcutDirectory) | Out-Null;
    }
    if (!$TargetPath)
    {
      throw "Install-ChocolateyShortcut - `$targetPath can not be null.";
    }
    if(!(Test-Path($TargetPath)) -and !(IsURIWeb($TargetPath)))
    {
      Write-Warning "'$TargetPath' does not exist. If it is not created the shortcut will not be valid.";
    }
    if($IconLocation)
    {
        if(!(Test-Path($iconLocation)))
        {
            Write-Warning "'$IconLocation' does not exist. A default icon will be used.";
        }
    }
    if ($WorkingDirectory)
    {
        if (!(Test-Path($WorkingDirectory)))
        {
            [System.IO.Directory]::CreateDirectory($WorkingDirectory) | Out-Null;
        }
    }
    Write-Debug "Creating Shortcut.";
    try
    {
        $Global:WshShell = New-Object -Com "WScript.Shell";
        $Lnk = $Global:WshShell.CreateShortcut($ShortcutFilePath);
        $Lnk.TargetPath = $TargetPath;
        $Lnk.WorkingDirectory = $WorkingDirectory;
        $Lnk.Arguments = $Arguments;
        if($IconLocation)
        {
            $Lnk.IconLocation = $IconLocation;
        }
        if ($Description)
        {
            $Lnk.Description = $Description;
        }
        if ($WindowStyle)
        {
            $Lnk.WindowStyle = $WindowStyle;
        }
        $Lnk.Save();
        Write-Debug "Shortcut created.";
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
        if ($PinToTaskbar)
        {
            $PinVerb = (New-Object -com "Shell.Application").Namespace($(Split-Path -Parent $Path.FullName)).ParseName($(Split-Path -Leaf $Path.FullName)).Verbs() | Where-Object {$_.Name -eq 'Pin to Tas&kbar'};
            if ($PinVerb)
            {
                $PinVerb.DoIt();
            }
        }
    }
    catch
    {
        Write-Warning "Unable to create shortcut. Error captured was $($_.Exception.Message).";
    }
}


Function Start-ProcessInSilentMode
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $CommandToRun,
        [parameter(Mandatory=$false, Position=1)][string] $Parameters = [string]::Empty,
        [parameter(Mandatory=$false, Position=2)][bool] $ShowOutput = $true
    )

    Write-Host "`r`n >" $CommandToRun $Parameters "`r`n";
    # Setting process invocation parameters.
    $Psi = New-Object -TypeName System.Diagnostics.ProcessStartInfo;
	$Psi.CreateNoWindow = $true;
	$Psi.UseShellExecute = $false;
	$Psi.RedirectStandardOutput = $true;
	$Psi.RedirectStandardError = $true;
	$Psi.WorkingDirectory = $Global:PathAppsTemp;
	$Psi.FileName = $CommandToRun;
	if (![String]::IsNullOrEmpty($Parameters))
	{
	    $Psi.Arguments = $Parameters;
	}
    $Psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden;
	# Creating process object.
	$Process = New-Object -TypeName System.Diagnostics.Process;
    $Process.EnableRaisingEvents = $true;
	$Process.StartInfo = $Psi;
	# Creating string builders to store stdout and stderr.
	$StdOutBuilder = New-Object -TypeName System.Text.StringBuilder;
	$StdErrBuilder = New-Object -TypeName System.Text.StringBuilder;
	# Adding event handers for stdout and stderr.
	$ScripBlockOut = {
	        if ($EventArgs.Data -ne $null)
	        {
                Write-Verbose $EventArgs.Data
    	        $Event.MessageData.AppendLine($EventArgs.Data);
	        }
		};
    $ScripBlockError = {
	        if ($EventArgs.Data -ne $null)
            {
                Write-Error "$($EventArgs.Data)"
            }

		};
	$StdOutEvent = Register-ObjectEvent -InputObject $Process -Action $ScripBlockOut -EventName 'OutputDataReceived' -MessageData $StdOutBuilder;
	$StdErrEvent = Register-ObjectEvent -InputObject $Process -Action $ScripBlockError -EventName 'ErrorDataReceived' -MessageData $StdErrBuilder;
	# Starting process.
	$Process.Start() > $null;
	$Process.BeginOutputReadLine() > $null;
	$Process.BeginErrorReadLine() > $null;
	$Process.WaitForExit() > $null;
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
	if ($Result.StdOut -ne $null -and $ShowOutput)
    {
	    Write-Host $Result.StdOut;
    }
    Write-Debug $Result.StdOut;
    if($Result.ExitCode -gt 0)
	{					
        Write-Host "Exited with status code (" $Result.ExitCode ")" -ForegroundColor Yellow;
	    Write-Host $Result.StdErr;
	}
    Write-Debug $Result.StdErr;
    return $Result.ExitCode;
}


Function UnzipFile
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string] $FileFullPath,
        [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string] $Destination,
        [parameter(Mandatory=$false, Position=2)][string] $SpecificFolder,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $IgnoredArguments
    )

    Write-Host "Extracting $FileFullPath to $Destination.`r`n";
    PrepareDirectory $Destination;
    if ([IntPtr]::Size -ne 4)
    {
        $FileFullPathNoRedirection = $FileFullPath -ireplace ([System.Text.RegularExpressions.Regex]::Escape([Environment]::GetFolderPath('System'))),(Join-Path $Env:SystemRoot 'SysNative');
        $DestinationNoRedirection = $Destination -ireplace ([System.Text.RegularExpressions.Regex]::Escape([Environment]::GetFolderPath('System'))),(Join-Path $Env:SystemRoot 'SysNative');
    }
    else
    {
        $FileFullPathNoRedirection = $FileFullPath;
        $DestinationNoRedirection = $Destination;
    }
    $Params = "x -aoa -bd -bb1 -o`"$DestinationNoRedirection`" -y `"$FileFullPathNoRedirection`"";
    if ($SpecificFolder)
    {
        $Params += " `"$SpecificFolder`"";
    }
    
    $ExitCode = Start-ProcessInSilentMode $Global:SevenZip $Params $false;
    switch ($ExitCode)
    {
        0
        {
            break;
        }
        1
        {
            Write-Host "`r`nERROR: Some files could not be extracted." -ForegroundColor Yellow -BackgroundColor Red;
        }
        2
        {
            Write-Host "`r`nERROR: 7-Zip encountered a fatal error while extracting the files." -ForegroundColor Yellow -BackgroundColor Red;
        }
        7
        {
            Write-Host "`r`nERROR: 7-Zip command line error." -ForegroundColor Yellow -BackgroundColor Red;
        }
        8
        {
            Write-Host "`r`nERROR: 7-Zip out of memory." -ForegroundColor Yellow -BackgroundColor Red;
        }
        255
        {
            Write-Host "`r`nERROR: Extraction cancelled by the user." -ForegroundColor Yellow -BackgroundColor Red;
        }
        default
        {
            Write-Host "`r`nERROR: 7-Zip signalled an unknown error (code $ExitCode)." -ForegroundColor Yellow -BackgroundColor Red;
        }
    }
    return $Destination
}


Function DownloadFile
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string]$FileName,
        [parameter(Mandatory=$true, Position=1)][ValidateNotNullOrEmpty()][string]$Url,
        [parameter(Mandatory=$false, Position=2)][HashTable]$Headers = @{}
    )

    $OutputFilename = Join-Path $Global:PathAppsTemp $Filename;
    if (-not (ValidatePaths $OutputFilename) -and -not (ExistsPaths $OutputFilename))
    {
        Write-Host "Downloading File in $OutputFilename.";
        Write-Host "Downloading File from $Url.";
        try
        {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true };
            [Net.ServicePointManager]::SecurityProtocol =  [System.Security.Authentication.SslProtocols] "tls, tls11, tls12";
            $Client = New-Object Net.WebClient;
            if ($Headers.Count -gt 0)
            {
                ForEach($Item in $Headers.GetEnumerator())
                {
                    $Client.Headers.Add($Item.Key, $Item.Value);
                }
            }
            $Creds = [System.Net.CredentialCache]::DefaultCredentials;
            if ($Creds -ne $null)
            {
                $Client.Credentials = $Creds;
            }
            $Client.DownloadFile($Url, $OutputFilename);
        }
        catch
        {
            Write-Warning "Unable to download file. Error captured was $($_.Exception.Message).";
            $OutputFilename = [string]::Empty;
        }
        finally
        {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null;
        }
    }
    else
    {
        Write-Host "File $OutputFilename already exist. Discard download.";
    }
    return $OutputFilename
}



Function Ping-Machine
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][ValidateNotNullOrEmpty()][string]$Computer,
        [parameter(Mandatory=$false, Position=1)][int]$Count = 4
    )
    
    [System.Collections.ArrayList]$Response = New-Object System.Collections.ArrayList;
    Write-Verbose "Beginning Ping monitoring of $Computer for $Count tries:";
    While ($Count -gt 0)
    {
        $Ping = Get-WmiObject Win32_PingStatus -Filter "Address = '$Computer'" | Select-Object @{ Label="TimeStamp"; Expression={Get-Date}},@{Label="Source"; Expression={ $_.__Server }},@{Label="Destination"; Expression={ $_.Address }},IPv4Address,@{Label="Status"; Expression={ If ($_.StatusCode -ne 0) {"Failed"} Else {""}}},ResponseTime;
        $Result = $Ping | Select-Object TimeStamp,Source,Destination,IPv4Address,Status,ResponseTime;
        $Response.Add($Result) | Out-Null;
        Write-verbose ($Ping | Select-Object TimeStamp,Source,Destination,IPv4Address,Status,ResponseTime | Format-Table -AutoSize | Out-String);
        $Count --;
        Start-Sleep -Seconds 1;
    }
    return $Response;
}



Function CalculateResponseTime
{
    param
    (
        [parameter(Mandatory=$true, Position=0)][System.Collections.ArrayList]$Pings
    )

    if ($Pings.Count -gt 0)
    {
        $ResponseTime = 0;
        foreach ($Ping in $Pings)
        {
            if ($Ping.ResponseTime -ne $null)
            {
                $ResponseTime = $ResponseTime + $Ping.ResponseTime.ToInt32($null);
            }
            else
            {
                $ResponseTime = $ResponseTime + 99;
            }
        }
        $ResponseTime = $ResponseTime / $Pings.Count;
    }
    else
    {
        $ResponseTime = 99;
    }
    return $ResponseTime;
}
#########################
# End General Functions #
#########################



###############################################
# Validating pre-requisites for installation. #
###############################################
Write-Host "`r`n`r`n";
Write-Host "###############################################";
Write-Host "# Validating pre-requisites for installation. #";
Write-Host "###############################################";
if (-not (Test-ProcessAdminRights))
{
    Write-Host "`r`nERROR: Run Powershell with Administrative Privilegies for install applications." -ForegroundColor Yellow -BackgroundColor Red;
    exit -12345;
}
if ([System.IntPtr]::Size -eq 4)
{
    Write-Host "`r`nERROR: Your OS is 32bits. This script only Run in OS 64bits version." -ForegroundColor Yellow -BackgroundColor Red;
    exit -12345;
}
$PathInstall = $PathInstall.Trim();
ValidatePaths $PathInstall;
if ($PathInstall.Contains(' '))
{
    Write-Host "`r`nERROR: The Path to install application contains spaces. `'$PathInstall`'" -ForegroundColor Yellow -BackgroundColor Red;
    exit -12345;
}
$PathRepository = $PathRepository.Trim();
ValidatePaths $PathRepository;
if ($PathRepository.Contains(' '))
{
    Write-Host "`r`nERROR: The Path to clone repository contains spaces. `'$PathRepository`'" -ForegroundColor Yellow -BackgroundColor Red;
    exit -12345;
}
if ($PathInstall.ToLower() -eq $PathRepository.ToLower())
{
    Write-Host "`r`nERROR: The paths to install the applications and clones the repositories are equals. `'$PathInstall`'" -ForegroundColor Yellow -BackgroundColor Red;
    exit -12345;
}
if ($UseSharedFolder)
{
    $PingAtalanta = Ping-Machine "atalanta" 4;
    if ((CalculateResponseTime $PingAtalanta) -lt 5)
    {
        Write-Host "Using \\atalanta\Temporal\EMantillaS\Xenial to download setup files.";
        $RepositoryLocal = '\\atalanta\Temporal\EMantillaS\Xenial';
    }
    else
    {
        $PingAtlas = Ping-Machine "atlas" 4;
        if ((CalculateResponseTime $PingAtlas) -lt 5)
        {
            Write-Host "Using \\atlas\Temporal\MAguilar\Xenial to download setup files.";
            $RepositoryLocal = '\\atlas\Temporal\MAguilar\Xenial';
        }
        else
        {
            Write-Host "WARNING: The Shared Temporary Folders not are accessible. Will be Download setup files directly from Internet.";
            $UseSharedFolder = $false;
        }
    }
}
$Global:PathAppsTemp = Join-Path $PathInstall 'Temp';
$Global:SevenZip = Join-Path $Env:ProgramFiles '7-Zip\7z.exe';
if (!([System.IO.File]::Exists($Global:SevenZip)))
{
    $Global:SevenZip = Join-Path ${Env:ProgramFiles(x86)} '7-Zip\7z.exe';
    if (!([System.IO.File]::Exists($Global:SevenZip)))
    {
        Write-Host "`r`nERROR: 7Zip no found in $Env:ProgramFiles or ${Env:ProgramFiles(x86)}." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
}
Write-Host "7Zip found at `'$Global:SevenZip`'."
$Global:Msi = (Get-Command "msiexec.exe" -ErrorAction SilentlyContinue).Source;
if ([string]::IsNullOrEmpty($Global:Msi))
{
    Write-Host "`r`nERROR: Microsoft Installer no found in $Env:SystemRoot\System32." -ForegroundColor Yellow -BackgroundColor Red;
    exit -12345;
}
Write-Host "Microsoft Installer found at `'$Global:Msi`'."
$Global:RoboCopy = (Get-Command "robocopy.exe" -ErrorAction SilentlyContinue).Source;
if ([string]::IsNullOrEmpty($Global:RoboCopy))
{
    Write-Host "`r`nERROR: Robocopy.exe no found in $Env:SystemRoot\System32." -ForegroundColor Yellow -BackgroundColor Red;
    exit -12345;
}
PrepareDirectory $PathInstall;
PrepareDirectory $Global:PathAppsTemp;



####################################
# Processing installation of JDK8. #
####################################
Write-Host "`r`n`r`n";
Write-Host "####################################";
Write-Host "# Processing installation of JDK8. #";
Write-Host "####################################";
$Key = Get-UninstallRegistryKey 'Java SE Development Kit 8*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $JavaDir = Join-Path $PathInstall 'Java8';
    $JavaBin = Join-Path $JavaDir 'bin';
    if ($UseSharedFolder)
    {
        $Headers = @{ };
        $UrlFile = $RepositoryLocal + '\jdk-8u162-windows-x64.exe';
    }
    else
    {
        $Headers = @{ 'Cookie' = 'gpw_e24=http://www.oracle.com; oraclelicense=accept-securebackup-cookie' };
        $UrlFile = 'http://download.oracle.com/otn-pub/java/jdk/8u162-b12/0da788060d494f5095bf8624735fa2f1/jdk-8u162-windows-x64.exe';
    }
    $JdkFile = DownloadFile 'jdk-8u162-windows-x64.exe' $UrlFile $Headers;
    $InstallOptions = '/s STATIC=1 ADDLOCAL="ToolsFeature,SourceFeature" INSTALLDIR="' + $JavaDir + '"';
    if (-not ([string]::IsNullOrEmpty($JdkFile)))
    {
        Write-Host "`r`nInstalling JDK8.";
        Start-ProcessInSilentMode $JdkFile $InstallOptions | Out-Null;
        Write-Host "Updating Environment Variables PATH, CLASSPATH and JAVA_HOME.";
        Install-EnvironmentVariablePath $JavaBin 'Machine';
        if ([Environment]::GetEnvironmentVariable('CLASSPATH','Machine') -eq $null)
        {
            Install-EnvironmentVariable 'CLASSPATH' '.;' 'Machine';
        }
        Install-EnvironmentVariable 'JAVA_HOME' $JavaDir 'Machine';
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing JDK8." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
}
else
{
    Write-Host "`r`nJDK8 is already installed.";
}



###########################################
# Processing installation of Android SDK. #
###########################################
Write-Host "`r`n`r`n";
Write-Host "###########################################";
Write-Host "# Processing installation of Android SDK. #";
Write-Host "###########################################";
$AndroidDir = Join-Path $PathInstall 'Android';
PrepareDirectory $AndroidDir;
$AndroidSdkDir = Join-Path $AndroidDir 'Sdk';
PrepareDirectory $AndroidSdkDir;
if ($UseSharedFolder)
{
    $UrlFile = $RepositoryLocal + '\sdk-tools-windows-4333796.zip';
}
else
{
    $UrlFile = 'https://dl.google.com/android/repository/sdk-tools-windows-4333796.zip';
}
if((Get-ChildItem $AndroidSdkDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1 | Measure-Object).Count -eq 0)
{
    $AndroidSdkFile = DownloadFile 'sdk-tools-windows-4333796.zip' $UrlFile;
    if (-not ([string]::IsNullOrEmpty($AndroidSdkFile)))
    {
        Write-Host "`r`nInstalling Android SDK (sdk-tools).";
        UnzipFile $AndroidSdkFile $AndroidSdkDir | Out-Null;
        $NewPath = Join-Path $AndroidSdkDir 'tools';
        if (ExistsPaths $NewPath)
        {
            Write-Host "Updating Environment Variables PATH and ANDROID_HOME.";
            Install-EnvironmentVariablePath $NewPath 'Machine';
            Install-EnvironmentVariable 'ANDROID_HOME' $AndroidSdkDir 'Machine';
        }
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Android SDK." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
    Write-Host "`r`nInstalling Android SDK (platform-tools).";
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\platform-tools-latest-windows.zip';
    }
    else
    {
        $UrlFile = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip';
    }
    $AndroidSdkFile = DownloadFile 'platform-tools-latest-windows.zip' $UrlFile;
    if (-not ([string]::IsNullOrEmpty($AndroidSdkFile)))
    {
        UnzipFile $AndroidSdkFile $AndroidSdkDir | Out-Null;
        $NewPath = Join-Path $AndroidSdkDir 'platform-tools';
        if (ExistsPaths $NewPath)
        {
            Write-Host "Updating Environment Variable PATH.";
            Install-EnvironmentVariablePath $NewPath 'Machine';
        }
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Android SDK." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
    Write-Host "`r`nPreparing User Android Directory.";
    $NewPath = Join-Path $Env:UserProfile '.android';
    PrepareDirectory $NewPath;
    $NewPath = Join-Path $NewPath 'repositories.cfg';
    New-Item -Path $NewPath -ItemType File -Force | Out-Null;
    if (ExistsPaths(Join-Path $AndroidSdkDir 'tools\bin\sdkmanager.bat'))
    {
        $InstallOptions = ' --licenses';
        Write-Host "`r`nAccepting Android licenses.";
        $Command = 'echo y y y y y y y | ' + (Join-Path $AndroidSdkDir 'tools\bin\sdkmanager.bat') + $InstallOptions;
        Write-Host "`r`n >" $Command;
        Invoke-Expression $Command;
        Start-Sleep -S 2;
        Write-Host "`r`nUpdating Android SKD.";
        $TextFile = "patcher;v4", "platform-tools", "extras;intel;Hardware_Accelerated_Execution_Manager", "tools", "emulator", "platforms;android-25", "platforms;android-26",
                    "docs", "extras;google;google_play_services", "extras;google;simulators", "extras;google;usb_driver", "extras;google;webdriver", "build-tools;25.0.3",
                    "build-tools;26.0.3", "extras;google;instantapps", "add-ons;addon-google_apis-google-24", "platforms;android-27", "extras;android;m2repository",
                    "extras;google;m2repository", "build-tools;27.0.3", "system-images;android-27;google_apis;x86", "sources;android-27";
        $Command = Join-Path $AndroidSdkDir 'tools\bin\sdkmanager.bat';
        foreach($Package in $TextFile)
        {
            $PathPackage = $Package.Replace(';','\');
            if (!(ExistsPaths(Join-Path $AndroidSdkDir $PathPackage)))
            {
                $InstallOptions = '--install ' + $Package;
                Start-ProcessInSilentMode $Command $InstallOptions $false | Out-Null;
            }
        }
        $InstallOptions = '--update';
        Start-ProcessInSilentMode $Command $InstallOptions $false | Out-Null;
    }
}
else
{
    Write-Host "`r`nAndroid SDK is already installed.";
}



##############################################
# Processing installation of Android Studio. #
##############################################
Write-Host "`r`n`r`n";
Write-Host "##############################################";
Write-Host "# Processing installation of Android Studio. #";
Write-Host "##############################################";
$Key = Get-UninstallRegistryKey 'Android Studio*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $AndroidStudioDir = $AndroidDir;
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\android-studio-ide-171.4443003-windows.zip';
    }
    else
    {
        $UrlFile = 'https://dl.google.com/dl/android/studio/ide-zips/3.0.1.0/android-studio-ide-171.4443003-windows.zip';
    }
    $AndroidFile = DownloadFile 'android-studio-ide-171.4443003-windows.zip' $UrlFile;
    if (-not ([string]::IsNullOrEmpty($AndroidFile)))
    {
        Write-Host "`r`nInstalling Android Studio.";
        UnzipFile $AndroidFile $AndroidStudioDir | Out-Null;
        $OldPath = Join-Path $AndroidStudioDir 'android-studio';
        $AndroidStudioDir = Join-Path $AndroidStudioDir 'Studio';
        if (!(ExistsPaths $AndroidStudioDir))
        {
            Write-Host "`r`nConfigurating Android Studio.";
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
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Android Studio." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nAndroid Studio is already installed.";
}



######################################
# Processing installation of NodeJs. #
######################################
Write-Host "`r`n`r`n";
Write-Host "######################################";
Write-Host "# Processing installation of NodeJs. #";
Write-Host "######################################";
$Key = Get-UninstallRegistryKey 'Node.js*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $NodeJsDir = Join-Path $PathInstall 'NodeJs';
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\node-v7.0.0-x64.msi';
    }
    else
    {
        $UrlFile = 'https://nodejs.org/dist/v7.0.0/node-v7.0.0-x64.msi';
    }
    $NodeJsFile = DownloadFile 'node-v7.0.0-x64.msi' $UrlFile;
    $InstallOptions = '/i "' + $NodeJsFile + '" INSTALLDIR="' + $NodeJsDir + '" /quiet /qn /norestart /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-NodeJs.log') + '"';
    if (-not ([string]::IsNullOrEmpty($NodeJsFile)))
    {
        Write-Host "`r`nInstalling NodeJs.";
        Start-ProcessInSilentMode $Global:Msi $InstallOptions | Out-Null;
        Update-SessionEnvironment;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing the NodeJs." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
}
else
{
    Write-Host "`r`nNodeJs is already installed.";
}



###################################
# Processing installation of Git. #
###################################
Write-Host "`r`n`r`n";
Write-Host "###################################";
Write-Host "# Processing installation of Git. #";
Write-Host "###################################";
$Key = Get-UninstallRegistryKey 'Git version*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $GitDir = Join-Path $PathInstall 'Git';
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\Git-2.16.1.4-64-bit.exe';
    }
    else
    {
        $UrlFile = 'https://github.com/git-for-windows/git/releases/download/v2.16.1.windows.4/Git-2.16.1.4-64-bit.exe';
    }
    $GitFile = DownloadFile 'Git-2.16.1.4-64-bit.exe' $UrlFile;
    $InstallOptions = '/verysilent /suppressmsgboxes /norestart /nocancel /sp- /closeapplications /restartapplications /components="icons,assoc,assoc_sh,ext,ext\shellhere,ext\guihere,icons\quicklaunch" /DIR="' + $GitDir + '" /LOG="' + (Join-Path $Global:PathAppsTemp '\Install-Git.log') + '"';
    if (-not ([string]::IsNullOrEmpty($GitFile)))
    {
        Write-Host "`r`nInstalling Git.";
        Start-ProcessInSilentMode $GitFile $InstallOptions | Out-Null;
        Update-SessionEnvironment;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Git." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
}
else
{
    Write-Host "`r`nGit is already installed.";
}



##########################################
# Processing installation of SourceTree. #
##########################################
Write-Host "`r`n`r`n";
Write-Host "##########################################";
Write-Host "# Processing installation of SourceTree. #";
Write-Host "##########################################";
$Key = Get-UninstallRegistryKey 'SourceTree*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\SourceTreeSetup-2.4.7.0.exe';
    }
    else
    {
        $UrlFile = 'https://downloads.atlassian.com/software/sourcetree/windows/ga/SourceTreeSetup-2.4.7.0.exe';
    }
    $SourceTreeFile = DownloadFile 'SourceTreeSetup-2.4.7.0.exe' $UrlFile;
    $InstallOptions = '/passive';
    if (-not ([string]::IsNullOrEmpty($SourceTreeFile)))
    {
        Write-Host "`r`nInstalling SourceTree.";
        Start-ProcessInSilentMode $SourceTreeFile $InstallOptions | Out-Null;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing SourceTree." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nSourceTree is already installed.";
}



#########################################################################
# Processing installation of Microsoft Visual C++ Redistributable 2013. #
#########################################################################
Write-Host "`r`n`r`n";
Write-Host "#########################################################################";
Write-Host "# Processing installation of Microsoft Visual C++ Redistributable 2013. #";
Write-Host "#########################################################################";
$Key = Get-UninstallRegistryKey 'Microsoft Visual C++ 2013 Redistributable*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\vcredist_x64.exe';
    }
    else
    {
        $UrlFile = 'http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe';
    }
    $VCFile = DownloadFile 'vcredist_x64.exe' $UrlFile;
    $InstallOptions = '/install /quiet /norestart /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-VCRedist.log') + '"';
    if (-not ([string]::IsNullOrEmpty($VCFile)))
    {
        Write-Host "`r`nInstalling Microsoft Visual C++ Redistributable 2013.";
        Start-ProcessInSilentMode $VCFile $InstallOptions | Out-Null;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Microsoft Visual C++ Redistributable 2013." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nMicrosoft Visual C++ Redistributable 2013 is already installed.";
}



#######################################
# Processing installation of Python3. #
#######################################
Write-Host "`r`n`r`n";
Write-Host "#######################################";
Write-Host "# Processing installation of Python3. #";
Write-Host "#######################################";
$Key = Get-UninstallRegistryKey 'Python 3.5.4 (64-bit)*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $PythonDir = Join-Path $PathInstall 'Python3';
    PrepareDirectory $PythonDir;
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\python-3.5.4-amd64.exe';
    }
    else
    {
        $UrlFile = 'https://www.python.org/ftp/python/3.5.4/python-3.5.4-amd64.exe';
    }
    $PythonFile = DownloadFile 'python-3.5.4-amd64.exe' $UrlFile;
    $InstallOptions = '/quiet InstallAllUsers=0 PrependPath=1 TargetDir="' + $PythonDir + '"';
    if (-not ([string]::IsNullOrEmpty($PythonFile)))
    {
        Write-Host "`r`nInstalling Python3.";
        Start-ProcessInSilentMode $PythonFile $InstallOptions | Out-Null;
        Update-SessionEnvironment;
        if (ExistsPaths $PythonDir)
        {
            Write-Host "Updating Environment Variable PATH.";
            Install-EnvironmentVariablePath $PythonDir 'Machine';
            $NewPath = Join-Path $PythonDir 'Scripts';
            Install-EnvironmentVariablePath $NewPath 'Machine';
            Write-Host "`r`nInstalling Pip.";
            if ($UseSharedFolder)
            {
                $UrlFile = $RepositoryLocal + '\get-pip.py';
            }
            else
            {
                $UrlFile = 'https://bootstrap.pypa.io/get-pip.py';
            }
            $PipFile = DownloadFile 'get-pip.py' $UrlFile;
            if (-not ([string]::IsNullOrEmpty($PipFile)))
            {
                Write-Host "`r`n > python $PipFile";
                Invoke-Expression "python $PipFile";
                Write-Host "`r`n > python -m pip install -U pip";
                Invoke-Expression "python -m pip install -U pip";
            }
            else
            {
                Write-Host "`r`nERROR: An error occurred when installing Pip." -ForegroundColor Yellow -BackgroundColor Red;
                exit -12345;
            }
        }
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Python3." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
}
else
{
    Write-Host "`r`nPython is already installed.";
}



##################################################
# Processing installation of Visual Studio Code. #
##################################################
Write-Host "`r`n`r`n";
Write-Host "##################################################";
Write-Host "# Processing installation of Visual Studio Code. #";
Write-Host "##################################################";
$Key = Get-UninstallRegistryKey 'Microsoft Visual Studio Code*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $VSCodeDir = Join-Path $PathInstall 'VSCode';
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\VSCodeSetup-x64-1.20.0.exe';
    }
    else
    {
        $UrlFile = 'https://az764295.vo.msecnd.net/stable/c63189deaa8e620f650cc28792b8f5f3363f2c5b/VSCodeSetup-x64-1.20.0.exe';
    }
    $VSCodeFile = DownloadFile 'VSCodeSetup-x64-1.20.0.exe' $UrlFile;
    $InstallOptions = '/verysilent /suppressmsgboxes /closeapplications /restartapplications /mergetasks="!runCode, desktopicon, quicklaunchicon, addcontextmenufiles, !addcontextmenufolders, addtopath" /DIR="' + $VSCodeDir + '" /LOG="' + (Join-Path $Global:PathAppsTemp '\Install-VSCode.log') + '"';
    if (-not ([string]::IsNullOrEmpty($VSCodeFile)))
    {
        Write-Host "`r`nInstalling Visual Studio Code.";
        Start-ProcessInSilentMode $VSCodeFile $InstallOptions | Out-Null;
        Update-SessionEnvironment;
        $Command = (Get-Command "code.cmd" -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrEmpty($Command))
        {
            Write-Host "`r`nERROR: code.cmd no found in $VSCodeDir\bin." -ForegroundColor Yellow -BackgroundColor Red;
        }
        Write-Host "Adding Visual Studio Code Extensions.";
        $TextFile = "ms-python.python", "ms-vscode.csharp", "PeterJausovec.vscode-docker", "formulahendry.docker-explorer", "ms-azuretools.vscode-cosmosdb",
                    "ms-vscode.powershell", "ms-vscode.cpptools";
        foreach($Extension in $TextFile)
        {
            $InstallOptions = '--install-extension ' + $Extension;
            Start-ProcessInSilentMode $Command $InstallOptions | Out-Null;
        }
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Visual Studio Code." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nVisual Studio Code is already installed.";
}



#######################################
# Processing installation of PyCharm. #
#######################################
Write-Host "`r`n`r`n";
Write-Host "#######################################";
Write-Host "# Processing installation of PyCharm. #";
Write-Host "#######################################";
$Key = Get-UninstallRegistryKey 'JetBrains PyCharm Community Edition*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $PyCharmDir = Join-Path $PathInstall 'PyCharm';
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\pycharm-community-2017.3.3.exe';
    }
    else
    {
        $UrlFile = 'https://download.jetbrains.com/python/pycharm-community-2017.3.3.exe';
    }
    $PyCharmFile = DownloadFile 'pycharm-community-2017.3.3.exe' $UrlFile;
    if (-not ([string]::IsNullOrEmpty($PyCharmFile)))
    {
        $TextFile = "mode=admin", "launcher32=0", "launcher64=1", "jre32=0", ".py=1" -Join "`n" | Out-File -Encoding ASCII ($Global:PathAppsTemp + "\silent.config");
        $InstallOptions = '/S /CONFIG="' + $Global:PathAppsTemp + '\silent.config" /D=' + $PyCharmDir;
        Write-Host "`r`nInstalling PyCharm.";
        Start-ProcessInSilentMode $PyCharmFile $InstallOptions | Out-Null;
        Update-SessionEnvironment;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing PyCharm." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nPyCharm is already installed.";
}


######################################
# Processing installation of Appium. #
######################################
Write-Host "`r`n`r`n";
Write-Host "######################################";
Write-Host "# Processing installation of Appium. #";
Write-Host "######################################";
$Key = Get-UninstallRegistryKey 'Appium *' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $AppiumDir = Join-Path $PathInstall 'Appium';
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\Appium.Setup.1.3.2.exe';
    }
    else
    {
        $UrlFile = 'https://github.com/appium/appium-desktop/releases/download/v1.3.2/Appium.Setup.1.3.2.exe';
    }
    $AppiumFile = DownloadFile 'Appium.Setup.1.3.2.exe' $UrlFile;
    if (-not ([string]::IsNullOrEmpty($AppiumFile)))
    {
        $InstallOptions = '/NCRC /S /D=' + $AppiumDir;
        Write-Host "`r`nInstalling Appium.";
        Start-ProcessInSilentMode $AppiumFile $InstallOptions | Out-Null;
        $OldPath = Join-Path $Env:LocalAppData 'Programs\appium-desktop';
        Start-ProcessInSilentMode $Global:RoboCopy "`"$OldPath`" `"$AppiumDir`" /e /move /np" $false | Out-Null;
        Install-EnvironmentVariablePath $AppiumDir 'User';
        Update-UnInstallPath 'Appium' 'DisplayIcon' $OldPath $AppiumDir;
        Update-UnInstallPath 'Appium' 'UninstallString' $OldPath $AppiumDir;
        $Key = (Get-UninstallRegistryKey 'Appium*' -WarningAction SilentlyContinue).PSChildName;
        if (![string]::IsNullOrEmpty($Key))
        {
            Set-ItemProperty -Path "HKCU:\Software\$Key" -Name "InstallLocation" -Value $AppiumDir
        }
        $AppiumExe = $AppiumDir + '\Appium.exe';
        $DesktopPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Appium.lnk";
        Install-Shortcut -ShortcutFilePath $DesktopPath -TargetPath $AppiumExe -IconLocation $AppiumExe;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Appium." -ForegroundColor Yellow -BackgroundColor Red;
        exit -12345;
    }
}
else
{
    Write-Host "`r`nAppium is already installed.";
}



#######################################
# Processing installation of MongoDb. #
#######################################
Write-Host "`r`n`r`n";
Write-Host "#######################################";
Write-Host "# Processing installation of MongoDb. #";
Write-Host "#######################################";
$Key = Get-UninstallRegistryKey 'MongoDB *' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $MongoDir = Join-Path $PathInstall 'MongoDb';
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\mongodb-win32-x86_64-2008plus-ssl-3.6.2-signed.msi';
    }
    else
    {
        $UrlFile = 'https://fastdl.mongodb.org/win32/mongodb-win32-x86_64-2008plus-ssl-3.6.2-signed.msi';
    }
    $MongoFile = DownloadFile 'mongodb-win32-x86_64-2008plus-ssl-3.6.2-signed.msi' $UrlFile;
    if (-not ([string]::IsNullOrEmpty($MongoFile)))
    {
        $InstallOptions = '/q /i "' + $MongoFile + '" INSTALLLOCATION="' + $MongoDir + '" ADDLOCAL="All" /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-MongoDb.log') + '"';
        Write-Host "`r`nInstalling MongoDb.";
        Start-ProcessInSilentMode $Global:Msi $InstallOptions | Out-Null;
        $MongoExe = Join-Path $MongoDir 'bin\mongod.exe';
        if (ExistsPaths $MongoExe)
        {
            Write-Host "Configurating MongoDb.";
            $DatabaseDir = Join-Path $MongoDir 'databases';
            PrepareDirectory $DatabaseDir;
            $LogDir = Join-Path $MongoDir 'logs';
            PrepareDirectory $LogDir;
            $NewPath = Join-Path $MongoDir 'bin';
            Install-EnvironmentVariablePath $NewPath 'Machine';            
            $TextFile = "systemLog:", "    destination: file", "    path: $LogDir\mongod.log", "storage:", "    dbPath: $DatabaseDir" -Join "`n" | Out-File -Encoding ASCII ($MongoDir + "\bin\mongod.cfg");
            $InstallOptions = '--config "' + $MongoDir + '\bin\mongod.cfg" --install';
            Start-ProcessInSilentMode $MongoExe $InstallOptions | Out-Null;
            Write-Host "Initializing Service MongoDb.";
            Start-ProcessInSilentMode "net" "start MongoDB" $true | Out-Null;
        }
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing MongoDb." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nMongoDb is already installed.";
}



######################################
# Processing installation of Docker. #
######################################
Write-Host "`r`n`r`n";
Write-Host "######################################";
Write-Host "# Processing installation of Docker. #";
Write-Host "######################################";
$Key = Get-UninstallRegistryKey 'Docker for Windows*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    $DockerDir = Join-Path $PathInstall 'Docker';
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\Docker for Windows Installer.exe';
    }
    else
    {
        $UrlFile = 'https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe';
    }
    $DockerFile = DownloadFile 'Docker for Windows Installer.exe' $UrlFile;
    $InstallOptions = 'install --quiet';
    if (-not ([string]::IsNullOrEmpty($DockerFile)))
    {
        Write-Host "`r`nInstalling Docker.";
        Start-ProcessInSilentMode $DockerFile $InstallOptions | Out-Null;
        Update-SessionEnvironment;
        $OldPath = Join-Path $Env:ProgramFiles 'Docker\Docker'
        if (ExistsPaths $OldPath)
        {
            $ServiceName = 'com.docker.service';
            if (ExistsService $ServiceName)
            {
                Write-Host "Stoping the Windows Service '$ServiceName'.";
                Stop-Service -Name $ServiceName -Force;
                While ((Get-Service $ServiceName).Status -ne "Stopped")
                {
                    Write-Host "Waiting for service '$ServiceName' to stop.";
                    Start-Sleep -S 3;
                }
            }
            Write-Host "Moving Docker to '$DockerDir'.";
            $ParentDir = (Get-Item $OldPath).Parent.FullName;
            Start-ProcessInSilentMode $Global:RoboCopy "`"$OldPath`" `"$DockerDir`" /e /move /np" $false | Out-Null;
            Remove-Item -Recurse -Force $ParentDir | Out-Null;
            Write-Host "Adjusting the Windows Service '$ServiceName'.";
            $NewPath = Join-Path $DockerDir $ServiceName;
            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\$ServiceName" -Name "ImagePath" -Value $NewPath
            Write-Host "Starting the Windows Service '$ServiceName'.";
            Start-Service -Name $ServiceName;
            Write-Host "Adjusting the Windows Registry and Environment Variables.";
            Update-UnInstallPath 'Docker for Windows' 'DisplayIcon' $OldPath $DockerDir;
            Update-UnInstallPath 'Docker for Windows' 'InstallLocation' $OldPath $DockerDir;
            Update-UnInstallPath 'Docker for Windows' 'UninstallString' $OldPath $DockerDir;
            $BinPath = Join-Path $OldPath 'Resources\bin'
            UnInstall-EnvironmentVariablePath $BinPath 'Machine';
            $BinPath = Join-Path $DockerDir 'Resources\bin'
            Install-EnvironmentVariablePath $BinPath 'Machine';
            $DockerExe = Join-Path $DockerDir 'Docker for Windows.exe';
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Docker for Windows" -Value $DockerExe
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Docker Inc.\Docker\1.0" -Name "AppPath" -Value $DockerDir
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Docker Inc.\Docker\1.0" -Name "BinPath" -Value $BinPath
            $DesktopPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Docker for Windows.lnk";
            Install-Shortcut -ShortcutFilePath $DesktopPath -TargetPath $DockerExe -IconLocation $DockerExe;
            Write-Host "Enabling the Hiper-V.";
            $Command = (Get-Command "dism.exe" -ErrorAction SilentlyContinue).Source
            if ([string]::IsNullOrEmpty($Command))
            {
                Write-Host "`r`nERROR: dism.exe no found in $Env:SystemRoot\System32." -ForegroundColor Yellow -BackgroundColor Red;
            }
            else
            {
                Write-Host "`r`n >$Command /Online /Enable-Feature:Microsoft-Hyper-V /All /NoRestart";
                Invoke-Expression "$Command /Online /Enable-Feature:Microsoft-Hyper-V /All /NoRestart";
            }
            $Command = (Get-Command "bcdedit.exe" -ErrorAction SilentlyContinue).Source
            if ([string]::IsNullOrEmpty($Command))
            {
                Write-Host "`r`nERROR: bcdedit.exe no found in $Env:SystemRoot\System32." -ForegroundColor Yellow -BackgroundColor Red;
            }
            else
            {
                Write-Host "`r`n > $Command /set hypervisorlaunchtype auto";
                Invoke-Expression "$Command /set hypervisorlaunchtype auto";
            }
        }
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Docker." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nDocker is already installed.";
}


##################################################
# Processing installation of Sysinternals Suite. #
##################################################
Write-Host "`r`n`r`n";
Write-Host "#################################################";
Write-Host "# Processing installation of Sysinternals Suite #";
Write-Host "#################################################";
$Key = 'HKCU:\SOFTWARE\Sysinternals';
if ($UseSharedFolder)
{
    $UrlFile = $RepositoryLocal + '\SysinternalsSuite.zip';
}
else
{
    $UrlFile = 'https://download.sysinternals.com/files/SysinternalsSuite.zip';
}
$SysinternalsFile = DownloadFile 'SysinternalsSuite.zip' $UrlFile;
if (-not ([string]::IsNullOrEmpty($SysinternalsFile)))
{
    $SysinternalsDir = Join-Path $PathInstall 'Sysinternals';
    PrepareDirectory $SysinternalsDir;
    Write-Host "`r`nInstalling Sysinternals Suite.";
    UnzipFile $SysinternalsFile $SysinternalsDir | Out-Null;
    if (ExistsPaths $SysinternalsDir)
    {
        Write-Host "`r`nConfigurating Sysinternals Suite.";
        $Tools = "AccessChk", "Active Directory Explorer", "ADInsight", "Autologon", "AutoRuns", "BGInfo", "CacheSet", "ClockRes",
                 "Coreinfo", "Ctrl2cap", "DbgView", "Desktops", "Disk2Vhd", "Diskmon", "DiskView", "Du", "EFSDump", "FindLinks",
                 "Handle", "Hex2Dec", "Junction", "LdmDump", "ListDLLs", "LoadOrder", "Movefile", "PageDefrag", "PendMove",
                 "PipeList", "Portmon", "ProcDump", "Process Explorer", "Process Monitor", "PsExec", "psfile", "PsGetSid", "PsInfo",
                 "PsKill", "PsList", "PsLoggedon", "PsLoglist", "PsPasswd", "PsService", "PsShutdown", "PsSuspend", "RamMap", "RegDelNull",
                 "Regjump", "Regsize", "RootkitRevealer", "Share Enum", "ShellRunas", "SigCheck", "Streams", "Strings", "Sync",
                 "System Monitor", "TCPView", "VMMap", "VolumeID", "Whois", "Winobj", "ZoomIt";
        New-Item -Path $Key -ErrorAction SilentlyContinue | Out-Null;
        Foreach ($Tool in $Tools)
        {
            $NewKey = Join-Path $Key $Tool;
            New-Item -Path $NewKey -ErrorAction SilentlyContinue | Out-Null;
            New-ItemProperty -Path $NewKey -Name EulaAccepted -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null;
        } 
        $NewKey = Join-Path $Key "\SigCheck\VirusTotal";
        New-Item -Path $NewKey -ErrorAction SilentlyContinue | Out-Null;
        New-ItemProperty -Path $NewKey -Name VirusTotalTermsAccepted -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null;
        Install-EnvironmentVariablePath $SysinternalsDir 'Machine';
    }
}
else
{
    Write-Host "`r`nERROR: An error occurred when installing Sysinternals Suite." -ForegroundColor Yellow -BackgroundColor Red;
}



#####################################
# Processing installation of Vysor. #
#####################################
Write-Host "`r`n`r`n";
Write-Host "#####################################";
Write-Host "# Processing installation of Vysor. #";
Write-Host "#####################################";
$Key = Get-UninstallRegistryKey 'Vysor*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\Vysor-win32-ia32.exe';
    }
    else
    {
        $UrlFile = 'https://vysornuts.clockworkmod.com/download/win32';
    }
    $VysorFile = DownloadFile 'Vysor-win32-ia32.exe' $UrlFile;
    $InstallOptions = '/passive';
    if (-not ([string]::IsNullOrEmpty($VysorFile)))
    {
        Write-Host "`r`nInstalling Vysor.";
        Start-ProcessInSilentMode $VysorFile $InstallOptions | Out-Null;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Vysor." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nVysor is already installed.";
}



####################################################
# Processing installation of Universal Adb Driver. #
####################################################
Write-Host "`r`n`r`n";
Write-Host "####################################################";
Write-Host "# Processing installation of Universal Adb Driver. #";
Write-Host "####################################################";
$Key = Get-UninstallRegistryKey 'Universal Adb Driver*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\UniversalAdbDriverSetup.msi';
    }
    else
    {
        $UrlFile = 'http://download.clockworkmod.com/test/UniversalAdbDriverSetup.msi';
    }
    $AdbDriverFile = DownloadFile 'UniversalAdbDriverSetup.msi' $UrlFile;
    if (-not ([string]::IsNullOrEmpty($AdbDriverFile)))
    {
        Write-Host "`r`nInstalling Universal AdbDriver.";
        $InstallOptions = '/i "' + $AdbDriverFile + '" /quiet /qn /norestart /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-UniversalAdbDriver.log') + '"';
        Start-ProcessInSilentMode $Global:Msi $InstallOptions | Out-Null;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing Universal AdbDriver." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nUniversal AdbDriver is already installed.";
}



######################################
# Processing installation of ConEmu. #
######################################
Write-Host "`r`n`r`n";
Write-Host "######################################";
Write-Host "# Processing installation of ConEmu. #";
Write-Host "######################################";
$Key = Get-UninstallRegistryKey 'ConEmu*' -WarningAction SilentlyContinue;
if ($Key -eq $null)
{
    if ($UseSharedFolder)
    {
        $UrlFile = $RepositoryLocal + '\ConEmuSetup.180309.exe';
    }
    else
    {
        $UrlFile = 'https://github.com/Maximus5/ConEmu/releases/download/v18.03.09/ConEmuSetup.180309.exe';
    }
    $ConEmuFile = DownloadFile 'ConEmuSetup.180309.exe' $UrlFile;
    $ConEmuDir = Join-Path $PathInstall 'ConEmu'
    if (-not ([string]::IsNullOrEmpty($ConEmuFile)))
    {
        Write-Host "`r`nInstalling ConEmu.";
        $InstallOptions = '/p:x64,adm /quiet /qn /norestart APPLICATIONFOLDER="' + $ConEmuDir + '" /l*v "' + (Join-Path $Global:PathAppsTemp '\Install-ConEmu.log') + '"';
        Start-ProcessInSilentMode $ConEmuFile $InstallOptions | Out-Null;
    }
    else
    {
        Write-Host "`r`nERROR: An error occurred when installing ConEmu." -ForegroundColor Yellow -BackgroundColor Red;
    }
}
else
{
    Write-Host "`r`nConEmu is already installed.";
}



################################################
# Cloning Repository 'tea-data-management-ui'. #
################################################
Write-Host "`r`n`r`n";
Write-Host "################################################";
Write-Host "# Cloning Repository 'tea-data-management-ui'. #";
Write-Host "################################################";
PrepareDirectory $PathRepository;
$RepositoryName = 'tea-data-management-ui';
if (ExistsPaths $PathRepository)
{
    Push-Location -Path $PathRepository;
    $RepoDir = Join-Path $PathRepository $RepositoryName;
    if((Get-ChildItem $RepoDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1 | Measure-Object).Count -eq 0)
    {
        $Command = "git";
        $InstallOptions = 'clone https://bit.heartlandcommerce.com/scm/hc/' + $RepositoryName + '.git';
        Write-Host "`r`n >" $Command $InstallOptions
        Invoke-Expression "$Command $InstallOptions";
    }
    if (ExistsPaths $RepoDir)
    {
        Push-Location -Path $RepoDir;
        $Command = 'pip install virtualenv';
        Write-Host "`r`n >" $Command;
        Invoke-Expression $Command;
        $Command = 'virtualenv ENV';
        Write-Host "`r`n >" $Command;
        Invoke-Expression $Command;
        $Command = Join-Path $RepoDir 'ENV\Scripts\activate.bat | pip install -r requirements.txt';
        Write-Host "`r`n >" $Command;
        Invoke-Expression $Command;
        Pop-Location;
    }
    Pop-Location;
}


#####################################
# Cloning Repository 'tea-pos-app'. #
#####################################
Write-Host "`r`n`r`n";
Write-Host "#####################################";
Write-Host "# Cloning Repository 'tea-pos-app'. #";
Write-Host "#####################################";
PrepareDirectory $PathRepository;
$RepositoryName = 'tea-pos-app';
if (ExistsPaths $PathRepository)
{
    Push-Location -Path $PathRepository;
    $RepoDir = Join-Path $PathRepository $RepositoryName;
    if((Get-ChildItem $RepoDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1 | Measure-Object).Count -eq 0)
    {
        $Command = "git";
        $InstallOptions = 'clone https://bit.heartlandcommerce.com/scm/hc/' + $RepositoryName + '.git';
        Write-Host "`r`n >" $Command $InstallOptions
        Invoke-Expression "$Command $InstallOptions";
    }
    if (ExistsPaths $RepoDir)
    {
        Push-Location -Path $RepoDir;
        $Command = 'pip install virtualenv';
        Write-Host "`r`n >" $Command;
        Invoke-Expression $Command;
        $Command = 'virtualenv ENV';
        Write-Host "`r`n >" $Command;
        Invoke-Expression $Command;
        $Command = Join-Path $RepoDir 'ENV\Scripts\activate.bat | pip install -r requirements.txt';
        Write-Host "`r`n >" $Command;
        Invoke-Expression $Command;
        Pop-Location;
    }
    Pop-Location;
}
