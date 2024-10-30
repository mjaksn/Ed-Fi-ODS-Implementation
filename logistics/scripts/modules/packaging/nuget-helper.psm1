﻿# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

& "$PSScriptRoot/../../../../logistics/scripts/modules/load-path-resolver.ps1"
Import-Module -Force -Scope Global (Get-RepositoryResolvedPath "logistics/scripts/modules/utility/cross-platform.psm1")

function Install-NuGetCli {
    <#
    .SYNOPSIS
        Installs the latest version of the NuGet command line executable

    .DESCRIPTION
        Installs the latest version of the NuGet command line executable

    .PARAMETER toolsPath
        The path to store nuget.exe to

    .PARAMETER sourceNuGetExe
        Web location to the nuget file. Defaulted to the version 5.3.1.0 of nuget.exe.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $ToolsPath,

        [string] $sourceNuGetExe = "https://dist.nuget.org/win-x86-commandline/v5.3.1/nuget.exe"
    )

    if (-not $(Test-Path $ToolsPath)) {
        mkdir $ToolsPath | Out-Null
    }

    $nuget = (Join-Path $ToolsPath "nuget.exe")

    if (-not $(Test-Path $nuget)) {
        Write-Host "Downloading nuget.exe official distribution from " $sourceNuGetExe
        Invoke-WebRequest $sourceNuGetExe -OutFile $nuget
    }
    else {
        $info = Get-Command $nuget

        if ("5.3.1.0" -ne $info.Version.ToString()) {
            Write-Host "Updating nuget.exe official distribution from " $sourceNuGetExe
            Invoke-WebRequest $sourceNuGetExe -OutFile $nuget
        }
    }

    # Add the tools directory to the path if not already there
    if (-not ($ENV:PATH.Contains($ToolsPath))) {
        $ENV:PATH = "$ToolsPath$([IO.Path]::PathSeparator)$ENV:PATH"
    }

    return $nuget
}

<#
.SYNOPSIS
    Downloads and extracts the latest compatible version of a NuGet package.

.OUTPUTS
    Directory name containing the downloaded files.

.EXAMPLE
    Get-NugetPackage -PackageName "EdFi.Suite3.RestApi.Databases" -OutputDirectory ".packages"  -PackageVersion "5.3.0"
#>
function Get-NugetPackage {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        # Exact package name
        [Parameter(Mandatory = $true)]
        [string]
        $PackageName,

        # Extracted package output directory
        [Parameter(Mandatory = $false)]
        $OutputDirectory = './downloads',

        # Exact package version
        [Parameter(Mandatory = $true)]
        [string]
        $PackageVersion,

        # URL for the NuGet package feed
        [string]
        $PackageSource = "https://pkgs.dev.azure.com/ed-fi-alliance/Ed-Fi-Alliance-OSS/_packaging/EdFi/nuget/v3/index.json",

        [switch]
        $ExcludeVersion
    )

    # The first URL just contains metadata for looking up more useful services
    $nugetServices = Invoke-RestMethod $PackageSource

    $packageService = $nugetServices.resources `
    | Where-Object { $_."@type" -like "PackageBaseAddress*" } `
    | Select-Object -Property "@id" -ExpandProperty "@id"

    $file = "$($PackageName).$($PackageVersion)"
    $zip = "$($file).zip"

    New-Item -Path $OutputDirectory -Force -ItemType Directory | Out-Null

    Push-Location $OutputDirectory

    if ($null -ne (Get-ChildItem $file -ErrorAction SilentlyContinue)) {
        # Already exists, don't re-download
        Pop-Location
        return "$($OutputDirectory)/$($file)"
    }

    $lowerId = $PackageName.ToLower()

    try {
        Invoke-RestMethod "$($packageService)$($lowerId)/$($PackageVersion)/$($file).nupkg" -OutFile $zip

        if($ExcludeVersion) {
            $zip = Move-Item -Path $zip -Destination "$($zip.Split($PackageVersion)[0].TrimEnd('.')).zip" -PassThru | Select-Object -ExpandProperty PSChildName
        }

        Expand-Archive $zip -Force

        Remove-Item $zip
    }
    catch {
        throw $_
    }
    finally {
        Pop-Location
    }

    return "$($OutputDirectory)/$($zip.TrimEnd(".zip"))"
}

$exports = @(
    "Install-NuGetCli"
    "Get-NuGetPackage"
)

Export-ModuleMember -Function $exports
