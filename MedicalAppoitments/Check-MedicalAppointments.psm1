# Paths
[string] $DEFAULT_LOG_PATH = "$ENV:TEMP\Check-MedicalAppointment.log"
[string] $DEFAULT_JSON_PATH = "$ENV:TEMP\Availability.json"
[string] $DEFAULT_CREDENTIALS_PATH = "$ENV:USERPROFILE\$ENV:USERNAME.xml"
[string] $DEFAULT_SMTP_SERVER = "smtp.gmail.com"
[int] $DEFAULT_SMTP_PORT = 587

function Set-UserCredentials {
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = "Username for the email account.")]
    [ValidateNotNullOrEmpty()]
    [string] $UserName,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $false, HelpMessage = "Password for the email account.")]
    [ValidateNotNullOrEmpty()]
    [string] $SmtpServer = $DEFAULT_SMTP_SERVER,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipeline = $false, HelpMessage = "SMTP Port for the email account.")]
    [ValidateNotNullOrEmpty()]
    [int] $SmtpPort = $DEFAULT_SMTP_PORT,

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipeline = $false, HelpMessage = "Path to save the credentials file.")]
    [ValidateNotNullOrEmpty()]
    [string] $UserInfoPath = $DEFAULT_CREDENTIALS_PATH
  )

  try {
    Export-Clixml -InputObject $Credential -Path "$UserInfoPath"
    Write-Log "Credentials saved successfully to: $UserInfoPath"
  }
  catch {
    Write-Log "[ERROR] Saving Credentials: $_"
  }
}

function Write-Log {
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = "Message to the log.")]
    [ValidateNotNullOrEmpty()]
    [string] $Message,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $false, HelpMessage = "Path to the log file.")]
    [ValidateNotNullOrEmpty()]
    [string] $LogPath = $DEFAULT_LOG_PATH
  )

  $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -Path "$LogPath" -Value "[$Timestamp] $Message"
}

Export-ModuleMember -Function Write-Log

function Get-MedicalAppointments {
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false, HelpMessage = "Medical appointment to check availability.")]
    [ValidateNotNullOrEmpty()]
    [PSCustomObject] $AppointmentInfo,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $false, HelpMessage = "Email settings to send notifications.")]
    [ValidateNotNullOrEmpty()]
    [PSCustomObject] $EMailInfo,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipeline = $false, HelpMessage = "Path to the user credentials file.")]
    [ValidateNotNullOrEmpty()]
    [string] $UserInfoPath = $DEFAULT_CREDENTIALS_PATH
  )

  # Parameters validation
  try {
    # Validate that AppointmentInfo has all required properties
    $RequiredProps = @('SpecialityId', 'AppointmentType', 'DoctorId', 'EntityId', 'UserIdType', 'UserId')
    foreach ($Property in $RequiredProps) {
      if (-not $AppointmentInfo.PSObject.Properties.Match($Property)) {
        throw "AppointmentInfo is missing required property: $Property"
      }
    }

    # Validate that UserInfoPath exists and contains a valid credential
    if (-Not (Test-Path "$UserInfoPath")) {
      throw "Credential file not found at: $UserInfoPath"
    }

    Write-Log "Loading email credentials from: $UserInfoPath"
    $Credential = Import-Clixml -Path "$UserInfoPath"
    if (-Not $Credential.UserName) {
      throw "Credential object does not contain a UserName."
    }

    $From = $Credential.UserName
    Write-Log "Loaded email credentials for user: $From"
  }
  catch {
    Write-Log "[ERROR] Loading Credentials: $_"
    Exit 1
  }

  # Main logic
  try {
    Write-Log "Starting appointment availability check."

    $Uri = "https://sancamilo.gnetwork.com.co/mat_cibot/public/web/disponibilidad"
    $Body = @{
      espe_id     = $AppointmentInfo.SpecialityId
      tico_id     = $AppointmentInfo.AppointmentType
      usua_cedula = $AppointmentInfo.DoctorId
      enti_id     = $AppointmentInfo.EntityId
      tiid_id     = $AppointmentInfo.UserIdType
      pers_cedula = $AppointmentInfo.UserId
    } -Join '&'

    $Response = Invoke-RestMethod -Uri $Uri -Method POST -ContentType "application/x-www-form-urlencoded" -Body $Body
    $RawResponse = $Response | ConvertTo-Json -Depth 5
    Write-Log "API Response:`n$RawResponse"

    if ($Response.Disponibilidad -and $Response.Disponibilidad.PSObject.Properties.Count -gt 0) {
      Write-Log "Appointments found."

      $Response.Disponibilidad | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 $DEFAULT_JSON_PATH

      try {
        Send-MailMessage  `
          -From $From `
          -To $EMailInfo.To `
          -Subject "Available Appointments Found" `
          -Body $Response.View `
          -BodyAsHtml $true `
          -SmtpServer $EMailInfo.SmtpServer `
          -Port $EMailInfo.SmtpPort `
          -Credential $Credential `
          -UseSsl `
          -Attachments $DEFAULT_JSON_PATH

        Write-Log "Email sent successfully."
        Remove-Item -Path $DEFAULT_JSON_PATH -ErrorAction SilentlyContinue
      }
      catch {
        Write-Log "ERROR sending email: $_"
      }
    }
    else {
      Write-Log "No appointments available."
    }
  }
  catch {
    Write-Log "ERROR during API call: $_"
    if ($_.Exception.Response -and $_.Exception.Response.GetResponseStream()) {
      $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $ErrorBody = $Reader.ReadToEnd()
      Write-Log "API Error Response Body:`n$ErrorBody"
    }
  }
}

Export-ModuleMember -Function Get-MedicalAppointments
