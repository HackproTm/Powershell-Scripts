$IfIndex = (Get-NetIPInterface |
			Where-Object -Property InterfaceAlias -Like "*deloitte*" |
			Where-Object -Property ConnectionState -Eq Connected
			).ifIndex;

$Gateway = '10.26.84.1';

$Ips = @();

$Ips += [System.Net.Dns]::GetHostAddresses('dsubscriptionservices.deloitte.com').IPAddressToString + "/32";    # 10.27.242.30
$Ips += [System.Net.Dns]::GetHostAddresses('qsubscriptionservices.deloitte.com').IPAddressToString + "/32";    # 10.27.242.28
$Ips += [System.Net.Dns]::GetHostAddresses('dmarketingcalendar.deloitte.com').IPAddressToString + "/32";       # 10.146.169.11
$Ips += [System.Net.Dns]::GetHostAddresses('qmarketingcalendar.deloitte.com').IPAddressToString + "/32";       # 10.146.169.11
$Ips += [System.Net.Dns]::GetHostAddresses('qaexchange.usqaex.usqa.com').IPAddressToString + "/32";            # 10.6.3.98

$Ips = $Ips | Select -Unique

ForEach ($Ip In $Ips)
{
	New-NetRoute -DestinationPrefix $Ip -InterfaceIndex $IfIndex -NextHop $Gateway -AddressFamily IPv4 -PolicyStore ActiveStore;
}
