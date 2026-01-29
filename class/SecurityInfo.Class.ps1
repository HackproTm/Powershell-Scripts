namespace SecurityInfo.UserInfo {
  enum SecretFormat {
    Text
    Hex
    Base32
  }

  enum SecretAlgorithm {
    SHA1
    SHA256
    SHA512
  }

  class SecureUserInfo {
    [string]$userName = $null
    [string]$userDomain = $null
    [SecureString]$password = $null
    [TotpSetting]$totpSetting = $null

    SecureUserInfo([string]$userName, [string]$userDomain, [SecureString]$password, [TotpSetting]$totpSetting = $null) {
      $this.userName = $userName
      $this.userDomain = $userDomain
      $this.password = $password
      $this.totpSetting = $totpSetting
    }
  }

  class TotpSetting {
    [SecureString]$secret = $null
    [SecretFormat]$secretFormat = $null
    [SecretAlgorithm]$algorithm = [SecretAlgorithm]::SHA1
    [Nullable[int]] $timeStep = $null
    [Nullable[int]] $digits = $null

    TotpSetting([SecureString]$secret, [SecretFormat]$secretFormat = [SecretFormat]::Text, [SecretAlgorithm]$algorithm = [SecretAlgorithm]::SHA1, [int]$timeStep = 30, [int]$digits = 6) {
      $this.secret = $secret
      $this.secretFormat = $secretFormat
      $this.algorithm = $algorithm
      $this.timeStep = $timeStep
      $this.digits = $digits
    }

    SetTotp([SecureString]$secret, [SecretFormat]$secretFormat = [SecretFormat]::Text, [SecretAlgorithm]$algorithm = [SecretAlgorithm]::SHA1, [int]$timeStep = 30, [int]$digits = 6) {
      $this.secret = $secret
      $this.secretFormat = $secretFormat
      $this.algorithm = $algorithm
      $this.timeStep = $timeStep
      $this.digits = $digits
    }
  }
}
