<#
.SYNOPSIS
Vergleicht die effektiv wirksamen GPOs (InheritedGpoLinks) auf Objekte zweier OUs.

.Ergebnis:
- Welche GPO wirkt in OU1, in OU2 oder in beiden?
- Link Ursprung (Target = Domain / OU / Site).
- Unterschiede farbig markiert.

.EXAMPLE
.\Compare-GPOs.ps1 `
  -OU1 "OU=Quelle,OU=Clients,DC=contoso,DC=local" `
  -OU2 "OU=Ziel,OU=Clients,DC=contoso,DC=local"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OU1,

    [Parameter(Mandatory = $true)]
    [string]$OU2,

    [string]$ExportCsv
)

# --- Vorbereitung ---------------------------------------------------------
try {
    Import-Module GroupPolicy -ErrorAction Stop
}
catch {
    Write-Error "Konnte das GroupPolicy-Modul nicht laden. GPMC/RSAT muss installiert sein. Fehler: $_"
    return
}

function Get-OUEffectiveGpoMap {
    <#
        Nimmt eine OU-DN und liefert ein Hashtable:
        Key   = GPO-ID (Guid als String)
        Value = Objekt mit Name + Target (wo die GPO verlinkt ist)

        Basis: NUR InheritedGpoLinks → das sind laut MS genau die
        GPOs, die bei der GP-Verarbeitung auf Clients in dieser OU
        tatsächlich angewendet werden.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OuDn
    )

    $inh = Get-GPInheritance -Target $OuDn -ErrorAction Stop

    $map = @{}

    if ($inh.InheritedGpoLinks) {
        foreach ($link in $inh.InheritedGpoLinks) {
            # GpoId ist ein Guid-Objekt → als String verwenden
            $id   = "$($link.GpoId)"
            $name = $link.DisplayName
            # Target = DN des Containers, wo die GPO VERLINKT ist
            $src  = $link.Target  

            if (-not $map.ContainsKey($id)) {
                $map[$id] = [PSCustomObject]@{
                    GpoId      = $id
                    GpoName    = $name
                    LinkTarget = $src  # z.B. "DC=contoso,DC=local" oder "OU=Baseline,..."
                }
            }
        }
    }

    return $map
}

# --- Daten holen ----------------------------------------------------------
Write-Host "Hole effektiv wirksame GPOs für OU1: $OU1" -ForegroundColor Cyan
$map1 = Get-OUEffectiveGpoMap -OuDn $OU1

Write-Host "Hole effektiv wirksame GPOs für OU2: $OU2" -ForegroundColor Cyan
$map2 = Get-OUEffectiveGpoMap -OuDn $OU2

# Alle GPO-IDs, die irgendwo wirken
$allIds = @($map1.Keys + $map2.Keys) | Sort-Object -Unique

# Vergleichstabelle bauen
$result = foreach ($id in $allIds) {
    $g1 = if ($map1.ContainsKey($id)) { $map1[$id] } else { $null }
    $g2 = if ($map2.ContainsKey($id)) { $map2[$id] } else { $null }

    $name = if ($g1) { $g1.GpoName } else { $g2.GpoName }

    $inOU1 = [bool]$g1
    $inOU2 = [bool]$g2

    $status = if ($inOU1 -and $inOU2) {
        'Beide'
    }
    elseif ($inOU1 -and -not $inOU2) {
        'Nur OU1'
    }
    elseif (-not $inOU1 -and $inOU2) {
        'Nur OU2'
    }
    else {
        'Keine'   # praktisch nicht relevant
    }

    [PSCustomObject]@{
        GpoName    = $name
        GpoId      = $id
        Status     = $status
        OU1_Aktiv  = $inOU1
        OU2_Aktiv  = $inOU2
        OU1_Source = if ($g1) { $g1.LinkTarget } else { $null }
        OU2_Source = if ($g2) { $g2.LinkTarget } else { $null }
    }
}

# Nur GPOs, die irgendwo aktiv wirken
$resultSorted = $result |
    Where-Object { $_.OU1_Aktiv -or $_.OU2_Aktiv } |
    Sort-Object Status, GpoName

# --- Konsolen-Output mit Farben ------------------------------------------
Write-Host ""
Write-Host "=== Vergleich effektiv wirksamer GPOs für" -ForegroundColor Green
Write-Host "    OU1 = $OU1"
Write-Host "    OU2 = $OU2`n" -ForegroundColor Green

Write-Host ("{0,-40} {1,-10} {2,-40} {3,-40}" -f "GPO-Name", "Status", "Quelle OU1 (Target)", "Quelle OU2 (Target)")
Write-Host ("{0,-40} {1,-10} {2,-40} {3,-40}" -f ("-"*40), ("-"*10), ("-"*40), ("-"*40))

foreach ($row in $resultSorted) {
    switch ($row.Status) {
        'Beide'   { $color = 'Green' }   # gleiche GPO zieht in beiden OUs
        'Nur OU1' { $color = 'Yellow' }  # zieht nur in Quelle
        'Nur OU2' { $color = 'Yellow' }  # zieht nur in Ziel
        default   { $color = 'DarkGray' }
    }

    $ou1Src = if ([string]::IsNullOrEmpty($row.OU1_Source)) { "" } else { $row.OU1_Source }
    $ou2Src = if ([string]::IsNullOrEmpty($row.OU2_Source)) { "" } else { $row.OU2_Source }

    $line = "{0,-40} {1,-10} {2,-40} {3,-40}" -f `
        $row.GpoName,
        $row.Status,
        $ou1Src,
        $ou2Src

    Write-Host $line -ForegroundColor $color
}

# --- Optional: CSV für Doku ---------------------------------------
if ($ExportCsv) {
    Write-Host ""
    Write-Host "Exportiere Ergebnis nach: $ExportCsv" -ForegroundColor Yellow
    $resultSorted |
        Select-Object GpoName, GpoId, Status,
            OU1_Aktiv, OU1_Source,
            OU2_Aktiv, OU2_Source |
        Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
}

