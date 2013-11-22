param($installPath, $toolsPath, $package, $project)
Import-Module (Join-Path $toolsPath utilities.psm1)
Import-Module (Join-Path $toolsPath commands.psm1)
Import-Module (Join-Path $toolsPath visualstudio.psm1)