Param(
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$HostName,
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$RootUser,
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$RootPass,
  [parameter(mandatory=$true)][ValidateNotNullorEmpty()][string]$UserName,
  [string]$Password = "",
  [string]$FullName = "",
  [string]$Description = ""
)

[System.Collections.ArrayList]$Errors = New-Object System.Collections.ArrayList;

# Validate the params received
if ([string]::IsNullOrEmpty($Password))
{
	[string]$Password = $UserName
}
if ([string]::IsNullOrEmpty($FullName))
{
	[string]$FullName = $UserName
}
if ([string]::IsNullOrEmpty($Description))
{
	[string]$Description = "Test Account Create With Script - Can Delete"
}

[System.Security.SecureString]$RootSecurePass = $RootPass | ConvertTo-SecureString -AsPlainText -Force
[System.Management.Automation.PSCredential]$RootCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $RootUser, $RootSecurePass

# Validate if Local User exist in the Machine
Write-Output "Validating if Local User '$Username' exist.";
try
{
	$UserExist = Invoke-Command -ComputerName $HostName -Credential $RootCredential -ScriptBlock {
		Param ([string]$userName)
		Get-LocalUser -Name $userName -ErrorAction Ignore;
	} -ArgumentList $UserName
}
catch
{
	Write-Output "Error: $($_.Exception.Message)"
}

# Remove the Local User if exist in the Machine
if ($UserExist)
{
	Write-Output "Removing Local User '$UserName'.";
	try
	{
		Invoke-Command -ComputerName $HostName -Credential $RootCredential -ScriptBlock {
			Param ([string]$userName)
			Remove-LocalUser -Name $userName;
		} -ArgumentList $UserName
	}
	catch
	{
		Write-Output "Error: $($_.Exception.Message)"
	}
}

# Create the Local User in the Machine
Write-Output "Creating the Local User '$Username'.";
[System.Security.SecureString]$UserPass = $Password | ConvertTo-SecureString -AsPlainText -Force
try
{
	Invoke-Command -ComputerName $HostName -Credential $RootCredential -ScriptBlock {
		Param ([string]$userName, [System.Security.SecureString]$userPass, [string]$fullName, [string]$description)
		New-LocalUser -Name $userName -FullName $fullName -Description $description -AccountNeverExpires -Password $userPass -PasswordNeverExpires
	} -ArgumentList $UserName, $UserPass, $FullName, $Description
}
catch
{
	Write-Output "Error: $($_.Exception.Message)"
}