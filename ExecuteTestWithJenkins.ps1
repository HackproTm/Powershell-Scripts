Param(
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$SolutionPath,
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$BuildNumber,
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$PackagesPath = "",
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$UiTestConfig = "",
  [string]$TestResultDir = ""
)

[string]$Global:ScriptDir = $PSScriptRoot;
[string]$Global:CurrentDir = (Get-Item -Path ".\" -Verbose).FullName;
[System.Collections.ArrayList]$Global:Errors = New-Object System.Collections.ArrayList;

#####################
# General Functions #
#####################
# Validate if the Path is valid
function Validate-Paths([string]$PathValidate)
{
	if ([string]::IsNullOrEmpty($PathValidate))
	{
		Write-Host "Failed" -ForegroundColor Red;
		Write-Host "ERROR: Path parameter is null or empty." -ForegroundColor Yellow -BackgroundColor Red;
		exit 12345;
	}
	if (-not (Test-Path -IsValid $PathValidate))
	{
		Write-Host "Failed" -ForegroundColor Red;
		Write-Host "ERROR: $PathValidate not is a path valid." -ForegroundColor Yellow -BackgroundColor Red;
		exit 12345;
	}
}

# Validate if the Path exist in the system
function Exist-Paths([string]$PathValidate)
{
	if (-not (Test-Path -Path "$PathValidate"))
	{
		Write-Host "Failed" -ForegroundColor Red;
		Write-Host "ERROR: $PathValidate not found in the system." -ForegroundColor Yellow -BackgroundColor Red;
		exit 12345;
	}
}


# Validate if errors are present and print them
function Validate-Errors([bool]$PrintFailed = $true)
{
	if ($Global:Errors.Count -gt 0)
	{
		if ($PrintFailed -eq $true)
		{
			Write-Host "Failed" -ForegroundColor Red;
		}
		$Global:Errors | Format-List | Out-String | %{Write-Host $_ -ForegroundColor Yellow -BackgroundColor Red};
		exit 12345;
	}
	$Global:Errors.Clear() > $null;
}


#Obtaint the short path for any path file or folder
function Get-ShortPath([string]$PathFile)
{
	$FileSystem = New-Object -ComObject Scripting.FileSystemObject
	[string]$ShortPath = ""
	if ($FileSystem.FileExists($PathFile) -eq $true)
	{
		$FileInfo = $FileSystem.GetFile($PathFile)
		[string]$ShortPath = $FileInfo.ShortPath
	}
	else
	{
		if ($FileSystem.FolderExists($PathFile) -eq $true)
		{
			$FileInfo = $FileSystem.GetFolder($PathFile)
			[string]$ShortPath = $FileInfo.ShortPath
		}
	}
	return $ShortPath
}


# Install Package Manager Chocolotey
function Install-Chocolatey
{
	Write-Host "The package manager Chocolatey is not installed.";
	Write-Host "`r`nInstalling Chocolatey in the system.`r`n";
	Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue -ErrorVariable Errors;
	Validate-Errors($false);
	Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -ErrorAction SilentlyContinue -ErrorVariable Errors
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
				Remove-Item -Recurse -Force "$Env:ChocolateyInstall"
			}
		}
		[System.Environment]::SetEnvironmentVariable("ChocolateyInstall", $null, [System.EnvironmentVariableTarget]::Machine)
	}
	[System.Text.RegularExpressions.Regex]::Replace([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment').GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames).ToString(), [System.Text.RegularExpressions.Regex]::Escape("$Env:ChocolateyInstall\bin") + '(?>;)?', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | %{[System.Environment]::SetEnvironmentVariable('PATH', $_, 'User')}
	[System.Text.RegularExpressions.Regex]::Replace([Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment\').GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames).ToString(),  [System.Text.RegularExpressions.Regex]::Escape("$env:ChocolateyInstall\bin") + '(?>;)?', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | %{[System.Environment]::SetEnvironmentVariable('PATH', $_, 'Machine')}
	if ($Env:ChocolateyBinRoot -ne '' -and $Env:ChocolateyBinRoot -ne $null) { Remove-Item -Recurse -Force "$Env:ChocolateyBinRoot" }
	if ($Env:ChocolateyToolsRoot -ne '' -and $Env:ChocolateyToolsRoot -ne $null) { Remove-Item -Recurse -Force "$Env:ChocolateyToolsRoot" }
	[System.Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $null, [System.EnvironmentVariableTarget]::User)
	[System.Environment]::SetEnvironmentVariable("ChocolateyToolsLocation", $null, [System.EnvironmentVariableTarget]::User)
	Write-Host "Done" -ForegroundColor Green;
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


#######################################################
# Obtaining the information from Solution File (.sln) #
#######################################################
Write-Host "`r`n`r`nObtaining information from Solution File (.sln)... " -NoNewline;
if ($SolutionPath) { $SolutionPath = $SolutionPath.Trim(); }
Validate-Paths($SolutionPath);
Exist-Paths($SolutionPath);
[string]$Global:FileExtension = (Get-Item "$SolutionPath").Extension;
if ($Global:FileExtension) { $Global:FileExtension = $Global:FileExtension.Trim().ToLower(); }
if ([string]::IsNullOrEmpty($Global:FileExtension) -or -not ($Global:FileExtension -eq ".sln"))
{
	Write-Host "Failed" -ForegroundColor Red;
	Write-Host "ERROR: $SolutionPath not is a Solution (.sln) File." -ForegroundColor Yellow -BackgroundColor Red;
	exit 12345;
}
[string]$Global:SolutionDir = (Get-Item "$SolutionPath").DirectoryName.Trim();
[string]$Global:SolutionName = (Get-Item "$SolutionPath").BaseName;
if ([string]::IsNullOrEmpty($Global:SolutionDir) -or [string]::IsNullOrEmpty($Global:SolutionName))
{
	Write-Host "Failed" -ForegroundColor Red;
	Write-Host "ERROR: An error occurred when establishing the Directory and Name of the solution." -ForegroundColor Yellow -BackgroundColor Red;
	exit 12345;
}
Validate-Paths($Global:SolutionDir);
Exist-Paths($Global:SolutionDir)
Write-Host "Done" -ForegroundColor Green;
Write-Host "`r`nSolution Directory: $Global:SolutionDir";
Write-Host "Solution Name: $Global:SolutionName";


##################################################
# Gets information of the Projects from Solution #
##################################################
Write-Host "`r`n`r`nGets information of the Projects from Solution... " -NoNewline;
[System.Collections.ArrayList]$Global:Projects = Get-Content "$SolutionPath" -ErrorAction SilentlyContinue -ErrorVariable Errors |
		Select-String 'Project\(' -ErrorAction SilentlyContinue -ErrorVariable Errors |
		ForEach-Object { $ProjectInfo = $_ -Split '[,=]' | ForEach-Object { $_.Trim('[ "{}]') };
			New-Object PSObject -Property @{
				Name = $ProjectInfo[1].Trim();
				File = $ProjectInfo[2].Trim();
				Guid = $ProjectInfo[3].Trim();
				TargetType = "";
				TargetDir = "";
				AssemblyName = "";
				IsUiProject = $false;
				NUnitTest = $false;
				MSTest = $false
			}
		} -ErrorAction SilentlyContinue -ErrorVariable Errors;
Validate-Errors;
if ($Global:Projects.Count -eq 0)
{
	Write-Host "Failed" -ForegroundColor Red;
	Write-Host "ERROR: The solution not have projects associates." -ForegroundColor Yellow -BackgroundColor Red;
	exit 12345;
}
Write-Host "Done" -ForegroundColor Green;
$Global:Projects | Format-Table -AutoSize -Property Guid,Name,File | Out-String | %{Write-Host $_};


########################################
# Verifying if Chocolatey is installed #
########################################
Write-Host "Verifying if Chocolatey is installed... " -NoNewline;
[string]$Global:ChocolateyDir = $Env:ChocolateyInstall;
if ($Global:ChocolateyDir) { $Global:ChocolateyDir = $Global:ChocolateyDir.Trim(); }
if ([string]::IsNullOrEmpty($Global:ChocolateyDir))
{
	Write-Host "Failed" -ForegroundColor Red;
	Install-Chocolatey;
	[string]$Global:ChocolateyDir = $Env:ChocolateyInstall;
	if ($Global:ChocolateyDir) { $Global:ChocolateyDir = $Global:ChocolateyDir.Trim(); }
	if ([string]::IsNullOrEmpty($Global:ChocolateyDir))
	{
		Write-Host "Failed" -ForegroundColor Red;
		Write-Host "System environment variable (ChocolateyInstall) not set." -ForegroundColor Yellow -BackgroundColor Red;
		exit 12345;
	}
}
Validate-Paths($Global:ChocolateyDir);
if (-not (Test-Path -Path "$Global:ChocolateyDir"))
{
	Write-Host "Failed" -ForegroundColor Red;
	Install-Chocolatey;
	[string]$Global:ChocolateyDir = $Env:ChocolateyInstall;
	if ($Global:ChocolateyDir) { $Global:ChocolateyDir = $Global:ChocolateyDir.Trim(); }
	if ([string]::IsNullOrEmpty($Global:ChocolateyDir))
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
Write-Host "Chocolatey Directory: $Global:ChocolateyDir";
Write-Host "`r`n`r`nVerifying Chocolatey executable path... " -NoNewline;
[string]$Global:ChocolateyPath = $Global:ChocolateyDir + "\choco.exe";
Validate-Paths($Global:ChocolateyPath);
if (-not (Test-Path -Path "$Global:ChocolateyPath"))
{
	Write-Host "Failed" -ForegroundColor Red;
	Install-Chocolatey;
	[string]$Global:ChocolateyPath = $Global:ChocolateyDir + "\choco.exe";
	if (-not (Test-Path -Path "$Global:ChocolateyPath"))
	{
		Write-Host "Failed" -ForegroundColor Red;
		Write-Host "Chocolatey executable not found." -ForegroundColor Yellow -BackgroundColor Red;
		exit 12345;
	}
}
else
{
	Write-Host "Done" -ForegroundColor Green;
	Write-Host $Global:ChocolateyPath
}


##########################################
# Obtaining required Chocolatey Packages #
##########################################
Write-Host "`r`n`r`nObtaining required Chocolatey Packages... " -NoNewline;
[System.Collections.ArrayList]$Global:PackagesRequired = New-Object System.Collections.ArrayList;
if ($PackagesPath) { $PackagesPath = $PackagesPath.Trim(); }
if (-not ([string]::IsNullOrEmpty($PackagesPath)))
{
	Validate-Paths($PackagesPath);
	Exist-Paths($PackagesPath);
	[string]$Global:FileExtension = (Get-Item "$PackagesPath").Extension;
	if ($Global:FileExtension) { $Global:FileExtension = $Global:FileExtension.Trim().ToLower(); }
	if ([string]::IsNullOrEmpty($Global:FileExtension) -or $Global:FileExtension -ne ".config" -or -not (Test-XMLFile($PackagesPath)))
	{
		Write-Host "Failed" -ForegroundColor Red;
		Write-Host "ERROR: $PackagesPath not is a Packages Configuration (.config) File." -ForegroundColor Yellow -BackgroundColor Red;
		exit 12345;
	}
	Select-Xml -Path "$PackagesPath" -XPath "/packages/package" -ErrorAction SilentlyContinue -ErrorVariable Errors |
		foreach {
			if ($_.Node.Id)
			{
				New-Object PSObject -Property @{
					Id = $_.Node.Id.Trim();
					Version = if ($_.Node.Version) { $_.Node.Version.Trim() } else { "0.0.0" }
				}
			}
		} -ErrorAction SilentlyContinue -ErrorVariable Errors | Select-Object -Unique Id,Version | Sort-Object Id,Version |
		ForEach {
			[PSObject]$ItemArray = New-Object PSObject -Property @{Id = $_.Id; Version = $_.Version};
			$Global:PackagesRequired.Add($ItemArray) > $null;
		};
	Validate-Errors;
}
[PSObject]$Global:Package = New-Object PSObject -Property @{Id = "dotnet4.6.1"; Version = "4.6.1"};
$Global:PackagesRequired.Add($Package) > $null;
[PSObject]$Global:Package = New-Object PSObject -Property @{Id = "microsoft-build-tools"; Version = "15.0.26320.2"};
$Global:PackagesRequired.Add($Package) > $null;
[PSObject]$Global:Package = New-Object PSObject -Property @{Id = "nuget.commandline"; Version = "4.3.0"};
$Global:PackagesRequired.Add($Package) > $null;
[PSObject]$Global:Package = New-Object PSObject -Property @{Id = "visualstudio2015testagents"; Version = "14.0.25420.1"};
$Global:PackagesRequired.Add($Package) > $null;
[PSObject]$Global:Package = New-Object PSObject -Property @{Id = "nunit-console-runner"; Version = "3.7.0"};
$Global:PackagesRequired.Add($Package) > $null;
[PSObject]$Global:Package = New-Object PSObject -Property @{Id = "vswhere"; Version = "2.2.11"};
$Global:PackagesRequired.Add($Package) > $null;
Write-Host "Done" -ForegroundColor Green;
$Global:PackagesRequired = $Global:PackagesRequired | Select-Object -Unique Id, Version | Sort-Object Id, Version;
$Global:PackagesRequired | Format-Table -AutoSize -Property Id,Version | Out-String | %{Write-Host $_};


###########################################
# Obtaining Chocolatey Packages installed #
###########################################
[string]$Global:CommandPrinted = " > " + $Global:ChocolateyPath + " list --local-only";
[string]$Global:Command = Get-ShortPath($Global:ChocolateyPath).ToString();
[string]$Global:CommandExecute = $Global:Command + " list --local-only";
Write-Host "Obtaining Chocolatey Packages installed... " -NoNewline;
[System.Collections.ArrayList]$Global:PackagesInstalled = Invoke-Expression "$Global:CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors |
						foreach {
									if ($_.Split(' ').Count -eq 2 -and -not [string]::IsNullOrEmpty($_.Split(' ')[0].Trim()))
									{
										New-Object PSObject -Property @{
											Id = $_.Split(' ')[0].Trim();
											Version = $_.Split(' ')[1].Trim()
										}
								}
						} -ErrorAction SilentlyContinue -ErrorVariable Errors | Select-Object -Unique Id, Version | Sort-Object Id, Version;
Validate-Errors;
if ($Global:PackagesInstalled.Count -eq 0)
{
	Write-Host "Failed" -ForegroundColor Red;
	Write-Host $Global:CommandPrinted
	Write-Host "None Chocolatey Packages installed.";
	Write-Host "";
	Write-Host "";
}
else
{
	Write-Host "Done" -ForegroundColor Green;
	Write-Host $Global:CommandPrinted
	$Global:PackagesInstalled | Format-Table -AutoSize -Property Id,Version | Out-String | %{Write-Host $_};
}


###########################################################
# Verifying if Chocolatey Packages required are installed #
###########################################################
Write-Host "Verifying if Chocolatey Packages required are installed... " -NoNewline;
[System.Collections.ArrayList]$Global:PackagesAddUpdate = New-Object System.Collections.ArrayList;
foreach($PackageR in $Global:PackagesRequired)
{
	[System.Version]$Global:VersionRequired = "0.0.0.0";
	[System.Version]$Global:VersionInstalled = "0.0.0.0";
	[bool]$Global:Finded = $false;
	[System.Version]$Global:VersionRequired = $PackageR.Version.Trim().ToLower();
	foreach($PackageI in $Global:PackagesInstalled)
	{
		if ($PackageI.Id -eq $PackageR.Id)
		{
			[bool]$Global:Finded = $true;
			[System.Version]$Global:VersionInstalled = $PackageI.Version.Trim().ToLower();
			break;
		}
	}
	if ($Global:Finded -eq $true)
	{
		if ($Global:VersionInstalled -lt $Global:VersionRequired)
		{
			[PSObject]$Global:PackageA = New-Object PSObject -Property @{Id = $PackageR.Id; Version = $PackageR.Version; Action = "Upgrade"};
			$Global:PackagesAddUpdate.Add($Global:PackageA) > $null;
		}
	}
	else
	{
		[PSObject]$Global:PackageA = New-Object PSObject -Property @{Id = $PackageR.Id; Version = $PackageR.Version; Action = "Install"};
		$Global:PackagesAddUpdate.Add($Global:PackageA) > $null;
	}
}
Write-Host "Done" -ForegroundColor Green;


#################################################
# Install or update Chocolatey Packages missing #
#################################################
if ($Global:PackagesAddUpdate.Count -gt 0)
{
	$Global:PackagesAddUpdate = $Global:PackagesAddUpdate | Select-Object -Unique Id, Version, Action | Sort-Object Action, Id, Version
	$Global:PackagesAddUpdate | Format-Table -AutoSize -Property Id,Version,Action | Out-String | %{Write-Host $_};
	Write-Host "Install or upgrade Chocolatey Packages missing.";
	foreach($PackageU in $Global:PackagesAddUpdate)
	{
		[string]$Global:Command = Get-ShortPath($Global:ChocolateyPath).ToString();
		[string]$Global:CommandPrinted = " > " + $Global:ChocolateyPath + " " + $PackageU.Action.Trim().ToLower() + " " + $PackageU.Id + " --proxy='' --yes --force --force-dependencies --no-progress";
		[string]$Global:CommandExecute = $Global:Command + " " + $PackageU.Action.Trim().ToLower() + " " + $PackageU.Id + " --proxy='' --yes --force --force-dependencies --no-progress";
		Write-Host "`r`n"
		Write-Host $PackageU.Action.Trim() $PackageU.Id $PackageU.Version;
		Write-Host $Global:CommandPrinted
		Invoke-Expression "$Global:CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors;
		Validate-Errors;
	}
}


#################################
# Establishing the MsBuild path #
#################################
Write-Host "`r`n`r`nEstablishing the MsBuild path... " -NoNewline;
[string]$Global:MsBuildDir = VSWhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
if ($Global:MsBuildDir) { $Global:MsBuildDir = $Global:MsBuildDir.Trim(); }
[System.Version]$Global:MsBuildVersion = VSWhere -latest -products * -requires Microsoft.Component.MSBuild -property installationVersion
Validate-Paths($Global:MsBuildDir);
Exist-Paths($Global:MsBuildDir);
[string]$Global:MsBuildPath = $Global:MsBuildDir + "\MSBuild\" + $Global:MsBuildVersion.Major + ".0\Bin\MSBuild.exe";
Validate-Paths($Global:MsBuildPath);
Exist-Paths($Global:MsBuildPath);
Write-Host "Done" -ForegroundColor Green;
Write-Host "MsBuild Dir: $Global:MsBuildDir";
Write-Host "MsBuild Path: $Global:MsBuildPath";


###############################
# Establishing the NuGet path #
###############################
Write-Host "`r`n`r`nEstablishing the NuGet path... " -NoNewline;
[string]$Global:NuGetPath = $Global:ChocolateyDir + "\bin\NuGet.exe";
Validate-Paths($Global:NuGetPath);
Exist-Paths($Global:NuGetPath);
Write-Host "Done" -ForegroundColor Green;
Write-Host "NuGet Path: $Global:NuGetPath";


##############################################
# Restoring the NuGet packages from solution #
##############################################
Write-Host "`r`n`r`nRestoring the NuGet packages from solution.";
[string]$Global:Command = Get-ShortPath($Global:NuGetPath).ToString();
[string]$Global:CommandA = (Get-Item "$Global:MsBuildPath").Directory.FullName;
[string]$Global:CommandB = (Get-Item (Get-ShortPath($Global:MsBuildPath).ToString())).Directory.FullName;
[string]$Global:CommandPrinted = " > " + $Global:NuGetPath + " restore '" + $SolutionPath + "' -NonInteractive -Verbosity normal -MSBuildPath '" + $Global:CommandA + "'";
[string]$Global:CommandExecute = $Global:Command + " restore '" + $SolutionPath + "' -NonInteractive -Verbosity normal -MSBuildPath '" + $Global:CommandB + "'";
Write-Host $Global:CommandPrinted
Write-Host ""
Invoke-Expression "$Global:CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors;
Validate-Errors;


######################
# Build the Solution #
######################
Write-Host "`r`n`r`nBuild the Solution.";
[string]$Global:Command = Get-ShortPath($Global:MsBuildPath).ToString();
[string]$Global:CommandPrinted = " > " + $Global:MsBuildPath + " /v:normal /t:Rebuild /p:Configuration=Release '" + $SolutionPath + "'";
[string]$Global:CommandExecute = $Global:Command + " /v:normal /t:Rebuild /p:Configuration=Release '" + $SolutionPath + "'";
Write-Host $Global:CommandPrinted
Write-Host ""
Invoke-Expression "$Global:CommandExecute" -ErrorAction SilentlyContinue -ErrorVariable Errors;
Validate-Errors;


###################################################################
# Validate if Projects are type Library and contains test methods #
###################################################################
Write-Host "`r`n`r`nValidate if Projects are type Library and contains Test Methods.";
[System.Collections.ArrayList]$Global:ProjectsTest = New-Object System.Collections.ArrayList;
foreach($Project in $Global:Projects)
{
	[string]$ProjectPath = $Global:SolutionDir + "\" + $Project.File;
	Validate-Paths($ProjectPath);
	Exist-Paths($ProjectPath);
	if (-not (Test-XMLFile($ProjectPath)))
	{
		Write-Host "`r`nERROR: $ProjectPath not is a valid Project File (.csproj)." -ForegroundColor Yellow -BackgroundColor Red;
	}
	[string]$TargetType = ([Xml](Get-Content -Path "$ProjectPath")).Project.PropertyGroup.OutputType;
	if ($TargetType) { $TargetType = $TargetType.Trim().ToLower(); }
	if ((-not [string]::IsNullOrEmpty($TargetType)))
	{
		$Project.TargetType = $TargetType;
		[string]$AssemblyName = ([Xml](Get-Content -Path "$ProjectPath")).Project.PropertyGroup.AssemblyName;
		if ($AssemblyName) { $AssemblyName = [string]$AssemblyName.Trim(); }
		if ((-not [string]::IsNullOrEmpty($AssemblyName)))
		{
			$Project.AssemblyName = $AssemblyName;
			[string]$IsUiProject = ([Xml](Get-Content -Path "$ProjectPath")).Project.PropertyGroup.IsCodedUITest;
			if ([string]::IsNullOrEmpty($IsUiProject))
			{
				$Project.IsUiProject = $false;
			}
			else
			{
				$Project.IsUiProject = $IsUiProject;
			}
			[System.Collections.ArrayList]$OutputProject = ([Xml](Get-Content -Path "$ProjectPath")).Project.PropertyGroup.OutputPath | Select -Unique;
			if ($OutputProject.Count -gt 0)
			{
				foreach($TargetDir in $OutputProject)
				{
					if ($TargetDir -and $TargetDir.Trim().ToLower().Contains("release"))
					{
						if ($Project.TargetType -eq "library")
						{
							[string]$AssemblyDir = (Get-Item ($Global:SolutionDir + "\" + $Project.File)).Directory.FullName + "\" + $TargetDir;
							[string]$AssemblyPath = $AssemblyDir + $AssemblyName + ".dll";
							Validate-Paths($AssemblyPath);
							Exist-Paths($AssemblyPath);
							$Project.TargetDir = $AssemblyDir;
							Add-Type -Path "$AssemblyPath" -IgnoreWarnings;
							[System.Reflection.Assembly]$AssemblyInfo = [System.Reflection.Assembly]::LoadFile($AssemblyPath);
							if ($AssemblyInfo)
							{
								$Types = $AssemblyInfo.GetTypes();
								if ($Types)
								{
									$Methods = $AssemblyInfo.GetTypes().GetMethods();
									if ($Methods)
									{
										[System.Collections.ArrayList]$TestMethodsNunit = $AssemblyInfo.GetTypes().GetMethods() |
											Where { $_.GetCustomAttributesData() | Where { $_.AttributeType.FullName -like "*.TestAttribute" } } | 
											Select Name, @{
												Name = "Description"
												Expression = { 
													$DescriptionAttribute = $_.GetCustomAttributesData() |
													Where { $_.AttributeType.FullName -like "*.DescriptionAttribute"}
												}
											} -ErrorAction Ignore -ErrorVariable Errors;
										if ($TestMethodsNunit.Count -gt 0) { $Project.NUnitTest = $true; }
										[System.Collections.ArrayList]$TestMethodsMSTest = $AssemblyInfo.GetTypes().GetMethods() |
											Where { $_.GetCustomAttributesData() | Where { $_.AttributeType.FullName -like "*.TestMethod" } } | 
											Select Name, @{
												Name = "Description"
												Expression = { 
													$DescriptionAttribute = $_.GetCustomAttributesData() |
													Where { $_.AttributeType.FullName -like "*.DescriptionAttribute"}
												}
											} -ErrorAction Ignore -ErrorVariable Errors;
										if ($TestMethodsMSTest.Count -gt 0) { $Project.MSTest = $true; }
									}
								}
							}
							Write-Host "`r`nAssembly: `r`n$AssemblyPath";
							if ($TestMethodsNunit.Count -gt 0 -or $TestMethodsMSTest.Count -gt 0)
							{
								if ($TestMethodsNunit.Count -gt 0)
								{
									Write-Host "`r`nNUnit Test Methods.";
									$TestMethodsNunit | Format-Table -AutoSize | Out-String | %{Write-Host $_};
								}
								if ($TestMethodsMSTest.Count -gt 0)
								{
									Write-Host "`r`nMicrosoft Test Methods.";
									$TestMethodsMSTest | Format-Table -AutoSize | Out-String | %{Write-Host $_};
								}
								$ProjectsTest.Add($Project) > $null;
							}
							else
							{
								Write-Host "`r`nNot found Test Methods.";
							}
						}
						else
						{
							Write-Host "`r`nProject not is a Library Type.";
						}
					}
				}
			}
			else
			{
				Write-Host "`r`nERROR: $ProjectPath, it was not possible to determine the output path of the assembly." -ForegroundColor Yellow -BackgroundColor Red;
			}
		}
		else
		{
			Write-Host "`r`nERROR: $ProjectPath, it was not possible to determine the assembly name." -ForegroundColor Yellow -BackgroundColor Red;
		}
	}
	else
	{
		Write-Host "`r`nERROR: $ProjectPath, it was not possible to determine the type of project." -ForegroundColor Yellow -BackgroundColor Red;
	}
}
if ($ProjectsTest.Count -eq 0)
{
	Write-Host "ERROR: The solution not have projects of type Library with test methods." -ForegroundColor Yellow -BackgroundColor Red;
	exit 12345;
}
else
{
	Write-Host "`r`n`r`nProjects found with NUnit or MSTest Methods";
	$ProjectsTest | Format-Table -AutoSize -Property Name,IsUiProject,NUnitTest,MSTest | Out-String | %{Write-Host $_}
}


################################
# Establishing the MSTest path #
################################
Write-Host "Establishing the MSTest path... " -NoNewline;
[string]$Global:MsTestDir = VSWhere -latest -products * -requires Microsoft.VisualStudio.Product.TestAgent -property installationPath
if ($Global:MsTestDir) { $Global:MsTestDir = $Global:MsTestDir.Trim(); }
[System.Version]$Global:MsTestVersion = VSWhere -latest -products * -requires Microsoft.VisualStudio.Product.TestAgent -property installationVersion
Validate-Paths($Global:MsTestDir);
Exist-Paths($Global:MsTestDir);
[string]$Global:MsTestPath = $Global:MsTestDir + "\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe";
Validate-Paths($Global:MsTestPath);
Exist-Paths($Global:MsTestPath);
Write-Host "Done" -ForegroundColor Green;
Write-Host "MsTest Dir: $Global:MsTestDir";
Write-Host "MsTest Path: $Global:MsTestPath";


#######################################
# Establishing the NUnit Console path #
#######################################
Write-Host "`r`n`r`nEstablishing the NUnit Console path... " -NoNewline;
[string]$Global:NUnitConsolePath = $Global:ChocolateyDir + "\lib\nunit-console-runner\tools\nunit3-console.exe";
Validate-Paths($Global:NUnitConsolePath);
Exist-Paths($Global:NUnitConsolePath);
Write-Host "Done" -ForegroundColor Green;
Write-Host "NUnit Console Path: $Global:NUnitConsolePath";


##################################################
# Obtaining Configuration of the TestUI Projects #
##################################################
if ($UiTestConfig) { $UiTestConfig = $UiTestConfig.Trim(); }
[System.Collections.ArrayList]$Global:ConfigTest = New-Object System.Collections.ArrayList;
if (-not ([string]::IsNullOrEmpty($UiTestConfig)))
{
	Write-Host "`r`n`r`nObtaining Configuration of the TestUI Projects... " -NoNewline;
	Validate-Paths($UiTestConfig);
	Exist-Paths($UiTestConfig);
	[string]$Global:FileExtension = (Get-Item "$UiTestConfig").Extension;
	if ($Global:FileExtension) { $Global:FileExtension = $Global:FileExtension.Trim().ToLower(); }
	if ([string]::IsNullOrEmpty($Global:FileExtension) -or $Global:FileExtension -ne ".xml" -or -not (Test-XMLFile($UiTestConfig)))
	{
		Write-Host "Failed" -ForegroundColor Red;
		Write-Host "ERROR: $UiTestConfig not is a XML (.xml) File." -ForegroundColor Yellow -BackgroundColor Red;
		exit 12345;
	}
	Select-Xml -Path "$UiTestConfig" -XPath "/UiTestProjectConfig/Configuration" -ErrorAction SilentlyContinue -ErrorVariable Errors |
		ForEach {
			if ($_.Node.BrowserType)
			{
				New-Object PSObject -Property @{
					BrowserType = $_.Node.BrowserType.Trim();
					ConfigFilePath = if ($_.Node.ConfigFilePath)
									 { $_.Node.ConfigFilePath.Trim() }
									 else
									 { "" }
				}
			}
		} -ErrorAction SilentlyContinue -ErrorVariable Errors | Select-Object -Unique BrowserType,ConfigFilePath | Sort-Object BrowserType |
		ForEach {
			[PSObject]$ItemArray = New-Object PSObject -Property @{BrowserType = $_.BrowserType.Trim(); ConfigFilePath = $_.ConfigFilePath.Trim()};
			$Global:ConfigTest.Add($ItemArray) > $null;
		};
	Validate-Errors;
	Write-Host "Done" -ForegroundColor Green;
	$Global:ConfigTest | Format-Table -AutoSize -Property BrowserType,ConfigFilePath | Out-String | %{Write-Host $_}
}
else
{
	Write-Host ""
	Write-Host ""
}


########################################
# Preparing directory for test results #
########################################
Write-Host "Preparing directory for test results... " -NoNewline;
if ($TestResultDir)
{
	$Global:TestResultDir = $TestResultDir.Trim();
	Validate-Paths($Global:TestResultDir);
	$Global:TestResultDir = $Global:TestResultDir + "\" + $BuildNumber;	
}
else
{
	$Global:TestResultDir = $Global:SolutionDir + "\TestResult\" + $BuildNumber;
	Validate-Paths($Global:TestResultDir);
}
If(!(Test-Path "$Global:TestResultDir"))
{
	New-Item -ItemType Directory -Force -Path $Global:TestResultDir > $null;
}
Exist-Paths($Global:TestResultDir);
Write-Host "Done" -ForegroundColor Green;
Write-Host "Test Result Directory: $Global:TestResultDir";
$Global:TestResultDir = Get-ShortPath($Global:TestResultDir).ToString();


##########################################################
# Executing the tests and generating the results reports #
##########################################################
[System.Collections.ArrayList]$Global:ExecuteTestCommand = New-Object System.Collections.ArrayList;
for ($i = 0; $i -lt $Global:ProjectsTest.Count; $i++)
{
	if ([System.Convert]::ToBoolean($Global:ProjectsTest[$i].IsUiProject) -eq $true)
	{
		if ($Global:ConfigTest.Count -gt 0)
		{
			for ($j = 0; $j -lt $Global:ConfigTest.Count; $j++)
			{
				[string]$Browser = $Global:ConfigTest[$j].BrowserType.Trim();
				[string]$ConfigFile = $Global:ConfigTest[$j].ConfigFilePath.Trim();
				if ([System.Convert]::ToBoolean($Global:ProjectsTest[$i].NUnitTest) -eq $true)
				{
					[string]$Arguments = "`"" + $Global:ProjectsTest[$i].TargetDir + $Global:ProjectsTest[$i].AssemblyName + ".dll`" --config=Default --work=" + $Global:TestResultDir +
										 " --result=`"TestResultNUnit-" + $Global:ProjectsTest[$i].AssemblyName + "_" + $Browser + ".xml`" --output=`"TestOutputNUnit-" +
										 $Global:ProjectsTest[$i].AssemblyName + "_" + $Browser + ".txt`" --err=`"TestErrorsNUnit-" + $Global:ProjectsTest[$i].AssemblyName + "_" + $Browser +
										 ".log`" --params=ConfigXML=`"" + $ConfigFile + "`" --trace=Verbose --labels=All --inprocess --domain=Single --dispose-runners --workers=1";
					[string]$JobName = "UiTest-NUnit_" + $Browser + "_" + $i + $j;
					[PSObject]$TestCommand = New-Object PSObject -Property @{Adapter = "NUnit"; AdapterPath = $Global:NUnitConsolePath; Arguments = $Arguments; JobName = $JobName; AssemblyName = $ProjectsTest[$i].AssemblyName; Browser = $Browser };
					$Global:ExecuteTestCommand.Add($TestCommand) > $null;
				}
				if ([System.Convert]::ToBoolean($ProjectsTest[$i].MSTest) -eq $true)
				{
					[string]$Arguments = "`"" + $ProjectsTest[$i].TargetDir + $ProjectsTest[$i].AssemblyName + ".dll`" /Logger:trx /Settings:Local.RunSettings /Diag:`"" +
										 $Global:TestResultDir + "\TestErrorsMSTest-" + $Global:ProjectsTest[$i].AssemblyName + "_" + $Browser + ".log`"";
					[string]$JobName = "UiTest-MSTest_" + $Browser + "_" + $i + $j;
					[PSObject]$TestCommand = New-Object PSObject -Property @{Adapter = "MSTest"; AdapterPath = $Global:MsTestPath; Arguments = $Arguments; JobName = $JobName; AssemblyName = $ProjectsTest[$i].AssemblyName; Browser = $Browser };
					$Global:ExecuteTestCommand.Add($TestCommand) > $null;
				}
			}
		}
		else
		{
			if ([System.Convert]::ToBoolean($Global:ProjectsTest[$i].NUnitTest) -eq $true)
			{
				[string]$Arguments = "`"" + $Global:ProjectsTest[$i].TargetDir + $Global:ProjectsTest[$i].AssemblyName + ".dll`" --config=Default --work=" + $Global:TestResultDir +
									 " --result=`"TestResultNUnit-" + $Global:ProjectsTest[$i].AssemblyName + ".xml`" --output=`"TestOutputNUnit-" +
									 $Global:ProjectsTest[$i].AssemblyName + ".txt`" --err=`"TestErrorsNUnit-" + $Global:ProjectsTest[$i].AssemblyName +
									 ".log`" --trace=Verbose --labels=All --inprocess --domain=Single --dispose-runners --workers=1";
				[string]$JobName = "UiTest-NUnit_" + $i + $j;
				[PSObject]$TestCommand = New-Object PSObject -Property @{Adapter = "NUnit"; AdapterPath = $Global:NUnitConsolePath; Arguments = $Arguments; JobName = $JobName; AssemblyName = $ProjectsTest[$i].AssemblyName; Browser = "Undefined" };
				$Global:ExecuteTestCommand.Add($TestCommand) > $null;
			}
			if ([System.Convert]::ToBoolean($ProjectsTest[$i].MSTest) -eq $true)
			{
				[string]$Arguments = "`"" + $ProjectsTest[$i].TargetDir + $ProjectsTest[$i].AssemblyName + ".dll`" /Logger:trx /Settings:Local.RunSettings /Diag:`"" +
									 $TestResultDir + "\TestErrorsMSTest-" + $Global:ProjectsTest[$i].AssemblyName + ".log`"";
				[string]$JobName = "UiTest-MSTest_" + $i + $j;
				[PSObject]$TestCommand = New-Object PSObject -Property @{Adapter = "MSTest"; AdapterPath = $Global:MsTestPath; Arguments = $Arguments; JobName = $JobName; AssemblyName = $ProjectsTest[$i].AssemblyName; Browser = "Undefined" };
				$Global:ExecuteTestCommand.Add($TestCommand) > $null;
			}
		}
	}
	else
	{
		if ([System.Convert]::ToBoolean($Global:ProjectsTest[$i].NUnitTest) -eq $true)
		{
			[string]$Arguments = "`"" + $Global:ProjectsTest[$i].TargetDir + $Global:ProjectsTest[$i].AssemblyName + ".dll`" --config=Default --work=" + $Global:TestResultDir +
								 " --result=`"TestResultNUnit-" + $Global:ProjectsTest[$i].AssemblyName + ".xml`" --output=`"TestOutputNUnit-" +
								 $Global:ProjectsTest[$i].AssemblyName + ".txt`" --err=`"TestErrorsNUnit-" + $Global:ProjectsTest[$i].AssemblyName +
								 ".log`" --trace=Verbose --labels=All --inprocess --domain=Single --dispose-runners --workers=1"
			[string]$JobName = "NUnit-Test_" + $i + $j
			[PSObject]$TestCommand = New-Object PSObject -Property @{Adapter = "NUnit"; AdapterPath = $Global:NUnitConsolePath; Arguments = $Arguments; JobName = $JobName; AssemblyName = $ProjectsTest[$i].AssemblyName; Browser = "None" };
			$Global:ExecuteTestCommand.Add($TestCommand) > $null;
		}
		if ([System.Convert]::ToBoolean($ProjectsTest[$i].MSTest) -eq $true)
		{
			[string]$Arguments = "`"" + $ProjectsTest[$i].TargetDir + $ProjectsTest[$i].AssemblyName + ".dll`" /Logger:trx /Settings:Local.RunSettings /Diag:`"" +
								 $Global:TestResultDir +"\TestErrorsMSTest-" + $ProjectsTest[$i].AssemblyName + ".log`""
			[string]$JobName = "MSTest-Test_" + $i + $j
			[PSObject]$TestCommand = New-Object PSObject -Property @{Adapter = "MSTest"; AdapterPath = $Global:MsTestPath; Arguments = $Arguments; JobName = $JobName; AssemblyName = $ProjectsTest[$i].AssemblyName; Browser = "None" };
			$Global:ExecuteTestCommand.Add($TestCommand) > $null;
		}
	}
}
$errorResult = "Empty Value"
Write-Host $errorResult;
if ($Global:ExecuteTestCommand.Count -gt 0)
{
	Write-Host "`r`nAssemblies, adapters and Browsers for execute the test."
	$Global:ExecuteTestCommand | Format-Table -AutoSize -Property AssemblyName, Adapter, Browser, JobName | Out-String | %{Write-Host $_}
	Write-Host "Executing the tests and generating the results reports."
	for ($i = 0; $i -lt $Global:ExecuteTestCommand.Count; $i++)
	{
     
	 $JobExecuted =	Start-Job -Name $Global:ExecuteTestCommand[$i].JobName -ScriptBlock {
					param ([string]$AdapterPath, [string]$Arguments, [string]$WorkDir)
					
					# Setting process invocation parameters.
					$oPsi = New-Object -TypeName System.Diagnostics.ProcessStartInfo;
					$oPsi.CreateNoWindow = $true;
					$oPsi.UseShellExecute = $false;
					$oPsi.RedirectStandardOutput = $true;
					$oPsi.RedirectStandardError = $true;
					$oPsi.WorkingDirectory = $WorkDir;
					$oPsi.FileName = $AdapterPath;
					if (![String]::IsNullOrEmpty($Arguments))
					{
						$oPsi.Arguments = $Arguments;
					}
					# Creating process object.
					$oProcess = New-Object -TypeName System.Diagnostics.Process;
					$oProcess.StartInfo = $oPsi;
					# Creating string builders to store stdout and stderr.
					$oStdOutBuilder = New-Object -TypeName System.Text.StringBuilder;
					$oStdErrBuilder = New-Object -TypeName System.Text.StringBuilder;
					# Adding event handers for stdout and stderr.
					$sScripBlock = {
						if (! [String]::IsNullOrEmpty($EventArgs.Data))
						{
							$Event.MessageData.AppendLine($EventArgs.Data);
						}
					};
					$oStdOutEvent = Register-ObjectEvent -InputObject $oProcess -Action $sScripBlock -EventName 'OutputDataReceived' -MessageData $oStdOutBuilder;
					$oStdErrEvent = Register-ObjectEvent -InputObject $oProcess -Action $sScripBlock -EventName 'ErrorDataReceived' -MessageData $oStdErrBuilder;
					# Starting process.
					[Void]$oProcess.Start();
					$oProcess.BeginOutputReadLine();
					$oProcess.BeginErrorReadLine();
					[Void]$oProcess.WaitForExit();
					# Unregistering events to retrieve process output.
					Unregister-Event -SourceIdentifier $oStdOutEvent.Name;
					Unregister-Event -SourceIdentifier $oStdErrEvent.Name;
					$oResult = New-Object -TypeName PSObject -Property ([Ordered]@{
						"ExeFile"  = $AdapterPath;
						"Args"     = $Arguments;
						"ExitCode" = $oProcess.ExitCode;
						"StdOut"   = $oStdOutBuilder.ToString().Trim();
						"StdErr"   = $oStdErrBuilder.ToString().Trim()
					});
					Write-Host "";
					Write-Host "===================== RESULT TEST =====================";
					Write-Host $oResult.StdOut;
					Write-Host "=================== END RESULT TEST ===================";
					Write-Host "";
					Write-Host "";
					Write-Host "===================== ERROR OUTPUT =====================";
					Write-Host "Exited with status code (" $oResult.ExitCode ")";
					Write-Host "";
					Write-Host $oResult.StdErr;			
					Write-Host "=================== END ERROR OUTPUT ===================";
					if($oResult.ExitCode -gt 0)
					{					
                        throw "JOB FAILED"
					}
				} -ArgumentList ($Global:ExecuteTestCommand[$i].AdapterPath, $Global:ExecuteTestCommand[$i].Arguments, $Global:TestResultDir);              

		if ($i -gt 0 -and (($i + 1) % 3) -eq 0)
		{
			Write-Host "`r`nWaiting for the tests end...";
			Wait-Job -Name "*Test*" > $null;
		}
	}
	if (($Global:ExecuteTestCommand.Count % 3) -ne 0)
	{
		Write-Host "`r`nWaiting for the tests end...";
		Wait-Job -Name "*Test*" > $null;
	}
	Write-Host "";
	Write-Host "";
	Write-Host "Generating result for the tests...";
	Receive-Job -Name "*Test*" -Wait -WriteJobInResults -ErrorVariable errorResult;
       
    if($errorResult.Count -gt 0 -and $errorResult[0].FullyQualifiedErrorId -ccontains 'JOB FAILED')
    {
		exit 1;
    }
    else
    {
		exit 0;
    }
}
else
{
	Write-Host "ERROR: It was not possible to generate the commands for the execution of the tests in each adapter." -ForegroundColor Yellow -BackgroundColor Red;
	exit 12345;
}
