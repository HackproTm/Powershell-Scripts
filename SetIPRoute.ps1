Param(
	[parameter(Mandatory=$False, Position=0)][switch]$Create
)

$ConfirmPreference = 'None';	# See 'Get-Help about_Preference_Variables';
$IpIgnore = "127", "224", "255";
$PslIp = @("10.10.10.0/24", "10.10.1.0/24", "10.20.1.0/24", "192.168.151.13/32");

$Adapters = Get-NetAdapter -Name "*" | Where-Object -Property Status -Eq "Up";
$Adapters | Format-Table;

If ($Adapters.Count -Gt 1)
{
    $Options = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription];
    $I = 0;
    
	ForEach($Adapter In $Adapters)
	{
        $I++;
        $Choice = "&" + $I + " - " + $Adapter.Name;
        $Options.Add((New-Object System.Management.Automation.Host.ChoiceDescription $Choice, $Adapter.InterfaceDescription)) > $null;
	}
    $Options.Add((New-Object System.Management.Automation.Host.ChoiceDescription "&Q - Quit", "Quit")) > $null;

    $Result = $Host.UI.PromptForChoice("Multiple network interfaces were detected.", "Choice the ifIndex from interface to configure?", $Options, 0);
    If ($Result -Lt 0 -Or $Result -Eq $Options.Count - 1)
    {
        Exit;
    }

    $InterfaceIndex = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Where-Object ifIndex -Eq $Adapters[$Result].ifIndex).ifIndex;
	$Gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Where-Object ifIndex -Eq $Adapters[$Result].ifIndex).NextHop;
}
Else
{
	$InterfaceIndex = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").ifIndex;
	$Gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop;
}

ForEach ($Ip In $PslIp)
{
	$Exist = Get-NetRoute -DestinationPrefix $Ip -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
	If ($Exist)
	{
		If (!$Create)
		{
			Write-Host "Removing... " $Ip
		}
		Remove-NetRoute -DestinationPrefix $Ip -AddressFamily IPv4 -PolicyStore ActiveStore -Confirm:$False -ErrorAction SilentlyContinue;
	}
	If ($Create)
	{
		New-NetRoute -DestinationPrefix $Ip.ToString() -InterfaceIndex $InterfaceIndex -NextHop $Gateway -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
	}
}

For ($I = 1; $I -lt 255; $I++)
{
	If ($IpIgnore.IndexOf($I.ToString()) -Eq -1)
	{
		$Route = $I.ToString() + ".0.0.0/8";
		$Exist = Get-NetRoute -DestinationPrefix $Route -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
		If ($Exist)
		{
			If (!$Create)
			{
				Write-Host "Removing... " $Route
			}
			Remove-NetRoute -DestinationPrefix $Route -AddressFamily IPv4 -PolicyStore ActiveStore -Confirm:$False -ErrorAction SilentlyContinue;
		}
		If ($Create)
		{
			New-NetRoute -DestinationPrefix $Route -InterfaceIndex $InterfaceIndex -NextHop $Gateway -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
		}
	}
}
