# Secret Server Rest API (11.1.8)
# This module contains functions to interact with Thycotic Secret Server via its REST API.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Set-Variable -Option Constant -Visibility Private -Name DEFAULT_THYCOTIC_BASE_URL -Value ([string]"https://uspcs.us.deloitte.com")
Set-Variable -Option Constant -Visibility Private -Name DEFAULT_CONTENT_TYPE_FORM -Value ([string]"application/x-www-form-urlencoded")
Set-Variable -Option Constant -Visibility Private -Name DEFAULT_CONTENT_TYPE_JSON -Value ([string]"application/json")

# Load the ThycoticServer class definition
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClassFilePath = Join-Path -Path "$ScriptRoot" -ChildPath "ThycoticServer.Class.ps1"
. $ClassFilePath

<#
.SYNOPSIS
Creates a ThycoticSecretSearchParams object for searching secrets in Thycotic Secret Server.

.DESCRIPTION
The New-ThycoticSecretSearchParams function constructs and returns a ThycoticSecretSearchParams object, which can be used to define search filters and ordering for querying secrets in Thycotic Secret Server via its API.
You can specify various filter parameters (such as folder, template, or status) and ordering options to customize the search.
This function is typically used as input for other functions that interact with the Thycotic API.

.PARAMETER AllowDoubleLock
Specifies whether to include secrets that allow double lock. Accepts $true, $false, or $null.

.PARAMETER DoNotCalculateTotal
If set to $true, the total count of secrets will not be calculated.

.PARAMETER DoubleLockId
Filters secrets by a specific double lock ID.

.PARAMETER ExtendedFields
An array of extended field names to include in the search.

.PARAMETER ExtendedTypeId
Filters secrets by a specific extended type ID.

.PARAMETER FolderId
Filters secrets by a specific folder ID.

.PARAMETER HeartbeatStatus
Filters secrets by their heartbeat status.

.PARAMETER IncludeActive
Specifies whether to include active secrets.

.PARAMETER IncludeInactive
Specifies whether to include inactive secrets.

.PARAMETER IncludeRestricted
Specifies whether to include restricted secrets.

.PARAMETER IncludeSubFolders
Specifies whether to include secrets from subfolders.

.PARAMETER IsExactMatch
If set to $true, the search will look for exact matches.

.PARAMETER OnlyRPCEnabled
Specifies whether to include only secrets with RPC enabled.

.PARAMETER OnlySharedWithMe
Specifies whether to include only secrets shared with the current user.

.PARAMETER PasswordTypeIds
An array of password type IDs to filter the search.

.PARAMETER PermissionRequired
Filters secrets by required permission.

.PARAMETER Scope
Specifies the scope of the search.

.PARAMETER SearchField
Specifies the field to search on.

.PARAMETER SearchFieldSlug
Specifies the slug of the search field.

.PARAMETER SearchText
The text to search for in secrets.

.PARAMETER SecretTemplateId
The secret template ID to filter the search.

.PARAMETER SiteId
Filters secrets by a specific site ID.

.PARAMETER OrderBy
An array of hashtables or ThycoticSecretSearchOrder objects to define the ordering of the search results.

.PARAMETER Skip
The number of secrets to skip (for paging).

.PARAMETER Take
The number of secrets to return (for paging).

.EXAMPLE
PS C:\> $params = New-ThycoticSecretSearchParams -SearchText "admin" -IncludeActive $true -Take 10

Creates a search parameter object to find active secrets containing "admin" in their fields, returning up to 10 results.

.EXAMPLE
PS C:\> $params = New-ThycoticSecretSearchParams -FolderId 123 -OrderBy @{ Name = "Name"; Direction = "Asc" }

Creates a search parameter object to find secrets in folder 123, ordered by name ascending.

