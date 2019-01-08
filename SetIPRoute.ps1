Param(
	[parameter(Mandatory=$False, Position=0)][switch]$Create
)

$ConfirmPreference = 'None'; # See 'Get-Help about_Preference_Variables';
$IpIgnore = "10", "127", "224", "255";
$InterfaceIndex = 10;        # Get via 'ifIndex' using 'Get-NetAdapter -Name "*" | Format-Table -Property "Name", "InterfaceDescription", "ifIndex", "Status"'
$Gateway = "172.28.200.1";   # Get via 'Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select  NextHop'
$PslIp = @("10.10.10.0/24", "10.10.1.0/24", "10.20.1.0/24", "192.168.151.13/32");

ForEach ($Ip In $PslIp)
{
	$Exist = Get-NetRoute -DestinationPrefix $Ip -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
	If ($Exist)
	{
		Remove-NetRoute -DestinationPrefix $Ip -AddressFamily IPv4 -PolicyStore ActiveStore -Confirm:$False -ErrorAction SilentlyContinue;
	}
	If ($Create)
	{
		New-NetRoute -DestinationPrefix $Ip.ToString() -InterfaceIndex $InterfaceIndex -NextHop $Gateway -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
	}
}

For ($Ip = 1; $Ip -lt 255; $Ip++)
{
	If ($IpIgnore.IndexOf($Ip.ToString()) -Eq -1)
	{
		$Route = $Ip.ToString() + ".0.0.0/8";
		$Exist = Get-NetRoute -DestinationPrefix $Route -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
		If ($Exist)
		{
			Remove-NetRoute -DestinationPrefix $Route -AddressFamily IPv4 -PolicyStore ActiveStore -Confirm:$False -ErrorAction SilentlyContinue;
		}
		If ($Create)
		{
			New-NetRoute -DestinationPrefix $Route -InterfaceIndex $InterfaceIndex -NextHop $Gateway -AddressFamily IPv4 -PolicyStore ActiveStore -ErrorAction SilentlyContinue;
		}
	}
}
