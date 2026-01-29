Describe "SystemHelpers Module - Out-Log Function" {

  BeforeAll {
    Import-Module -Name "$PSScriptRoot/../modules/SystemHelpers.psm1" -Force
  }

  InModuleScope "SystemHelpers" {
    It "Should log critical error with exception and exit" {
      # Prepare Test Data
      $Message = "Critical error."
      $Exception = [System.Exception]::new("Critical failure")
      $PrefixDate = "Date"
      $PrefixData = @{ "USER" = "Admin" }

      Out-Log -Message $Message -MessageType Critical -PrefixDate $PrefixDate -PrefixData $PrefixData -Exception $Exception | Should -Be "Script exited with code 1."
    }
  }

  AfterAll {
    Remove-Module -Name "SystemHelpers" -Force
  }
}