.LINK
https://updates.thycotic.net/secretserver/restapiguide/TokenAuth/#tag/Secrets/operation/SecretsService_SearchV2
#>
function New-ThycoticSecretSearchParams {
  param(
    # Filter parameters (flattened)
    [Nullable[bool]] $AllowDoubleLock,
    [Nullable[bool]] $DoNotCalculateTotal,
    [Nullable[int]] $DoubleLockId,
    [string[]] $ExtendedFields,
    [Nullable[int]] $ExtendedTypeId,
    [Nullable[int]] $FolderId,
    [string] $HeartbeatStatus,
    [Nullable[bool]] $IncludeActive,
    [Nullable[bool]] $IncludeInactive,
    [Nullable[bool]] $IncludeRestricted,
    [Nullable[bool]] $IncludeSubFolders,
    [Nullable[bool]] $IsExactMatch,
    [Nullable[bool]] $OnlyRPCEnabled,
    [Nullable[bool]] $OnlySharedWithMe,
    [int[]] $PasswordTypeIds,
    [string] $PermissionRequired,
    [string] $Scope,
    [string] $SearchField,
    [string] $SearchFieldSlug,
    [string] $SearchText,
    [Nullable[int]] $SecretTemplateId,
    [Nullable[int]] $SiteId,

    # OrderBy parameters (array of hashtables or objects)
    [object[]] $OrderBy,

    # Paging parameters
    [Nullable[int]] $Skip,
    [Nullable[int]] $Take
  )

  # Build filter if any filter parameter is provided
  $FilterParams = @{}
  foreach ($FilterName in ([ThycoticSecretSearchFilter].GetProperties() | ForEach-Object { $_.Name })) {
    if ($PSBoundParameters.ContainsKey($FilterName)) {
      $filterParams[$FilterName] = $PSBoundParameters[$FilterName]
    }
  }
  $Filter = $null
  if ($FilterParams.Count -gt 0) {
    $Filter = [ThycoticSecretSearchFilter]::new()
    foreach ($Key in $FilterParams.Keys) {
      $Filter.$Key = $FilterParams[$Key]
    }
  }

  # Build orderBy array if provided
  $OrderByArr = $null
  if ($OrderBy) {
    $OrderByArr = @()
    for ($Index = 0; $Index -lt $OrderBy.Count; $Index++) {
      $OrderItem = $OrderBy[$Index]
      if ($OrderItem -is [ThycoticSecretSearchOrder]) {
        $OrderItem._index = $Index
        $OrderByArr += $OrderItem
      } elseif ($OrderItem -is [HashTable] -or $OrderItem -is [PSCustomObject]) {
        $Name = $OrderItem.Name
        $Direction = if ($OrderItem.PSObject.Properties.Match('Direction')) { [ThycoticSortOrder]$OrderItem.direction } else { [ThycoticSortOrder]::Asc }
        $OrderObj = [ThycoticSecretSearchOrder]::new($Index, $Name, $Direction)
        if ($OrderItem.PSObject.Properties.Match('Priority')) { $OrderObj.priority = $OrderItem.Priority }
        $OrderByArr += $OrderObj
      } elseif ($OrderItem -is [String]) {
        $Name = $OrderItem
        $OrderObj = [ThycoticSecretSearchOrder]::new($Index, $Name)
        $OrderByArr += $OrderObj
      }
    }
  }

  $ParamsObj = [ThycoticSecretSearchParams]::new()
  if ($Filter) { $ParamsObj.filter = $Filter }
  if ($OrderByArr) { $ParamsObj.orderBy = $OrderByArr }
  if ($PSBoundParameters.ContainsKey('Skip')) { $ParamsObj.skip = $Skip }
  if ($PSBoundParameters.ContainsKey('Take')) { $ParamsObj.take = $Take }
  return $ParamsObj
}

Export-ModuleMember -Function New-ThycoticSecretSearchParams

<#
.SYNOPSIS
Retrieves an access token from the Thycotic Secret Server API using user credentials and optional MFA.

.DESCRIPTION
The Get-ThycoticToken function authenticates against the Thycotic Secret Server API using stored user credentials and, if required,
a one-time password (OTP) for multi-factor authentication (MFA).
It sends a POST request to the Thycotic token endpoint with the credentials in application/x-www-form-urlencoded format.
The function supports retry logic and logs all relevant events and errors.

.PARAMETER UserName
The username to use for authentication (must be in the format DOMAIN\UserName). If not specified, the current Windows user is used.

.PARAMETER PathPass
The path where the encrypted credentials file is stored. If not specified, the user's home directory is used.

.PARAMETER MFACode
The One Time Password (OTP) for multi-factor authentication, if required. If not specified, no OTP header is sent.

.PARAMETER ThycoticUrl
The base URL for the Thycotic API. If not specified, the default is the value provided in the constant DEFAULT_THYCOTIC_BASE_URL.

.PARAMETER MaxAttempts
The maximum number of attempts to retrieve the token. Default is 2. Must be between 1 and 10.

.EXAMPLE
PS C:\> Get-ThycoticToken

Retrieves a Thycotic access token for the current Windows user using stored credentials.

.EXAMPLE
PS C:\> Get-ThycoticToken -UserName "MYDOMAIN\User1" -MFACode "123456"

Retrieves a Thycotic access token for MYDOMAIN\User1 using stored credentials and the provided OTP for MFA.

.EXAMPLE
PS C:\> Get-ThycoticToken -UserName "MYDOMAIN\User1" -PathPass "C:\SecureCreds" -MFACode "654321" -MaxAttempts 3

Retrieves a Thycotic access token for MYDOMAIN\User1 using credentials stored in C:\SecureCreds, with the provided OTP, retrying up to 3 times if necessary.

.LINK
https://uspcs.us.deloitte.com/USPCS/documents/restapi/OAuth/

.LINK
https://updates.thycotic.net/secretserver/restapiguide/OAuth/

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-restmethod

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential

