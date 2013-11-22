$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $toolsDir "utilities.psm1")

$createReleasePackageExe = Join-Path $toolsDir "CreateReleasePackage.exe"

$wixDir = Join-Path $toolsDir "wix"
$candleExe = Join-Path $wixDir "candle.exe"
$lightExe = Join-Path $wixDir "light.exe"

function New-TemplateFromPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$packageFile,
        [Parameter(Mandatory = $true)]
        [string]$templateFile
    )

    $resultFile = & $createReleasePackageExe --preprocess-template $templateFile $pkg.FullName
    $resultFile
}

function New-ReleaseForPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionDir,
        [Parameter(Mandatory = $true)]
        [string]$BuildDir,
        [Parameter(Mandatory = $false)]
        [string]$ReleasesDir = (Join-Path $SolutionDir "Releases")
    )

    if (!(Test-Path $ReleasesDir)) { `
        New-Item -ItemType Directory -Path $ReleasesDir | Out-Null
    }

    Write-Message "Checking $BuildDir for packages`n"

    $nugetPackages = ls "$BuildDir\*.nupkg" `
        | ?{ $_.Name.EndsWith(".symbols.nupkg") -eq $false } `
        | sort @{expression={$_.LastWriteTime};Descending=$false}

    if ($nugetPackages -eq $null) {
        Write-Error "No .nupkg files were found in the build directory"
        Write-Error "Have you built the solution lately?"

        return
    } else {
        foreach($pkg in $nugetPackages) {
            $pkgFullName = $pkg.FullName
            Write-Message "Found package $pkgFullName"
        }
    }

    Write-Host ""
    Write-Message "Publishing artifacts to $ReleasesDir"

    $releasePackages = @()

    $packageDir = Get-NuGetPackagesPath($SolutionDir)
    if(-not $packageDir) {
        $packageDir = Join-Path $SolutionDir "packages"
    }

    Write-Host ""
    Write-Message "Using packages directory $packageDir"

    foreach($pkg in $nugetPackages) {
        $pkgFullName = $pkg.FullName
        $releaseOutput = & $createReleasePackageExe -o $ReleasesDir -p $packageDir $pkgFullName

        if ($LastExitCode -ne 0) {
            Write-Error "CreateReleasePackage returned an error code. Aborting..."
            return
        }

        $packages = $releaseOutput.Split(";")
        $fullRelease = $packages[0].Trim()

        Write-Host ""
        Write-Message "Full release: $fullRelease"

        if ($packages.Length -gt 1) {
            $deltaRelease = $packages[-1].Trim()
            if ([string]::IsNullOrWhitespace($deltaRelease) -eq $false) {
                Write-Message "Delta release: $deltaRelease"
            }
        }

        $newItem = New-Object PSObject -Property @{
                PackageSource = $pkgFullName
                FullRelease = $fullRelease
                DeltaRelease = $deltaRelease
        }

        $releasePackages += $newItem
    }

    # use the last package and create an installer
    $latest =  $releasePackages[-1]

    $latestPackageSource = $latest.PackageSource
    $latestFullRelease = $latest.FullRelease

    Write-Host ""
    Write-Message "Creating installer for $latestFullRelease"

    $candleTemplate = New-TemplateFromPackage $latestPackageSource "$toolsDir\template.wxs"
    $wixTemplate = Join-Path $BuildDir "template.wxs"

    Remove-ItemSafe $wixTemplate
    mv $candleTemplate $wixTemplate | Out-Null

    # we are all made of stars and string replacement code
    $releasesFile = Join-Path $ReleasesDir "RELEASES"
    $templateText = Get-Content $wixTemplate
    $templateText = $templateText `
                        -Replace "\$\(var.ToolsDir\)", $toolsDir `
                        -Replace "\$\(var.ReleasesFile\)", $releasesFile `
                        -Replace "\$\(var.NuGetFullPackage\)", $latestFullRelease
    
    Set-Content $wixTemplate $templateText
    
    Remove-ItemSafe "$BuildDir\template.wixobj"

    Write-Message "Running candle.exe"
    & $candleExe -out "$BuildDir\template.wixobj" -arch x86 -ext "$wixDir\WixBalExtension.dll" -ext "$wixDir\WixUtilExtension.dll" -ext "$wixDir\WixNetFxExtension.dll" "$wixTemplate"

    Write-Message "Running light.exe"
    & $lightExe -out "$ReleasesDir\Setup.exe" -ext "$wixDir\WixBalExtension.dll" -ext "$wixDir\WixUtilExtension.dll" -ext "$wixDir\WixNetFxExtension.dll" "$BuildDir\template.wixobj"
}
