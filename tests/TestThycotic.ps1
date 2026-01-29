Import-Module -Name .\ThycoticServer.psm1 -Force

$AccessToken = Get-ThycoticToken -MFACode "451740"
# $AccessToken = "abcdefghijklmnopqrstuvwxyz1234567890abcdefg"

$Parameters = New-ThycoticSecretSearchParams -IncludeRestricted $true -SearchText "AuditTest"
$Parameters.ToString()

$Secrets = Find-ThycoticSecrets -Token $AccessToken -SearchInfo $Parameters

$Secrets | ForEach-Object {
    Write-Host "Secret ID: $($_.Id), Name: $($_.Name), Description: $($_.Description)"
}