.LINK
https://learn.microsoft.com/en-us/dotnet/api/system.web.httputility.urlencode
#>
function Get-ThycoticToken {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, HelpMessage = "Username to use for the credentials (use the format DOMAIN\UserName).")]
    [string]$UserName = $DEFAULT_USERNAME,

    [Parameter(Mandatory = $false, HelpMessage = "Path to get the credentials encryted.")]
    [string]$PathPass = $DEFAULT_SECURE_FULLPATH,

    [Parameter(Mandatory = $false, HelpMessage = "One Time Password (OTP) for MFA, if required.")]
    [string]$MFACode = "",

    [Parameter(Mandatory = $false, HelpMessage = "Base URL for the Thycotic API.")]
    [string]$ThycoticUrl = $DEFAULT_THYCOTIC_BASE_URL,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of attempts to retrieve the token. Default is 2 and can be set between 1 and 10.")]
    [ValidateRange(1, 10)]
    [int]$MaxAttempts = 2
  )

  # Get the user credentials
  $Credential = Get-UserCredentials -UserName "$UserName" -PathPass "$PathPass"

  # Set the URI for the Thycotic API token endpoint
  $Uri = "$ThycoticUrl/USPCS/oauth2/token"

  # Set the headers for the request
  $Headers = @{
    "Content-Type" = $DEFAULT_CONTENT_TYPE_FORM
  }
  if ($MFACode) {
    $Headers += @{
      "OTP" = "$MFACode"
    }
  }

  # Set the Body for the request
  $BodyInfo = @{
    "grant_type" = "password"
    "username" = "$(($Credential.UserName -Split "\\")[-1])"
    "password" = "$($Credential.GetNetworkCredential().Password)"
    "domain" = "$(($Credential.UserName -Split "\\")[0])"
  }
  # Encode the keys and values for URL encoding
  $Body = ($BodyInfo.Keys | ForEach-Object {
    [System.Web.HttpUtility]::UrlEncode($_) + "=" + [System.Web.HttpUtility]::UrlEncode($BodyInfo[$_])
  }) -Join "&"

  $Attemp = 1
  do {
    try {
      Out-Log -Message "Attempting to retrieve the Thycotic Server token. Attempt $Attemp of $MaxAttempts" -MessageType "Information"
      Out-Log -Message "Request URI: POST $Uri" -MessageType "Information"
      # Make the POST request to retrieve the token
      $Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Body
      if ($Response.Access_Token) {
        Out-Log -Message "Thycotic Server token retrieved successfully." -MessageType "Information"
        return $Response.Access_Token
      } else {
        Out-Log -Message "No Thycotic Server token found in the response." -ForceExit
      }
    }
    catch {
      Out-Log -Message "Failed to retrieve the Thycotic Server token." -ExceptionInfo $_
    }
    $Attemp++
    if ($Attemp -gt $MaxAttempts) {
      Out-Log -Message "Maximum attempts reached. Exiting." -ForceExit
    }
    Start-Sleep -Seconds 2
  } while ($Attemp -le $MaxAttempts)
}

Export-ModuleMember -Function Get-ThycoticToken

# https://uspcs.us.deloitte.com/USPCS/documents/restapi/TokenAuth/#tag/Secrets/operation/SecretsService_Search
function Find-ThycoticSecrets {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, HelpMessage = "Thycotic Server token to use for authentication.")]
    [string] $Token,

    [Parameter(Mandatory = $false, HelpMessage = "Search information to find secrets.")]
    [ThycoticSecretSearchParams] $SearchInfo = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Base URL for the Thycotic API.")]
    [string] $ThycoticUrl = $DEFAULT_THYCOTIC_BASE_URL
  )

  # Set the URI for the Thycotic API search endpoint
  $Uri = "$ThycoticUrl/USPCS/api/v1/secrets"

  # Set the headers for the request
  $Headers = @{
    "Content-Type" = $DEFAULT_CONTENT_TYPE_JSON
    Authorization = "Bearer $Token"
  }

  try {
    # Initialize variables for pagination and results
    $AllRecords = @()
    $Skip = 0
    $Take = if ($SearchInfo -and $SearchInfo.Take) { $SearchInfo.Take } else { 10 }
    $HasNext = $true

    # If SearchInfo is not provided, create a new instance
    if (-not $SearchInfo) {
      $SearchInfo = [ThycoticSecretSearchParams]::new()
    }

    while ($HasNext) {
      # Actualiza los parámetros de paginación
      $SearchInfo.skip = $Skip
      $SearchInfo.take = $Take

      # Use the ToString() method of ThycoticSecretSearchParams to build the query string
      $QueryString = $SearchInfo.ToString()
      $RequestUri = if ($QueryString) { "$Uri`?$QueryString" } else { $Uri }

      Out-Log -Message "Request URI: GET $Uri" -MessageType "Information"
      $Response = Invoke-RestMethod -Uri $RequestUri -Method Get -Headers $Headers

      if ($Response -and $Response.records) {
        $AllRecords += $Response.records
      }

      # Check if there are more records to fetch
      $HasNext = $false
      if ($Response.PSObject.Properties.Match('hasNext') -and $Response.hasNext) {
        $HasNext = $Response.hasNext
      }
      if ($Response.PSObject.Properties.Match('nextSkip')) {
        $Skip = $Response.nextSkip
      } else {
        $Skip += $Take
      }
      Start-Sleep -Seconds 2
    }

    return $AllRecords
  }
  catch {
    Out-Log -Message "Failed to retrieve the Thycotic Secrets." -ExceptionInfo $_
  }
}

Export-ModuleMember -Function Find-ThycoticSecrets
