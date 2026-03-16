# Compare-effective-GPO

A PowerShell utility that compares the **effectively applied Group Policy Objects (GPOs)** between two Active Directory Organizational Units (OUs). It shows which GPOs are active in each OU, highlights differences with color-coded console output, and optionally exports the results to CSV.

## Use Cases

- Troubleshoot GPO application differences between OUs
- Verify consistent policy coverage during OU migrations
- Audit and document GPO inheritance across organizational units

## Prerequisites

| Requirement | Details |
|---|---|
| Operating System | Windows (Server or Client with RSAT) |
| PowerShell | 3.0 or later |
| Active Directory module | GroupPolicy module (part of GPMC / RSAT) |
| Permissions | Read access to Group Policy and AD |

### Install RSAT (if needed)

**Windows Server:**
```powershell
Install-WindowsFeature -Name GPMC
```

**Windows 10/11:**
```powershell
Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0
```

## Usage

```powershell
.\Compare-GPOs.ps1 -OU1 "<OU-DN>" -OU2 "<OU-DN>" [-ExportCsv "<path>"]
```

### Parameters

| Parameter | Required | Description |
|---|---|---|
| `-OU1` | ✅ Yes | Distinguished Name (DN) of the first OU |
| `-OU2` | ✅ Yes | Distinguished Name (DN) of the second OU |
| `-ExportCsv` | ❌ No | File path for optional CSV export |

### Examples

**Compare two OUs:**
```powershell
.\Compare-GPOs.ps1 `
  -OU1 "OU=Source,OU=Clients,DC=contoso,DC=local" `
  -OU2 "OU=Target,OU=Clients,DC=contoso,DC=local"
```

**Compare and export results to CSV:**
```powershell
.\Compare-GPOs.ps1 `
  -OU1 "OU=Source,OU=Clients,DC=contoso,DC=local" `
  -OU2 "OU=Target,OU=Clients,DC=contoso,DC=local" `
  -ExportCsv "C:\Reports\gpo-comparison.csv"
```

## Output

### Console

The script prints a color-coded table to the console:

| Color | Meaning |
|---|---|
| 🟢 Green | GPO is effective in **both** OUs |
| 🟡 Yellow | GPO is effective in **only one** OU |

**Example output:**
```
=== Vergleich effektiv wirksamer GPOs für
    OU1 = OU=Source,OU=Clients,DC=contoso,DC=local
    OU2 = OU=Target,OU=Clients,DC=contoso,DC=local

GPO-Name                                 Status     Quelle OU1 (Target)                      Quelle OU2 (Target)
---------------------------------------- ---------- ---------------------------------------- ----------------------------------------
Default Domain Policy                    Beide      DC=contoso,DC=local                      DC=contoso,DC=local
Security Baseline                        Beide      OU=Baseline,DC=contoso,DC=local          OU=Baseline,DC=contoso,DC=local
Old Client Policy                        Nur OU1    OU=Source,OU=Clients,DC=contoso,DC=local
New Client Policy                        Nur OU2                                             OU=Target,OU=Clients,DC=contoso,DC=local
```

### CSV (optional)

When `-ExportCsv` is used, the following columns are exported:

| Column | Description |
|---|---|
| `GpoName` | Display name of the GPO |
| `GpoId` | GUID of the GPO |
| `Status` | `Beide` (both), `Nur OU1` (only OU1), or `Nur OU2` (only OU2) |
| `OU1_Aktiv` | `True`/`False` — GPO active in OU1 |
| `OU1_Source` | DN of the container where the GPO is linked for OU1 |
| `OU2_Aktiv` | `True`/`False` — GPO active in OU2 |
| `OU2_Source` | DN of the container where the GPO is linked for OU2 |

## How It Works

The script uses `Get-GPInheritance` to retrieve the `InheritedGpoLinks` for each OU. `InheritedGpoLinks` represent the complete, ordered set of GPOs that are actually applied to objects inside that OU — taking into account linked GPOs from the domain, parent OUs, and sites. The two sets are then compared and differences are surfaced in the output.

## Notes

- Script comments and console messages are in German.
- Only GPOs that appear in at least one OU's effective set are included in the output.
- The `Status` values in the output are in German: `Beide` = both, `Nur OU1` = only OU1, `Nur OU2` = only OU2.

## License

No license file is currently provided. Contact the repository owner for usage terms.
