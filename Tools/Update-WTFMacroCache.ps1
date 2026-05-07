param(
    [string]$RetailPath = (Resolve-Path "$PSScriptRoot\..\..\..\..\").Path,
    [string]$OutputPath = (Resolve-Path "$PSScriptRoot\..\Modules\Spell").Path + "\OmegaSpell_WTFMacroCache.generated.lua"
)

$ErrorActionPreference = "Stop"

function Escape-LuaString {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return "" }
    return ($Value -replace "\\", "\\\\" -replace '"', '\"' -replace "`r", "" -replace "`n", "\n")
}

function Read-MacroCache {
    param([string]$Path)

    $lines = Get-Content -LiteralPath $Path -ErrorAction Stop
    $macros = New-Object System.Collections.Generic.List[object]
    $current = $null
    $body = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match '^VER\s+\d+\s+([0-9A-Fa-f]+)\s+"((?:\\"|[^"])*)"\s+"((?:\\"|[^"])*)"\s*$') {
            if ($current) {
                $current.body = ($body -join "`n")
                $macros.Add($current)
            }
            $current = [ordered]@{
                id = $matches[1]
                name = ($matches[2] -replace '\\"', '"')
                icon = ($matches[3] -replace '\\"', '"')
                body = ""
            }
            $body = New-Object System.Collections.Generic.List[string]
            continue
        }

        if ($line -eq "END") {
            if ($current) {
                $current.body = ($body -join "`n")
                $macros.Add($current)
                $current = $null
                $body = New-Object System.Collections.Generic.List[string]
            }
            continue
        }

        if ($current) {
            $body.Add($line)
        }
    }

    if ($current) {
        $current.body = ($body -join "`n")
        $macros.Add($current)
    }

    return $macros
}

$wtfAccount = Join-Path $RetailPath "WTF\Account"
if (-not (Test-Path -LiteralPath $wtfAccount)) {
    throw "Dossier WTF introuvable : $wtfAccount"
}

$profiles = New-Object System.Collections.Generic.List[object]
$globalMacros = New-Object System.Collections.Generic.List[object]
$globalSeen = @{}
$characterProfiles = @{}

function Add-UniqueMacro {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [hashtable]$Seen,
        [object]$Macro
    )
    $dedupeKey = "{0}`n{1}`n{2}" -f $Macro.name, $Macro.icon, $Macro.body
    if (-not $Seen.ContainsKey($dedupeKey)) {
        $Seen[$dedupeKey] = $true
        $Target.Add($Macro)
    }
}

Get-ChildItem -LiteralPath $wtfAccount -Directory | Where-Object { $_.Name -ne "SavedVariables" } | ForEach-Object {
    $accountDir = $_
    $account = $accountDir.Name

    $globalFile = Join-Path $accountDir.FullName "macros-cache.txt"
    if (Test-Path -LiteralPath $globalFile) {
        $macros = @(Read-MacroCache $globalFile)
        foreach ($macro in $macros) {
            Add-UniqueMacro -Target $globalMacros -Seen $globalSeen -Macro $macro
        }
    }

    Get-ChildItem -LiteralPath $accountDir.FullName -Directory | ForEach-Object {
        $realmDir = $_
        Get-ChildItem -LiteralPath $realmDir.FullName -Directory | ForEach-Object {
            $charDir = $_
            $macroFile = Join-Path $charDir.FullName "macros-cache.txt"
            if (-not (Test-Path -LiteralPath $macroFile)) { return }
            $macros = @(Read-MacroCache $macroFile)
            if ($macros.Count -eq 0) { return }
            $mergedKey = "$($realmDir.Name)`n$($charDir.Name)"
            if (-not $characterProfiles.ContainsKey($mergedKey)) {
                $characterProfiles[$mergedKey] = [ordered]@{
                    key = "WTF:$($realmDir.Name):$($charDir.Name)"
                    label = "$($charDir.Name) - $($realmDir.Name)"
                    accounts = New-Object System.Collections.Generic.List[string]
                    accountSeen = @{}
                    macroSeen = @{}
                    realm = $realmDir.Name
                    character = $charDir.Name
                    type = "character"
                    macros = New-Object System.Collections.Generic.List[object]
                }
            }
            $profile = $characterProfiles[$mergedKey]
            if (-not $profile.accountSeen.ContainsKey($account)) {
                $profile.accountSeen[$account] = $true
                $profile.accounts.Add($account)
            }
            foreach ($macro in $macros) {
                Add-UniqueMacro -Target $profile.macros -Seen $profile.macroSeen -Macro $macro
            }
        }
    }
}

foreach ($profile in $characterProfiles.Values) {
    $profiles.Add([ordered]@{
        key = $profile.key
        label = $profile.label
        account = ($profile.accounts -join ", ")
        realm = $profile.realm
        character = $profile.character
        type = "character"
        macros = $profile.macros
    })
}

if ($globalMacros.Count -gt 0) {
    $profiles.Add([ordered]@{
        key = "WTF:GLOBAL"
        label = "Global"
        account = ""
        realm = ""
        character = ""
        type = "global"
        macros = $globalMacros
    })
}

$out = New-Object System.Collections.Generic.List[string]
$out.Add("-- OmegaSpell - cache genere depuis WTF.")
$out.Add("-- Genere le $(Get-Date -Format "yyyy-MM-dd HH:mm:ss").")
$out.Add("")
$out.Add("OmegaSpellWTFMacroCache = {")
$out.Add("    generatedAt = ""$(Escape-LuaString (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))"",")
$out.Add("    profiles = {")

foreach ($profile in ($profiles | Sort-Object @{ Expression = { if ($_.type -eq "global") { 0 } else { 1 } } }, label, account)) {
    $out.Add("        {")
    $out.Add("            key = ""$(Escape-LuaString $profile.key)"",")
    $out.Add("            label = ""$(Escape-LuaString $profile.label)"",")
    $out.Add("            account = ""$(Escape-LuaString $profile.account)"",")
    $out.Add("            realm = ""$(Escape-LuaString $profile.realm)"",")
    $out.Add("            character = ""$(Escape-LuaString $profile.character)"",")
    $out.Add("            type = ""$(Escape-LuaString $profile.type)"",")
    $out.Add("            macros = {")
    foreach ($macro in $profile.macros) {
        $out.Add("                {")
        $out.Add("                    id = ""$(Escape-LuaString $macro.id)"",")
        $out.Add("                    name = ""$(Escape-LuaString $macro.name)"",")
        $out.Add("                    displayName = ""$(Escape-LuaString $macro.name)"",")
        $out.Add("                    icon = ""$(Escape-LuaString $macro.icon)"",")
        $out.Add("                    body = ""$(Escape-LuaString $macro.body)"",")
        $out.Add("                },")
    }
    $out.Add("            },")
    $out.Add("        },")
}

$out.Add("    },")
$out.Add("}")

[System.IO.File]::WriteAllLines($OutputPath, $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Cache WTF genere : $OutputPath"
Write-Host ("Profils : {0}" -f $profiles.Count)
