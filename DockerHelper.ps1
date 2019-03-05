<#
.SYNOPSIS
Read row position from docker ps output 

.DESCRIPTION
Read row position from docker ps output 
#>
function Get-RowColumnPosition
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [String]$Row
    )
    
    $Positions = New-Object System.Collections.Generic.List[System.Object]

    $recordPosition = $true

    For ($i = ($Row.Length - 1); $i -gt 0; $i--)
    {
        if (($Row.Chars($i) -eq ' ') -and ($Row.Chars($i - 1) -eq ' '))
        {            
            if ($recordPosition)
            {
                $Positions += ($i + 1)

                $recordPosition = $false
            }
        }

        if (($Row.Chars($i) -eq ' ') -and ($Row.Chars($i - 1) -ne ' '))
        {
            $recordPosition = $true
        }
    }

    return $Positions = ($Positions += 0) | Sort-Object
}

<#
.SYNOPSIS
Create new docker PSObject

.DESCRIPTION
Take Docker ps output header row and data row as parameters and create new PSObject
#>
function New-DockerObject
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True, ValueFromPipeline =$True)]
        [String]$HeaderRow,

        [Parameter(Mandatory=$False)]
        [String]$DataRow
    )

    $Object = New-Object `
        -TypeName PSObject

    $ColumnPosition = Get-RowColumnPosition `
        -Row $HeaderRow
    
    for ($i = 0; $i -lt $ColumnPosition.Length; $i ++)
    {
        if ($i -eq ($ColumnPosition.Length - 1))
        {
            $Name = $HeaderRow.Substring($ColumnPosition[$i])
            
            $Value = $DataRow.Substring($ColumnPosition[$i])
        }
        else
        {
            $Name = $HeaderRow.Substring($ColumnPosition[$i], ($ColumnPosition[$i + 1] - $ColumnPosition[$i]))
            
            $Value = $DataRow.Substring($ColumnPosition[$i], ($ColumnPosition[$i + 1] - $ColumnPosition[$i]))
        }

        Add-Member `
            -InputObject $Object `
            -MemberType NoteProperty `
            -Name $Name.Replace(" ", "") `
            -Value $Value.Trim()
    }

    return $Object
}

<#
.SYNOPSIS
Convert docker ps cmd output to PSObject

.DESCRIPTION
Convert docker ps cmd output to PSObject
#>
function ConvertTo-DockerObject
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True, ValueFromPipeline =$True)]
        [String[]]$DockerOutput
    )

    $DataRows = $DockerOutput[1..$DockerOutput.Length]

    ForEach ($DataRow in $DataRows)
    {
        New-DockerObject `
            -HeaderRow $DockerOutput[0] `
            -DataRow $DataRow 
    }
}

<#
.SYNOPSIS
List all containers

.DESCRIPTION
List all containers
#>
function Get-DockerContainers
{
    $Output = docker ps -a --all --no-trunc

    return ConvertTo-DockerObject `
        -DockerOutput $Output
}

<#
.SYNOPSIS
Remove all stopped containers

.DESCRIPTION
Remove all stooped containers
#>
function Remove-DockerContainers
{
    $Containers = Get-DockerContainers 

    foreach ($Container in $Containers)
    {
        Docker rm $Container.ContainerId
    }
}

<#
.SYNOPSIS
List all container images

.DESCRIPTION
List all container images
#>
function Get-DockerImages
{
    $Output = docker image ls --all --no-trunc

    return ConvertTo-DockerObject `
        -DockerOutput $Output
}

<#
.SYNOPSIS
Remove all intermediate iamges

.DESCRIPTION
Remove all intermediate iamges
#>
function Remove-DockerIntermediateImages
{
    $IntermediateImages = Get-DockerImages | Where-Object { $_.Repository -eq "<none>" }

    if ($IntermediateImages)
    {
        foreach ($Image in $IntermediateImages)
        {
            Docker image rm $Image.ImageId
        }
    }
}

<#
.SYNOPSIS
Create new docker image info object

.DESCRIPTION
Create new docker image info object
#>
function New-DockerImageInfo
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [String]$VersionFilePath
    )

    $VersionContent = Get-Content `
        -Path $VersionFilePath | ConvertFrom-Json
    
    $Branch = (git rev-parse `
        --abbrev-ref HEAD).Replace("/","-")

    $ShortHash = git rev-parse `
        --short HEAD

    $Tag = if ($Branch -ne "Master") {
        "{0}-{1}" -f $($VersionContent.ImageVersion), $Branch        
    }
    else
    {
        $VersionContent.ImageVersion
    }

    return `
        [PSCustomObject]@{
            Tag = $Tag
            Branch = $Branch
            ShortHash = $ShortHash
            Version = $VersionContent.ImageVersion
            Packages = $VersionContent.Packages
        }
}