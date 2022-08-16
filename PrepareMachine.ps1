Param
(
    [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$PackagesPath,
    [string]$InstallAppsPath = [string]::Empty
)

#####################
# General Functions #
#####################
# Validate if the Path is valid
function Validate-Paths([string]$PathToValidate)
{
    if ([string]::IsNullOrEmpty($PathToValidate))
    {
        Write-Host "Failed" -ForegroundColor Red;
        Write-Host "ERROR: Path parameter is null or empty." -ForegroundColor Yellow -BackgroundColor Red;
        exit 12345;
    }
    if (-not (Test-Path -IsValid $PathToValidate))
    {
        Write-Host "Failed" -ForegroundColor Red;
        Write-Host "ERROR: $PathValidate not is a path valid." -ForegroundColor Yellow -BackgroundColor Red;
        exit 12345;
    }
}


# Validate if the Path exist in the system
function Exist-Paths([string]$PathToValidate)
{
    if (-not (Test-Path -Path "$PathToValidate"))
    {
        Write-Host "Failed" -ForegroundColor Red;
        Write-Host "ERROR: $PathToValidate not found in the system." -ForegroundColor Yellow -BackgroundColor Red;
        exit 12345;
    }
}


# Validate if errors are present and print them
function Validate-Errors([bool]$PrintIfFailed = $true)
{
    if ($Global:Errors.Count -gt 0)
    {
        if ($PrintIfFailed -eq $true)
        {
            Write-Host "Failed" -ForegroundColor Red;
        }
        $Global:Errors | Format-List | Out-String | %{Write-Host $_ -ForegroundColor Yellow -BackgroundColor Red};
        exit 12345;
    }
    $Global:Errors.Clear() > $null;
}


# Check for Load or Parse errors when loading the XML file
function Test-XMLFile([string]$XmlFilePath)
{
    try
    {
        [System.Xml.XmlDocument]$XmlFile = New-Object System.Xml.XmlDocument;
        $XmlFile.Load((Get-ChildItem -Path "$XmlFilePath").FullName);
        return $true;
    }
    catch [System.Xml.XmlException]
    {
        return $false;
    }
}


#Obtaint the short path for any path file or folder
function Get-ShortPath([string]$PathFile)
{
    $FileSystem = New-Object -ComObject Scripting.FileSystemObject;
    [string]$ShortPath = [string]::Empty;
    if ($FileSystem.FileExists($PathFile) -eq $true)
    {
        $FileInfo = $FileSystem.GetFile($PathFile);
        [string]$ShortPath = $FileInfo.ShortPath;
    }
    else
    {
        if ($FileSystem.FolderExists($PathFile) -eq $true)
        {
            $FileInfo = $FileSystem.GetFolder($PathFile);
            [string]$ShortPath = $FileInfo.ShortPath;
        }
    }
    return $ShortPath;
}


# Install Package Manager Chocolotey
function Install-Chocolatey
{
    Write-Host "The package manager Chocolatey is not installed.";
    Write-Host "`r`nInstalling Chocolatey in the system.`r`n";
    Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue -ErrorVariable Errors;
    Validate-Errors($false);
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction SilentlyContinue -ErrorVariable Errors;
    Validate-Errors($false);
}


# Uninstall Package Manager Chocolotey
function Uninstall-Chocolatey
{
    Write-Host "`r`nUninstalling Chocolatey of the system... " -NoNewline;
    if ($Env:ChocolateyInstall -ne '' -and $Env:ChocolateyInstall -ne $null)
    {
        if (Test-Path -IsValid "$Env:ChocolateyInstall")
        {
            if (Test-Path -Path "$Env:ChocolateyInstall")
            {
                Remove-Item -Recurse -Force "$Env:ChocolateyInstall";
            }
        }
        [System.Environment]::SetEnvironmentVariable("ChocolateyInstall", $null, [System.EnvironmentVariableTarget]::Machine);
    }
    [System.Text.RegularExpressions.Regex]::Replace([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment').GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames).ToString(), [System.Text.RegularExpressions.Regex]::Escape("$Env:ChocolateyInstall\bin") + '(?>;)?', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | %{[System.Environment]::SetEnvironmentVariable('PATH', $_, 'User')};
    [System.Text.RegularExpressions.Regex]::Replace([Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment\').GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames).ToString(),  [System.Text.RegularExpressions.Regex]::Escape("$Env:ChocolateyInstall\bin") + '(?>;)?', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | %{[System.Environment]::SetEnvironmentVariable('PATH', $_, 'Machine')};
    if ($Env:ChocolateyBinRoot -ne '' -and $Env:ChocolateyBinRoot -ne $null)
    {
        Remove-Item -Recurse -Force "$Env:ChocolateyBinRoot";
    }
    if ($Env:ChocolateyToolsRoot -ne '' -and $Env:ChocolateyToolsRoot -ne $null)
    {
        Remove-Item -Recurse -Force "$Env:ChocolateyToolsRoot";
    }
    [System.Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $null, [System.EnvironmentVariableTarget]::User);
    [System.Environment]::SetEnvironmentVariable("ChocolateyToolsLocation", $null, [System.EnvironmentVariableTarget]::User);
    Write-Host "Done" -ForegroundColor Green;
}


#Delete the Path from Environment Variables
function UnInstall-ChocolateyPath([string] $PathToUnInstall, [System.EnvironmentVariableTarget] $PathType = [System.EnvironmentVariableTarget]::User)
{
    Write-Host "Running 'UnInstall-ChocolateyPath' with pathToUnInstall:`'$PathToUnInstall`'";
    $OriginalPathToUnInstall = $PathToUnInstall;

    #Get the PATH variable
    $EnvPath = $Env:PATH;
    if ($EnvPath.ToLower().Contains($PathToUnInstall.ToLower()))
    {
        $StatementTerminator = ";";
        Write-Host "PATH environment variable contains $PathToUnInstall. Removing...";
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
                $PsArgs = "UnInstall-ChocolateyPath -pathToUnInstall `'$OriginalPathToUnInstall`' -pathType `'$PathType`'";
                Start-ChocolateyProcessAsAdmin "$PsArgs";
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


#Update the path from Uninstall Package
function Update-UnInstallPath([string] $DisplayName, [string] $PropertyName, [string] $OldValue, [string] $NewValue )
{
    [string]$DisplayNameRex = [System.String]::Concat($DisplayName, '*');
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


[System.Collections.ArrayList]$Global:Errors = New-Object System.Collections.ArrayList;


########################################
# Verifying if Chocolatey is installed #
########################################
Write-Host "Verifying if Chocolatey is installed... " -NoNewline;
[string]$ChocolateyDir = $Env:ChocolateyInstall;
if ($ChocolateyDir)
{
    $ChocolateyDir = $ChocolateyDir.Trim();
}
if ([string]::IsNullOrEmpty($ChocolateyDir))
{
    Write-Host "Failed" -ForegroundColor Red;
    Install-Chocolatey;
    [string]$ChocolateyDir = $Env:ChocolateyInstall;
    if ($ChocolateyDir)
    {
        $ChocolateyDir = $ChocolateyDir.Trim();
    }
    if ([string]::IsNullOrEmpty($ChocolateyDir))
    {
        Write-Host "Failed" -ForegroundColor Red;
        Write-Host "System environment variable (ChocolateyInstall) not set." -ForegroundColor Yellow -BackgroundColor Red;
        exit 12345;
    }
}
Validate-Paths($ChocolateyDir);
if (-not (Test-Path -Path "$ChocolateyDir"))
{
    Write-Host "Failed" -ForegroundColor Red;
    Install-Chocolatey;
    [string]$ChocolateyDir = $Env:ChocolateyInstall;
    if ($ChocolateyDir)
    {
        $ChocolateyDir = $ChocolateyDir.Trim();
    }
    if ([string]::IsNullOrEmpty($ChocolateyDir))
    {
        Write-Host "Failed" -ForegroundColor Red;
        Write-Host "System environment variable (ChocolateyInstall) not set." -ForegroundColor Yellow -BackgroundColor Red;
        exit 12345;
    }
}
else
{
    Write-Host "Done" -ForegroundColor Green;
}
Write-Host "Chocolatey Directory: $ChocolateyDir";
Write-Host "`r`n`r`nVerifying Chocolatey executable path... " -NoNewline;
[string]$ChocolateyPath = Join-Path $ChocolateyDir "choco.exe";
Validate-Paths($ChocolateyPath);
if (-not (Test-Path -Path "$ChocolateyPath"))
{
    Write-Host "Failed" -ForegroundColor Red;
    Install-Chocolatey;
    [string]$ChocolateyPath = Join-path $ChocolateyDir "choco.exe";
    if (-not (Test-Path -Path "$ChocolateyPath"))
    {
        Write-Host "Failed" -ForegroundColor Red;
        Write-Host "Chocolatey executable not found." -ForegroundColor Yellow -BackgroundColor Red;
        exit 12345;
    }
}
else
{
    Write-Host "Done" -ForegroundColor Green;
    Write-Host $ChocolateyPath;
}
[string]$PathMachine = Join-Path $ChocolateyDir 'helpers\chocolateyInstaller.psm1';
Import-Module $PathMachine;


##########################################
# Obtaining required Chocolatey Packages #
##########################################
Write-Host "`r`n`r`nObtaining required Chocolatey Packages... " -NoNewline;
[System.Collections.ArrayList]$PackagesRequired = New-Object System.Collections.ArrayList;
if ($PackagesPath)
{
    $PackagesPath = $PackagesPath.Trim();
}
if (-not ([string]::IsNullOrEmpty($PackagesPath)))
{
    Validate-Paths($PackagesPath);
    Exist-Paths($PackagesPath);
    [string]$FileExtension = (Get-Item "$PackagesPath").Extension;
    if ($FileExtension)
    {
        $FileExtension = $FileExtension.Trim().ToLower();
    }
    if ([string]::IsNullOrEmpty($FileExtension) -or $FileExtension -ne ".xml" -or -not (Test-XMLFile($PackagesPath)))
    {
        Write-Host "Failed" -ForegroundColor Red;
        Write-Host "ERROR: $PackagesPath not is a Packages Configuration (.xml) File." -ForegroundColor Yellow -BackgroundColor Red;
        exit 12345;
    }
    Select-Xml -Path "$PackagesPath" -XPath "/packages/package" -ErrorAction SilentlyContinue -ErrorVariable Errors | `
        ForEach `
        {
            if ($_.Node.Id)
            {
                New-Object PSObject -Property @{
                    Id = $_.Node.Id.Trim();
                    Version = if ($_.Node.Version) { $_.Node.Version.Trim(); } else { "0.0.0"; };
                    DisplayName = if ($_.Node.DisplayName) { $_.Node.DisplayName.Trim(); } else { $_.Node.Id.Trim(); };
                    DirectoryName = if ($_.Node.DirectoryName) { $_.Node.DirectoryName.Trim(); } else { $_.Node.Id.Trim(); };
                    Arguments = $_.Node.Arguments.Trim();
                }
            }
        } -ErrorAction SilentlyContinue -ErrorVariable Errors |
        ForEach `
        {
            [PSObject]$ItemArray = New-Object PSObject -Property @{ Id = $_.Id; Version = $_.Version; DisplayName = $_.DisplayName; DirectoryName = $_.DirectoryName; Arguments = $_.Arguments; };
            $PackagesRequired.Add($ItemArray) > $null;
        };
    Validate-Errors;
}
Write-Host "Done" -ForegroundColor Green;
$PackagesRequired = $PackagesRequired | Select-Object -Property Id,Version,DisplayName,DirectoryName,Arguments -Unique;
$PackagesRequired | Format-Table -AutoSize -Property Id,Version,DisplayName,DirectoryName,Arguments | Out-String | %{Write-Host $_};


###########################################
# Obtaining Chocolatey Packages installed #
###########################################
[string]$CommandPrinted = " > " + $ChocolateyPath + " list --local-only";
[string]$Command = Get-ShortPath($ChocolateyPath).ToString();
[string]$CommandExecute = $Command + " list --local-only";
Write-Host "Obtaining Chocolatey Packages installed... " -NoNewline;
[System.Collections.ArrayList]$PackagesInstalled = Invoke-Expression "$CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors | `
    ForEach `
    {
        if ($_.Split(' ').Count -eq 2 -and -not [string]::IsNullOrEmpty($_.Split(' ')[0].Trim()))
        {
            New-Object PSObject -Property @{
                Id = $_.Split(' ')[0].Trim();
                Version = $_.Split(' ')[1].Trim();
            }
        }
    } -ErrorAction SilentlyContinue -ErrorVariable Errors | Select-Object -Unique Id, Version | Sort-Object Id, Version;
Validate-Errors;
if ($PackagesInstalled.Count -eq 0)
{
    Write-Host "Failed" -ForegroundColor Red;
    Write-Host $CommandPrinted;
    Write-Host "None Chocolatey Packages installed.";
    Write-Host "";
    Write-Host "";
}
else
{
    Write-Host "Done" -ForegroundColor Green;
    Write-Host $CommandPrinted;
    $PackagesInstalled | Format-Table -AutoSize -Property Id,Version | Out-String | %{Write-Host $_};
}


###########################################################
# Verifying if Chocolatey Packages required are installed #
###########################################################
Write-Host "Verifying if Chocolatey Packages required are installed... " -NoNewline;
[System.Collections.ArrayList]$PackagesAddUpdate = New-Object System.Collections.ArrayList;
ForEach($PackageR in $PackagesRequired)
{
    [System.Version]$VersionRequired = "0.0.0.0";
    [System.Version]$VersionInstalled = "0.0.0.0";
    [bool]$Finded = $false;
    [System.Version]$VersionRequired = $PackageR.Version.Trim().ToLower();
    ForEach($PackageI in $PackagesInstalled)
    {
        if ($PackageI.Id -eq $PackageR.Id)
        {
            [bool]$Finded = $true;
            [System.Version]$VersionInstalled = $PackageI.Version.Trim().ToLower();
            break;
        }
    }
    if ($Finded -eq $true)
    {
        if ($VersionInstalled -lt $VersionRequired)
        {
            [PSObject]$PackageA = New-Object PSObject -Property @{Id = $PackageR.Id; Version = $PackageR.Version; DisplayName = $PackageR.DisplayName; DirectoryName = $PackageR.DirectoryName; Arguments = $PackageR.Arguments; Action = "Upgrade"};
            $PackagesAddUpdate.Add($PackageA) > $null;
        }
    }
    else
    {
        [PSObject]$PackageA = New-Object PSObject -Property @{Id = $PackageR.Id; Version = $PackageR.Version; DisplayName = $PackageR.DisplayName; DirectoryName = $PackageR.DirectoryName; Arguments = $PackageR.Arguments; Action = "Install"};
        $PackagesAddUpdate.Add($PackageA) > $null;
    }
}
Write-Host "Done" -ForegroundColor Green;
if ([string]::IsNullOrEmpty($InstallAppsPath))
{
    [string]$TempPath = Join-Path $Env:Temp "Xenial";
}
else
{
    [string]$TempPath = Join-Path $InstallAppsPath "Temp";
}

#################################################
# Install or update Chocolatey Packages missing #
#################################################
if ($PackagesAddUpdate.Count -gt 0)
{
    $PackagesAddUpdate | Format-Table -AutoSize -Property Id,Version,DisplayName,DirectoryName,Arguments,Action | Out-String | %{Write-Host $_};
    Write-Host "Install or upgrade Chocolatey Packages missing.";
    ForEach($PackageU in $PackagesAddUpdate)
    {
        [string]$DisplayNameRex = $PackageU.DisplayName + '*';
        [Array]$Keys = Get-UninstallRegistryKey $DisplayNameRex -WarningAction SilentlyContinue;
        if ($Keys.Count -eq 0)
        {
            [string]$InstallPath = [string]::Empty; 
            if(![string]::IsNullOrEmpty($InstallAppsPath))
            {
                if ([string]::IsNullOrEmpty($PackageU.DirectoryName))
                {
                    $InstallPath = $InstallAppsPath;
                }
                else
                {
                    $InstallPath = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                }
            }
            [string]$Parameters = [string]::Empty;
            if (![string]::IsNullOrEmpty($PackageU.Arguments))
            {
                if ($PackageU.Arguments.Contains('{INSTALLPATH}'))
                {
                    if (![string]::IsNullOrEmpty($InstallPath))
                    {
                        if ($PackageU.Id.ToLower().Contains("jdk"))
                        {
                            $Parameters = $Parameters.Replace('{INSTALLPATH}', $InstallPath).Replace('\','\\');
                        }
                        else
                        {
                            $Parameters = $Parameters.Replace('{INSTALLPATH}', $InstallPath);
                        }
                    }
                    else
                    {
                        $Parameters = [string]::Empty;
                    }
                }
                else
                {
                    $Parameters = " --params=" + $PackageU.Arguments;
                }
            }
            [string]$Version = [string]::Empty;
            if ($PackageU.Version -ne '0.0.0.0' -and $PackageU.Version -ne '0.0.0' -and $PackageU.Version -ne '0.0')
            {
                $Version = " --version " + $PackageU.Version.ToString();
            }
            [string]$Command = Get-ShortPath($ChocolateyPath).ToString();
            [string]$CommandPrinted = " > " + $ChocolateyPath + " " + $PackageU.Action.Trim().ToLower() + " " + $PackageU.Id + $Version + " --yes --force --force-dependencies --no-progress --cache-location=""" + $TempPath + """" + $Parameters;
            [string]$CommandExecute = $Command + " " + $PackageU.Action.Trim().ToLower() + " " + $PackageU.Id + $Version + " --yes --force --force-dependencies --no-progress --cache-location=""" + $TempPath + """" + $Parameters;
            Write-Host "`r`n";
            Write-Host $PackageU.Action.Trim() $PackageU.Id $PackageU.Version;
            Write-Host $CommandPrinted;
            Invoke-Expression "$CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors;
            Validate-Errors;
        }
        else
        {
            Write-Host "`r`n";
            Write-Host $PackageU.Action.Trim() $PackageU.Id $PackageU.Version;
            Write-Host $PackageU.Id $PackageU.Version " is already installed.";
        }
    }
}
refreshenv;


############################################
# Move Chocolatey Packages to Install Path #
############################################
if (![string]::IsNullOrEmpty($InstallPath))
{
    if ($PackagesAddUpdate.Count -gt 0)
    {
        Write-Host "`r`n`r`nMoving Chocolatey Packages to Install Path... ";
        ForEach($PackageU in $PackagesAddUpdate)
        {
            if(![string]::IsNullOrEmpty($PackageU.DirectoryName))
            {
                switch ($PackageU.Id)
                {
                    "android-sdk"
                    {
                        Write-Host "`r`nMoving Android Sdk";
                        [string]$OldDestination = Join-Path ${Env:SystemDrive} 'Android\android-sdk';
                        [string]$ParentDir = (Get-Item $OldDestination).Parent.FullName;
                        $PathMachine = Join-Path $OldDestination 'tools';
                        Uninstall-ChocolateyPath $PathMachine 'Machine';
                        $PathMachine = Join-Path $OldDestination 'platform-tools';
                        Uninstall-ChocolateyPath $PathMachine 'Machine';
                        Uninstall-ChocolateyEnvironmentVariable 'ANDROID_HOME' 'Machine';
                        $CommandExecute = $PathMachine + "\adb kill-server";
                        Invoke-Expression "$CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors;
                        Validate-Errors;
                        refreshenv;
                        [string]$NewDestination = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                        [string]$EnvToolsPath = Join-Path $NewDestination 'tools';
                        [string]$EnvPlatformsPath = Join-Path $NewDestination 'platform-tools';
                        robocopy $OldDestination $NewDestination /e /move /np | Out-Null;
                        Remove-Item -Recurse -Force $ParentDir;
                        Install-ChocolateyPath $EnvToolsPath 'Machine';
                        Install-ChocolateyPath $EnvPlatformsPath 'Machine';
                        Install-ChocolateyEnvironmentVariable 'ANDROID_HOME' ${NewDestination} 'Machine';
                        refreshenv;
                        $CommandExecute = $EnvPlatformsPath + "\adb start-server";
                        Invoke-Expression "$CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors;
                        Validate-Errors;
                        $PathMachine = Join-Path $ChocolateyDir 'lib\android-sdk\tools\common.ps1';
                        (Get-Content $PathMachine).Replace('$androidPath = "${Env:SystemDrive}\Android"', '$androidPath = "' + $InstallAppsPath + '"') | Set-Content $PathMachine;
                        (Get-Content $PathMachine).Replace('$destination = "${androidPath}\android-sdk"', '$destination = "${androidPath}\Sdk"') | Set-Content $PathMachine;
                    }
                    "androidstudio"
                    {
                        Write-Host "`r`nMoving Android Studio";
                        [string]$OldDestination = Join-Path $Env:ProgramFiles 'Android\Android Studio';
                        [string]$ParentDir = (Get-Item $OldDestination).Parent.FullName;
                        [string]$NewDestination = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                        robocopy $OldDestination $NewDestination /e /move /np | Out-Null;
                        Remove-Item -Recurse -Force $ParentDir;
                        $PathMachine = Join-Path $ChocolateyDir 'lib\AndroidStudio\tools\common.ps1';
                        (Get-Content $PathMachine).Replace('$extractionPath =  Join-Path  $env:programfiles ''Android''', '$extractionPath = ''' + $InstallAppsPath + '''') | Set-Content $PathMachine;
                        (Get-Content $PathMachine).Replace('$installDir = Join-Path $extractionPath ''Android Studio''', '$installDir = Join-Path $extractionPath ''' + $PackageU.DirectoryName + '''') | Set-Content $PathMachine;
                        Update-UnInstallPath $PackageU.DisplayName 'DisplayIcon' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'UninstallString' $OldDestination $NewDestination;
                    }
                    "git.install"
                    {
                        Write-Host "`r`nMoving Git";
                        [string]$OldDestination = Join-Path $Env:ProgramFiles 'Git';
                        [string]$NewDestination = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                        $PathMachine = Join-Path $OldDestination 'cmd';
                        Uninstall-ChocolateyPath $PathMachine 'Machine';
                        $PathMachine = Join-Path $OldDestination 'mingw64\bin';
                        Uninstall-ChocolateyPath $PathMachine 'Machine';
                        $PathMachine = Join-Path $OldDestination 'usr\bin';
                        Uninstall-ChocolateyPath $PathMachine 'Machine';
                        refreshenv;
                        robocopy $OldDestination $NewDestination /e /move /np | Out-Null;
                        $PathMachine = Join-Path $NewDestination 'cmd';
                        Install-ChocolateyPath $PathMachine 'Machine';
                        $PathMachine = Join-Path $NewDestination 'mingw64\bin';
                        Install-ChocolateyPath $PathMachine 'Machine';
                        $PathMachine = Join-Path $NewDestination 'usr\bin';
                        Install-ChocolateyPath $PathMachine 'Machine';
                        refreshenv;
                        Update-UnInstallPath $PackageU.DisplayName 'DisplayIcon' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'Inno Setup: App Path' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'InstallLocation' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'QuietUninstallString' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'UninstallString' $OldDestination $NewDestination;
                    }
                    "visualstudiocode"
                    {
                        Write-Host "`r`nMoving Visual Studio Code";
                        [string]$OldDestination = Join-Path ${Env:ProgramFiles(x86)} 'Microsoft VS Code';
                        [string]$ExeVSCode = Join-Path $OldDestination "Code.exe";
                        if(![System.IO.File]::Exists($ExeVSCode))
                        {
                            $OldDestination = Join-Path $env:ProgramFiles 'Microsoft VS Code';
                        }
                        [string]$NewDestination = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                        robocopy $OldDestination $NewDestination /e /move /np | Out-Null;
                        $PathMachine = Join-Path $OldDestination 'bin';
                        Uninstall-ChocolateyPath $PathMachine 'User';
                        refreshenv;
                        $PathMachine = Join-Path $InstallAppsPath 'VSCode\bin';
                        Install-ChocolateyPath $PathMachine 'User';
                        refreshenv;
                        Update-UnInstallPath $PackageU.DisplayName 'DisplayIcon' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'Inno Setup: App Path' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'InstallLocation' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'QuietUninstallString' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'UninstallString' $OldDestination $NewDestination;
                    }
                    "nodejs.install"
                    {
                        Write-Host "`r`nMoving NodeJs";
                        [string]$OldDestination = Join-Path ${Env:ProgramFiles(x86)} 'nodejs';
                        [string]$ExeNodeJs = Join-Path $OldDestination "node.exe";
                        if(![System.IO.File]::Exists($ExeNodeJs))
                        {
                            $OldDestination = Join-Path $Env:ProgramFiles 'nodejs';
                        }
                        [string]$NewDestination = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                        robocopy $OldDestination $NewDestination /e /move /np | Out-Null;
                        Uninstall-ChocolateyPath $OldDestination 'Machine';
                        refreshenv;
                        Install-ChocolateyPath $NewDestination 'Machine';
                        refreshenv;
                    }
                    "nvm.portable"
                    {
                       Write-Host "`r`nMoving Nvm";
                       [string]$OldDestination = Join-Path $Env:AllUsersProfile 'nvm';
                       [string]$NewDestination = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                       Uninstall-ChocolateyPath $OldDestination 'Machine';
                       Uninstall-ChocolateyEnvironmentVariable 'NVM_HOME' 'Machine';
                       Uninstall-ChocolateyEnvironmentVariable 'NVM_SYMLINK' 'Machine';
                       refreshenv;
                       robocopy $OldDestination $NewDestination /e /move /np | Out-Null;
                       [string]$OldDestination = Join-Path ${Env:ProgramFiles(x86)} 'nodejs';
                       [string]$ExeNodeJs = Join-Path $OldDestination "node.exe";
                       if(![System.IO.File]::Exists($ExeNodeJs))
                       {
                           $OldDestination = Join-Path $Env:ProgramFiles 'nodejs';
                       }
                       Uninstall-ChocolateyPath $OldDestination 'Machine';
                       Install-ChocolateyEnvironmentVariable 'NVM_HOME' ${NewDestination} 'Machine';
                       Install-ChocolateyPath ${NewDestination} 'Machine';
                       [System.Management.Automation.CommandInfo]$ExeNodeJs = Get-Command 'node.exe*';
                       $PathMachine = (Get-Item $ExeNodeJs.Path).DirectoryName;
                       Install-ChocolateyEnvironmentVariable 'NVM_SYMLINK' $PathMachine 'Machine';
                       Install-ChocolateyPath $PathMachine 'Machine';
                       refreshenv;
                    }
                    "appium-desktop"
                    {
                        Write-Host "`r`nMoving Appium Desktop";
                        [string]$OldDestination = Join-Path $Env:LocalAppData 'Programs\appium-desktop';
                        [string]$NewDestination = Join-Path $InstallAppsPath $PackageU.DirectoryName;
                        robocopy $OldDestination $NewDestination /e /move /np | Out-Null;
                        Install-ChocolateyPath $NewDestination 'User';
                        refreshenv;
                        Update-UnInstallPath $PackageU.DisplayName 'DisplayIcon' $OldDestination $NewDestination;
                        Update-UnInstallPath $PackageU.DisplayName 'UninstallString' $OldDestination $NewDestination;
                    }
                }
            }
        }
    }
}