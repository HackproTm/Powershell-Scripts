namespace ThycoticServer.Secrets.Search {

  enum ThycoticSortOrder {
    Asc
    Desc
  }

  class ThycoticSecretSearchFilter {
    [Nullable[bool]] $allowDoubleLock = $null
    [Nullable[bool]] $doNotCalculateTotal = $null
    [Nullable[int]] $doubleLockId = $null
    [string[]] $extendedFields = $null
    [Nullable[int]] $extendedTypeId = $null
    [Nullable[int]] $folderId = $null
    [string] $heartbeatStatus = $null
    [Nullable[bool]] $includeActive = $null
    [Nullable[bool]] $includeInactive = $null
    [Nullable[bool]] $includeRestricted = $null
    [Nullable[bool]] $includeSubFolders = $null
    [Nullable[bool]] $isExactMatch = $null
    [Nullable[bool]] $onlyRPCEnabled = $null
    [Nullable[bool]] $onlySharedWithMe = $null
    [int[]] $passwordTypeIds = $null
    [string] $permissionRequired = $null
    [string] $scope = $null
    [string] $searchField = $null
    [string] $searchFieldSlug = $null
    [string] $searchText = $null
    [Nullable[int]] $secretTemplateId = $null
    [Nullable[int]] $siteId = $null

    ThycoticSecretSearchFilter() {}

    [string] ToString() {
      $Pairs = @()
      $Properties = $this.PSObject.Properties | Where-Object { $null -ne $_.Value }
      foreach ($Property in $Properties) {
        if ($Property.Value -Is [System.Array] -And $Property.Value.Count -gt 0) {
          $PropertyValue = ($Property.Value -Join ",")
        } elseif ($Property.Value -Is [string] -And $Property.Value -eq "") {
          continue
        } else {
          $PropertyValue = $Property.Value
        }
        $Pairs += [System.Web.HttpUtility]::UrlEncode("filter.$($Property.Name)") + "=" + [System.Web.HttpUtility]::UrlEncode("$PropertyValue")
      }
      return $Pairs -Join "&"
    }
  }

  class ThycoticSecretSearchOrder {
    [Nullable[int]] $_index = $null
    [string] $name
    [ThycoticSortOrder] $direction = [ThycoticSortOrder]::Asc
    [Nullable[int]] $priority = $null

    ThycoticSecretSearchOrder([int]$index, [string] $name, [ThycoticSortOrder] $direction = [ThycoticSortOrder]::Asc) {
      $this._index = $index
      $this.name = $name
      $this.direction = $direction
    }

    [string] ToString() {
      $Pairs = @()
      $Properties = $this.PSObject.Properties | Where-Object { $null -ne $_.Value -and $_.Name -NotLike '_*' }
      foreach ($Property in $Properties) {
        if ($Property.Value -Is [string] -And $Property.Value -eq "") {
          continue
        } else {
          $PropertyValue = $Property.Value
        }
        $Pairs += [System.Web.HttpUtility]::UrlEncode("sortBy[$($this._index)].$($Property.Name)") + "=" + [System.Web.HttpUtility]::UrlEncode("$PropertyValue")
      }
      return $Pairs -Join "&"
    }
  }

  class ThycoticSecretSearchParams {
    [ThycoticSecretSearchFilter] $filter = $null
    [ThycoticSecretSearchOrder[]] $orderBy = $null
    [Nullable[int]] $skip = $null
    [Nullable[int]] $take = $null

    ThycoticSecretSearchParams() {}

    [string] ToString() {
      $Pairs = @()
      if ($this.filter) {
        $Pairs += $this.filter.ToString()
      }
      if ($this.orderBy) {
        foreach ($Order in $this.orderBy) {
          $Pairs += $Order.ToString()
        }
      }
      if ($null -ne $this.skip) {
        $Pairs += "skip=" + [System.Web.HttpUtility]::UrlEncode("$($this.skip)")
      }
      if ($null -ne $this.take) {
        $Pairs += "take=" + [System.Web.HttpUtility]::UrlEncode("$($this.take)")
      }
      return $Pairs -Join "&"
    }
  }
}
