[CmdletBinding()]
param (
	[Parameter(Mandatory=$true)]
	[string] $SolutionDir,
	[Parameter(Mandatory=$true)]
	[string] $BuildDir,
	[Parameter(Mandatory = $false)]
	[string]$ReleasesDir = (Join-Path $SolutionDir "Releases")
)

Set-PSDebug -Strict

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $toolsDir "utilities.psm1")
Import-Module (Join-Path $toolsDir "commands.psm1")

New-ReleaseForPackage -SolutionDir $SolutionDir `
                         -BuildDir $BuildDir `
                         -ReleasesDir $ReleasesDir
