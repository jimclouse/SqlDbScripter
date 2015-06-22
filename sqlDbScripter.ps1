param (
  [string]  $databases = "", # comma-delimited, no spaces 
  [string]  $hostName  = "",
  [string]  $login     = "",
  [string]  $password  = "",
  [string]  $outputDirectory  = "",
  [switch] $jobsOnly  = $False
)
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Text.Encoding') | out-null
$conn = new-object Microsoft.SqlServer.Management.Common.ServerConnection
$conn.LoginSecure = $True
if ( -not([string]::IsNullOrEmpty($login))){
        if ([string]::IsNullOrEmpty($password)) {
          $password = Read-Host 'Password?'
        }
        $conn.LoginSecure = $False
        $conn.Login = $login
        $conn.Password = $password
}

Write-Host "Processing DB: $hostName, login: $login, password: $password, outputDirectory: $outputDirectory`r`n"

$databasesToDump = $null

if ( -not [String]::IsNullOrEmpty($databases) ){
        $databasesToDump = $databases -split " "
        #Write-Host $databasesToDump $databasesToDump.gettype() $databasesToDump.count
}

$usingOutputDirectory = (-not([string]::IsNullOrEmpty($outputDirectory)))
if ($usingOutputDirectory -eq $True){
  New-Item -ItemType Directory -Force -Name $outputDirectory | Out-Null
  pushd $outputDirectory | Out-Null  
}

$conn.ServerInstance = $hostName

$srv = new-object Microsoft.SqlServer.Management.Smo.Server($conn)
foreach ($_ in $srv.Databases){
  if ( $jobsOnly -eq $True -or $_.IsSystemObject -eq $True) { continue }
  if ( -not ($databasesToDump -eq $null )){
        if ([Array]::IndexOf($databasesToDump, $_.Name) -eq -1){
                "Skipping DB {0}" -f $_.Name | Write-Host
                continue
        }      
  }

  New-Item -ItemType Directory -Force -Name $_.Name | Out-Null
  pushd $_.Name | Out-Null
  Write-Host "Processing DB" $_.Name
 
  New-Item -ItemType Directory -Force -Name sprocs | Out-Null
  pushd sprocs | Out-Null
  $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
  $scriptingOptions.ExtendedProperties = $True
  $scriptingOptions.Permissions     = $True
  $scriptingOptions.Encoding        = [System.Text.Encoding]::UTF8  
  "  Writing sprocs  " -f $_.Name | Write-Host -nonewline
  $_.StoredProcedures | foreach {
    $fileName = $_.Schema + '.' + $_.Name + '.sql'
    if ( -not $_.IsSystemObject ) { 
      Write-Host "+" -nonewline
      $_.script($scriptingOptions) | Out-File $fileName -Encoding utf8
    }
    else { Write-Host "." -nonewline  }
  }
  Write-Host
  popd | Out-Null # sprocs

  New-Item -ItemType Directory -Force -Name tables | Out-Null
  New-Item -ItemType Directory -Force -Name indexes | Out-Null
  New-Item -ItemType Directory -Force -Name triggers | Out-Null
  
  pushd tables | Out-Null
  " Writing tables " -f $_.Name | Write-Host
  $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
  $scriptingOptions.DriAll           = $True
  $scriptingOptions.Permissions      = $True
  $scriptingOptions.ExtendedProperties = $True
  $scriptingOptions.Encoding = [System.Text.Encoding]::UTF8
  $_.Tables | foreach {
    $TableName = $_.Name
	$SchemaName = $_.Schema
    $fileName = $_.Schema + '.' + $TableName + '.sql'
    if ( -not $_.IsSystemObject ){
	  Write-Host "  "$TableName
      $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
    }
    else { Write-Host "." -nonewline  }
	
    $_.Indexes | foreach {
      $fileName = '..\indexes\' + $SchemaName + '.' + $TableName + '.' + $_.Name + '.sql'
	  $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
	  Write-Host "      " $fileName
    }
	$_.Triggers | foreach {
      $fileName = '..\triggers\' + $SchemaName + '.' + $TableName + '.' + $_.Name + '.sql'
	  $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
	  Write-Host "      " $fileName
    }
  }
  Write-Host
  popd | Out-Null # tables
  
  New-Item -ItemType Directory -Force -Name views | Out-Null
  pushd views | Out-Null
  " Writing views " -f $_.Name | Write-Host -nonewline
  $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
  $scriptingOptions.DriAll           = $True
  $scriptingOptions.ClusteredIndexes = $True
  $scriptingOptions.Indexes          = $True
  $scriptingOptions.XmlIndexes       = $True
  $scriptingOptions.Permissions      = $True
  $scriptingOptions.ExtendedProperties = $True
  $scriptingOptions.Encoding = [System.Text.Encoding]::UTF8
  $_.Views | foreach {
    $fileName = $_.Schema + '.' + $_.Name + '.sql'
    if ( -not $_.IsSystemObject ){
      Write-Host "+" -nonewline
      $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
    }
    else { Write-Host "." -nonewline  }
  }
  Write-Host
  popd | Out-Null # views
  
  New-Item -ItemType Directory -Force -Name udfs | Out-Null
  pushd udfs | Out-Null
  " Writing udfs" -f $_.Name | Write-Host
  $scriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
  $scriptingOptions.ExtendedProperties = $True
  $scriptingOptions.Encoding        = [System.Text.Encoding]::UTF8
  $scriptingOptions.Permissions     = $True
  $_.UserDefinedFunctions | foreach {
    $fileName = $_.Schema + '.' + $_.Name + '.sql'
    if ( -not $_.IsSystemObject ){
      $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
    }
  }
  $_.UserDefinedTableTypes | foreach {
    $fileName = $_.Schema + '.' + $_.Name + '.sql'
    if ( -not $_.IsSystemObject ){
      $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
    }
  }
  $_.UserDefinedDataTypes | foreach {
    $fileName = $_.Schema + '.' + $_.Name + '.sql'
    if ( -not $_.IsSystemObject ){
      $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
    }
  }
  $_.UserDefinedAggregates | foreach {
    $fileName = $_.Schema + '.' + $_.Name + '.sql'
    if ( -not $_.IsSystemObject ){
      $_.Script($scriptingOptions) | Out-File $fileName -Encoding utf8
    }
  }  
  popd | Out-Null # udfs

  popd | Out-Null # db directory
}

Write-Host " Writing jobs " -nonewline
New-Item -ItemType Directory -Force jobs | Out-Null
pushd jobs | Out-Null
foreach ($job in $srv.JobServer.Jobs){
  Write-Host "." -nonewline
  # Out-File -LiteralPath isn't always available: replace any zany/wildcard filename chars with a dash
  $jobName = $job.Name -Replace "[^\w\d\s{}()&@._+=\-]+", "-" -Replace "^-+|-+$"
  $job.script() | Out-File $jobName -Encoding utf8
}
Write-Host
popd | Out-Null # jobs

if ($usingOutputDirectory -eq $True){
  popd | Out-Null # output directory
}
