#Requires -Version 5.1
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
    Read-only inventory of the Microsoft Copilot admin catalog packages (plugin registry).

.DESCRIPTION
    Lists the packages of the Copilot admin catalog through Microsoft Graph:
    GET https://graph.microsoft.com/v1.0/copilot/admin/catalog/packages

    A package is the unit published in the Microsoft plugin registry. It can bundle
    skills, connectors and agents. This script never changes a tenant setting: it only
    sends one GET request. Enabling, blocking or assigning plugins is done in the
    Agent 365 experience of the Microsoft 365 admin center (Agents > Tools).

    The API is labelled preview and requires a Microsoft Agent 365 license. Because the
    schema can change, every package is returned with its properties as sent by the API,
    without renaming or filtering. Inspect the full output before filtering on a field.

    Requirements:
    - Module Microsoft.Graph.Authentication (Connect-MgGraph, Invoke-MgGraphRequest)
    - Microsoft Graph permission CopilotPackages.Read.All
    - Role AI Administrator (or Global Administrator)
    - Microsoft Agent 365 license

    The only local state change is the optional HTML report, which supports -WhatIf
    and -Confirm.

.PARAMETER SkipConnect
    Reuses the current Microsoft Graph session instead of calling Connect-MgGraph.
    The session must already hold the CopilotPackages.Read.All scope.

.PARAMETER AsJson
    Returns a JSON string (array of packages) instead of PowerShell objects.

.PARAMETER JsonDepth
    Serialization depth used by -AsJson and for nested values in the HTML report.
    Default: 5. Accepted range: 1 to 100.

.PARAMETER HtmlReportPath
    Path of a simple HTML report to create, with one row per package and one column
    per property found. Supports -WhatIf and -Confirm.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    System.Management.Automation.PSCustomObject, one per catalog package.
    System.String when -AsJson is used.

.EXAMPLE
    .\Get-CopilotPluginCatalog.ps1

    Connects to Microsoft Graph and returns one object per catalog package.

.EXAMPLE
    .\Get-CopilotPluginCatalog.ps1 -HtmlReportPath .\catalog.html

    Returns the packages and writes a simple HTML report.

.EXAMPLE
    .\Get-CopilotPluginCatalog.ps1 -HtmlReportPath .\catalog.html -WhatIf

    Reads the catalog but only shows what would be written, without creating the file.

.EXAMPLE
    .\Get-CopilotPluginCatalog.ps1 -AsJson -JsonDepth 8 | Out-File -FilePath .\catalog.json -Encoding utf8

    Saves the raw structure of the packages as JSON.

.EXAMPLE
    Connect-MgGraph -Scopes 'CopilotPackages.Read.All'
    .\Get-CopilotPluginCatalog.ps1 -SkipConnect -Verbose

    Reuses an existing Microsoft Graph session.

.NOTES
    Version: 1.0.0
    Author: Charles Jenkins
    License: MIT
    The API is in preview: property names can change. The script sends a single
    request and does not follow pagination links.

.LINK
    https://trivium365.com/blog/registre-plugins-microsoft-copilot-gouvernance/

.LINK
    https://techcommunity.microsoft.com/blog/microsoft-copilot-blog/introducing-the-plugin-registry---one-place-to-discover-and-govern-plugins-for-m/4559682
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[OutputType([pscustomobject], [string])]
param(
    [Parameter()]
    [switch]$SkipConnect,

    [Parameter()]
    [switch]$AsJson,

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$JsonDepth = 5,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$HtmlReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-CatalogPackageObject {
    <#
    .SYNOPSIS
        Converts a package returned by Invoke-MgGraphRequest into a PowerShell object.
    .PARAMETER InputObject
        Package as returned by the API (usually a dictionary).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        $properties = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
            $properties[[string]$key] = $InputObject[$key]
        }
        [pscustomobject]$properties
    }
    else {
        $InputObject
    }
}

function ConvertTo-HtmlCellValue {
    <#
    .SYNOPSIS
        Converts a property value into HTML encoded text for a table cell.
    .PARAMETER Value
        Value to convert. Nested values are serialized as compact JSON.
    .PARAMETER Depth
        JSON serialization depth for nested values.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [int]$Depth
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [string] -or $Value -is [System.ValueType]) {
        $text = [string]$Value
    }
    else {
        $text = ConvertTo-Json -InputObject $Value -Depth $Depth -Compress
    }

    [System.Net.WebUtility]::HtmlEncode($text)
}

