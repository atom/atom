$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $toolsDir "utilities.psm1")
Import-Module (Join-Path $toolsDir "commands.psm1")

function New-Release {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromPipeLine=$true)]
        [string] $ProjectName
    )

    if (-not $ProjectName) {
        $ProjectName = (Get-Project).Name
    }

    $project = Get-Project $ProjectName
    $projectDir = (gci $project.FullName).Directory

    $activeConfiguration = $project.ConfigurationManager.ActiveConfiguration

    $outputDir =  $activeConfiguration.Properties.Item("OutputPath").Value

    $buildDir = Join-Path $projectDir $outputDir

    # because the EnvDTE build operations doesn't block on Win7
    # we're not going to clean up packages here because
    # we expect you to be a responsible adult
    # with your artifacts

    if ($psversiontable.psversion.major -gt 3) {

        if (Test-Path $buildDir) {
            Write-Message "Clearing existing nupkg files from folder $outputDir"
            Remove-Item "$buildDir\*.nupkg"
        } else {
            Write-Message "Build output folder $buildDir does not exist, skipping"
        }

        Write-Message "Building project $ProjectName"

        $dte.Solution.SolutionBuild.Clean($true)

        $dte.Solution.SolutionBuild.BuildProject( `
            $activeConfiguration.ConfigurationName, `
            $project.FullName, `
            $true)
    }

    Write-Message "Publishing release for project $ProjectName"

    $solutionDir = (gci $dte.Solution.FullName).Directory

    New-ReleaseForPackage -SolutionDir $solutionDir `
                             -BuildDir $buildDir
}

function Enable-BuildPackage {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromPipeLine=$true)]
        [string] $ProjectName
    )

        Set-BuildPackage -Value $true -ProjectName $ProjectName
}

'New-Release', 'Enable-BuildPackage' | %{
    Register-TabExpansion $_ @{
        ProjectName = { Get-Project -All | Select -ExpandProperty Name }
    }
}

Export-ModuleMember New-Release, Enable-BuildPackage