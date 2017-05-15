$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# from NuGetPowerTools - https://github.com/davidfowl/NuGetPowerTools/blob/master/MSBuild.psm1

function Write-Message {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [string[]]$Message
    )

    Write-Host "Squirrel: " -f blue -nonewline;
    Write-Host $Message
}

function Write-Error {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [string[]]$Message
    )

    Write-Host "Squirrel: " -f red -nonewline;
    Write-Host $Message
}

function Remove-ItemSafe {
    param(
        [parameter(Mandatory=$true)]
        $Path
    )

    if (Test-Path $Path) {
        rm $Path | Out-Null
    }
}

function Resolve-ProjectName {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )

    if($ProjectName) {
        $projects = Get-Project $ProjectName
    }
    else {
        # All projects by default
        $projects = Get-Project
    }

    $projects
}

function Get-MSBuildProject {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    Process {
        (Resolve-ProjectName $ProjectName) | % {
            $path = $_.FullName
            @([Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($path))[0]
        }
    }
}

function Set-MSBuildProperty {
    param(
        [parameter(Position = 0, Mandatory = $true)]
        $PropertyName,
        [parameter(Position = 1, Mandatory = $true)]
        $PropertyValue,
        [parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    Process {
        (Resolve-ProjectName $ProjectName) | %{
            $buildProject = $_ | Get-MSBuildProject
            $buildProject.SetProperty($PropertyName, $PropertyValue) | Out-Null
            $_.Save()
        }
    }
}

function Get-MSBuildProperty {
    param(
        [parameter(Position = 0, Mandatory = $true)]
        $PropertyName,
        [parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string]$ProjectName
    )

    $buildProject = Get-MSBuildProject $ProjectName
    $buildProject.GetProperty($PropertyName)
}

# helper functions to take care of the nastiness of manipulating everything

function Get-ProjectItem {
    param(
        [parameter(Position=0,ValueFromPipeLine=$true,Mandatory=$true)]
        $FileName,
        [parameter(Position=1,ValueFromPipeLine=$true,Mandatory=$true)]
        $ProjectName
    )

    (Resolve-ProjectName $ProjectName) | %{
        $_.ProjectItems | Where-Object { $_.Name -eq $FileName } `
                        | Select-Object -first 1

    }
}

function Add-FileWithNoOutput {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,ValueFromPipeLine=$true,Mandatory=$true)]
        [string] $FilePath,

        [Parameter(Position=1,ValueFromPipeLine=$true,Mandatory=$true)]
        $Project
    )

    # NOTE: this won't work for nested files
    $fileName = (gci $FilePath).Name

    # TODO: stop passing the Project object around
    $projectName = $Project.Name

    # do we have the existing file in the project?
    $existingFile = Get-ProjectItem $fileName $projectName

    if ($existingFile -eq $null) {
        Write-Message "Could not find file '$FilePath' in project '$projectName'"
        Write-Message "Adding nuspec file to the project"

        (Resolve-ProjectName $projectName) | %{
            # use the native MSBuild object
            $buildProject = $_ | Get-MSBuildProject

            # create the new elements with *just* the nuspec file
            $itemGroup = $buildProject.Xml.AddItemGroup()
            $none = $buildProject.Xml.CreateItemElement("None")

            $none.Include = $fileName
            $itemGroup.AppendChild($none) | Out-Null

            # save the outer project object instead
            $_.Save()
        }
    } else {
        Write-Message "Ensuring nuspec file is excluded from build output"

        $copyToOutput = $existingFile.Properties.Item("CopyToOutputDirectory")
        $copyToOutput.Value = 0
        $Project.Save()
    }
}

function Set-BuildPackage {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromPipeLine=$true, Mandatory=$true)]
        [string] $ProjectName = '',

        [Parameter(Position=0, ValueFromPipeLine=$true, Mandatory=$true)]
        [bool] $Value = $false
    )

    $buildPackage = Get-MSBuildProperty "BuildPackage" $ProjectName

    if ([System.Convert]::ToBoolean($buildPackage.EvaluatedValue) -eq $Value) {
        Write-Message "No need to modify the csproj file as BuildPackage is set to $Value"
    } else {
        Write-Message "Changing BuildPackage from '$buildPackageValue' to '$Value' in project file"
        Set-MSBuildProperty "BuildPackage" $Value $ProjectName
    }
}

function Add-InstallerTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromPipeLine=$true, Mandatory=$true)]
        [string] $Destination,

        [Parameter(Position=0, ValueFromPipeLine=$true, Mandatory=$true)]
        [string] $ProjectName = ''
    )

    if (Test-Path $Destination) {
         Write-Message "The file '$Destination' already exists, will not overwrite this file..."
    } else {
        $content = Get-Content (Join-Path $toolsDir template.nuspec.temp) | `
                   Foreach-Object { $_ -replace '{{project}}', $ProjectName }

        Set-Content -Path $Destination -Value $content	| Out-Null
    }
}

function Get-NuGetPackagesPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$directory
    )

    $cfg = Get-ChildItem -Path $directory -Filter nuget.config | Select-Object -first 1
    if($cfg) {
        [xml]$config = Get-Content $cfg.FullName
        $path = $config.configuration.config.add | ?{ $_.key -eq "repositorypath" } | select value
        # Found nuget.config but it don't has repositorypath attribute
        if($path) {
            return $path.value.Replace("$", $directory)
        }
    }

    $parent = Split-Path $directory

    if(-not $parent) {
        return $null
    }

    return Get-NuGetPackagesPath($parent)
}