function ConvertTo-CatalogHtmlReport {
    <#
    .SYNOPSIS
        Builds a simple HTML report from the catalog packages.
    .PARAMETER Package
        Catalog packages as PowerShell objects.
    .PARAMETER Depth
        JSON serialization depth for nested values.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Package,

        [Parameter(Mandatory = $true)]
        [int]$Depth
    )

    $columns = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $Package) {
        foreach ($property in $item.PSObject.Properties) {
            if (-not $columns.Contains($property.Name)) {
                $columns.Add($property.Name)
            }
        }
    }

    $generatedOn = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $builder = [System.Text.StringBuilder]::new()
    $null = $builder.AppendLine('<!DOCTYPE html>')
    $null = $builder.AppendLine('<html lang="en">')
    $null = $builder.AppendLine('<head>')
    $null = $builder.AppendLine('<meta charset="utf-8">')
    $null = $builder.AppendLine('<title>Copilot plugin catalog inventory</title>')
    $null = $builder.AppendLine('<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:6px;text-align:left;vertical-align:top;font-size:13px}th{background:#f0f0f0}td{word-break:break-word}</style>')
    $null = $builder.AppendLine('</head>')
    $null = $builder.AppendLine('<body>')
    $null = $builder.AppendLine('<h1>Copilot plugin catalog inventory</h1>')
    $null = $builder.AppendLine(('<p>Generated on {0}. Source: GET /v1.0/copilot/admin/catalog/packages (preview). Read-only inventory; property names can change while the API is in preview.</p>' -f $generatedOn))
    $null = $builder.AppendLine(('<p>Packages returned: {0}</p>' -f $Package.Count))

    if ($Package.Count -eq 0 -or $columns.Count -eq 0) {
        $null = $builder.AppendLine('<p>No package was returned.</p>')
    }
    else {
        $null = $builder.AppendLine('<table>')
        $null = $builder.Append('<tr>')
        foreach ($column in $columns) {
            $null = $builder.Append(('<th>{0}</th>' -f [System.Net.WebUtility]::HtmlEncode($column)))
        }
        $null = $builder.AppendLine('</tr>')

        foreach ($item in $Package) {
            $null = $builder.Append('<tr>')
            foreach ($column in $columns) {
                $property = $item.PSObject.Properties[$column]
                $cellValue = ''
                if ($null -ne $property) {
                    $cellValue = ConvertTo-HtmlCellValue -Value $property.Value -Depth $Depth
                }
                $null = $builder.Append(('<td>{0}</td>' -f $cellValue))
            }
            $null = $builder.AppendLine('</tr>')
        }
        $null = $builder.AppendLine('</table>')
    }

    $null = $builder.AppendLine('</body>')
    $null = $builder.AppendLine('</html>')
    $builder.ToString()
}

if (-not $SkipConnect) {
    Write-Verbose -Message 'Connecting to Microsoft Graph with scope CopilotPackages.Read.All.'
    $null = Connect-MgGraph -Scopes 'CopilotPackages.Read.All'
}

$uri = 'https://graph.microsoft.com/v1.0/copilot/admin/catalog/packages'
Write-Verbose -Message ('GET {0}' -f $uri)

try {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri
}
catch {
    throw ('Unable to read the Copilot admin catalog. Check that the account holds the AI Administrator role (or Global Administrator), that consent was granted for CopilotPackages.Read.All and that the tenant has a Microsoft Agent 365 license. The API is in preview. Details: {0}' -f $_.Exception.Message)
}

$rawPackages = @()
if ($response -is [System.Collections.IDictionary]) {
    if ($response.Contains('value')) {
        $rawPackages = @($response['value'])
    }
    else {
        Write-Warning -Message 'The response does not contain a value collection. The preview schema may have changed.'
    }
}
elseif ($null -ne $response -and $null -ne $response.PSObject.Properties['value']) {
    $rawPackages = @($response.value)
}
else {
    Write-Warning -Message 'Unexpected response format. The preview schema may have changed.'
}

$packages = @(
    $rawPackages |
        Where-Object -FilterScript { $null -ne $_ } |
        ForEach-Object -Process { ConvertTo-CatalogPackageObject -InputObject $_ }
)
Write-Verbose -Message ('{0} package(s) returned.' -f $packages.Count)

if ($PSBoundParameters.ContainsKey('HtmlReportPath')) {
    if ($PSCmdlet.ShouldProcess($HtmlReportPath, 'Write HTML report of the Copilot plugin catalog')) {
        $html = ConvertTo-CatalogHtmlReport -Package $packages -Depth $JsonDepth
        Set-Content -LiteralPath $HtmlReportPath -Value $html -Encoding UTF8
        Write-Verbose -Message ('HTML report written to {0}' -f $HtmlReportPath)
    }
}

if ($AsJson) {
    ConvertTo-Json -InputObject $packages -Depth $JsonDepth
}
else {
    $packages
}
