Import-Module -Name "$PSScriptRoot\Check-MedicalAppointments.psm1" -Force

$AppointmentInfo = [PSCustomObject]@{
    SpecialityId = 65
    AppointmentType = 63
    DoctorId = 91492811
    EntityId = 10
    UserIdType = 'C'
    UserId = 13854016
}

$EMailInfo = [PSCustomObject]@{
    SmtpServer = "smtp.gmail.com"
    SmtpPort = 587
    To = "hackpro.ems@gmail.com"
}

$UserInfoPath = "$ENV:USERPROFILE\hackpro.ems.xml"

Get-MedicalAppointments -AppointmentInfo $AppointmentInfo -EMailInfo $EMailInfo -UserInfoPath "$UserInfoPath"
