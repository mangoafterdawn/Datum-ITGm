#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the "Datum" Visual Style into a Simply Love-based theme.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:BackedUp = New-Object System.Collections.Generic.HashSet[string]

# Helper to write text without adding a BOM (Byte Order Mark) which can break Lua files
function Write-FileNoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Backup-File {
    param([Parameter(Mandatory)][string]$Path)

    if ($script:BackedUp.Contains($Path)) { return }

    $relative = $Path
    if ($relative.StartsWith($PWD.Path)) {
        $relative = $relative.Substring($PWD.Path.Length).TrimStart('\', '/')
    }
    $dest = Join-Path (Join-Path $PWD '.backup') $relative

    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $Path -Destination $dest -Force
    [void]$script:BackedUp.Add($Path)
}

function Read-YesNo {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [bool]$Default = $true
    )
    $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim() -match '^[Yy]'
}

function Fail {
    param([int]$Code, [string]$Message)
    [Console]::Error.WriteLine($Message)
    exit $Code
}

# insert before matching line
function Insert-LineBefore {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Regex,
        [Parameter(Mandatory)][string]$Line
    )
    $lines = Get-Content -LiteralPath $Path
    $out = New-Object System.Collections.Generic.List[string]
    $matched = $false
    foreach ($l in $lines) {
        if (-not $matched -and $l -match $Regex) {
            $out.Add($Line)
            $matched = $true
        }
        $out.Add($l)
    }
    if (-not $matched) { Fail 3 "[Err3] Failed to match line in: $Path" }
    Write-FileNoBom -Path $Path -Content ($out -join "`r`n")
}

# sed -i 's/old/new/g'
function Replace-InFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Old,
        [Parameter(Mandatory)][string]$New
    )
    $content = Get-Content -LiteralPath $Path -Raw
    $updated = $content.Replace($Old, $New)
    Write-FileNoBom -Path $Path -Content $updated
}

# sed -i -E 's/(regex)(...)/replacement/'
function Regex-Replace-InFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Replacement
    )
    $content = Get-Content -LiteralPath $Path -Raw
    $updated = [regex]::Replace($content, $Pattern, $Replacement)
    Write-FileNoBom -Path $Path -Content $updated
}

# sed -i -E '/<match>/s/<pattern>/<replacement>/
function Regex-Replace-OnMatchingLines {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$LineFilter,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Replacement
    )
    $lines = Get-Content -LiteralPath $Path
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $LineFilter) {
            $lines[$i] = [regex]::Replace($lines[$i], $Pattern, $Replacement)
        }
    }
    Write-FileNoBom -Path $Path -Content ($lines -join "`r`n")
}

# append after matching line
function Append-LineAfter {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Regex,
        [Parameter(Mandatory)][string]$Line
    )
    $lines = Get-Content -LiteralPath $Path
    $out = New-Object System.Collections.Generic.List[string]
    $matched = $false
    foreach ($l in $lines) {
        $out.Add($l)
        if (-not $matched -and $l -match $Regex) {
            $out.Add($Line)
            $matched = $true
        }
    }
    if (-not $matched) { Fail 3 "[Err3] Failed to match line in: $Path" }
    Write-FileNoBom -Path $Path -Content ($out -join "`r`n")
}

function Copy-Directory {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

# Prompt for theme path
Write-Host ""
$rawPath = Read-Host 'Enter the theme path (e.g. C:\Games\ITGmania\Themes\ZMod)'
if ([string]::IsNullOrWhiteSpace($rawPath)) { Fail 1 '[Err1] No path provided.' }
$FILE_PATH = $rawPath.Trim().Trim('"', "'")

# Resolve to an absolute path
try {
    $FILE_PATH = (Resolve-Path -LiteralPath $FILE_PATH -ErrorAction Stop).Path
} catch {
    Fail 1 "[Err1] $FILE_PATH`: No such file or directory."
}

if (-not (Test-Path -LiteralPath $FILE_PATH -PathType Container)) {
    Fail 1 "[Err1] $FILE_PATH`: No such file or directory."
}

# Verify this is a Simply Love-based theme
$themeInfo = Join-Path $FILE_PATH 'ThemeInfo.ini'
if (-not (Test-Path -LiteralPath $themeInfo -PathType Leaf)) {
    Fail 2 '[Err2] Invalid theme type or directory. Must be a SimplyLove-based theme to install the "Datum" visual style.'
}
$themeInfoContent = Get-Content -LiteralPath $themeInfo -Raw
if ($themeInfoContent -notmatch '(?i)simply\s*love') {
    Fail 2 '[Err2] Invalid theme type or directory. Must be a SimplyLove-based theme to install the "Datum" visual style.'
}

Write-Host ""
Write-Host "Installing Datum Visual Style at: $FILE_PATH ..."
Write-Host ""
Write-Host "NOTE: Before installing, make sure to configure the visual style settings in DatumOptions.lua!"
Write-Host "If you would prefer to do this after installation is complete, it will be located at:"
Write-Host ""
Write-Host "$FILE_PATH\BGAnimations\_shared background\Datum\DatumOptions.lua"
Write-Host ""
Write-Host "Install optional theme sound effects? This will replace sound effects across the ENTIRE THEME,"
Write-Host "(Current sound effects will be backed up at $PWD\.backup\Sounds\)"
$DO_SOUNDS_INSTALLATION = Read-YesNo -Prompt '' -Default $true
Write-Host ""
Write-Host "Install optional theme tweaks? This will only minorly tweak the base theme colors."
$DO_TWEAKS_INSTALLATION = Read-YesNo -Prompt '' -Default $true
Write-Host ""

$SHARED_BG = Join-Path $FILE_PATH 'BGAnimations\_shared background'
$GRAPHICS  = Join-Path $FILE_PATH 'Graphics'
$SCRIPTS   = Join-Path $FILE_PATH 'Scripts'
$SOUNDS    = Join-Path $FILE_PATH 'Sounds'

# BGAnimations / _shared background
if (Test-Path -LiteralPath $SHARED_BG -PathType Container) {
    $srcDatum = Join-Path $PWD 'BGAnimations\_shared background\Datum'
    Copy-Directory -Source $srcDatum -Destination $SHARED_BG

    $srcOptions = Join-Path $PWD 'DatumOptions.lua'
    $destOptions = Join-Path (Join-Path $SHARED_BG 'Datum') 'DatumOptions.lua'
    Copy-Item -LiteralPath $srcOptions -Destination $destOptions -Force

    # default.lua
    $defaultLua = Join-Path $SHARED_BG 'default.lua'
    if (-not (Test-Path -LiteralPath $defaultLua)) { Fail 3 "[Err3] Failed to match line in: $defaultLua" }
    $defaultContent = Get-Content -LiteralPath $defaultLua -Raw
    $sharedBgDefaultLua = 'af[#af+1] = LoadActor("./Datum/Datum.lua", file)'
    if ($defaultContent -match 'Datum\.lua') {
        # Already installed
    } elseif ($defaultContent -match 'af\[#af\+1\] = LoadActor') {
        Backup-File -Path $defaultLua
        Insert-LineBefore -Path $defaultLua -Regex '^[ \t]*return af' -Line $sharedBgDefaultLua
    } else {
        Fail 3 "[Err3] Failed to match line in: $defaultLua"
    }

    # Normal.lua
    $normalLua = Join-Path $SHARED_BG 'Normal.lua'
    if (-not (Test-Path -LiteralPath $normalLua)) { Fail 3 "[Err3] Failed to match line in: $normalLua" }
    $normalContent = Get-Content -LiteralPath $normalLua -Raw
    if ($normalContent -match 'Datum') {
        # Already installed
    } elseif ($normalContent -match 'self:visible\(not ThemePrefs') {
        Backup-File -Path $normalLua
        Regex-Replace-InFile -Path $normalLua -Pattern '(self:visible\(.*)(\))' -Replacement '$1 and style ~= "Datum"$2'
        Regex-Replace-OnMatchingLines -Path $normalLua -LineFilter 'ThemePrefs\.Get\("RainbowMode"\)' -Pattern '[ \t]*then' -Replacement ' or style == "Datum" then'
    } else {
        Fail 3 "[Err3] Failed to match line in: $normalLua"
    }
} else {
    Fail 4 '[Err4] Failed to install _shared background components.'
}


# Graphics
if (Test-Path -LiteralPath $GRAPHICS -PathType Container) {
    $visualStylesDir = Join-Path $GRAPHICS '_VisualStyles'
    if (-not (Test-Path -LiteralPath $visualStylesDir)) {
        New-Item -ItemType Directory -Path $visualStylesDir -Force | Out-Null
    }
    Copy-Directory -Source (Join-Path $PWD 'Graphics\_VisualStyles\Datum') -Destination $visualStylesDir

    if ($DO_TWEAKS_INSTALLATION) {
        $titleScroll = Join-Path $GRAPHICS 'ScreenTitleMenu scroll.lua'
        if (Test-Path -LiteralPath $titleScroll -PathType Leaf) {
            Backup-File -Path $titleScroll
            Replace-InFile -Path $titleScroll -Old 'PLAYER_2' -New 'PLAYER_1'
        }
    }
} else {
    Fail 4 '[Err4] Failed to install Graphics components.'
}

# Scripts / ThemePrefs
$themeprefs = Join-Path $SCRIPTS '99 SL-ThemePrefs.lua'
if (Test-Path -LiteralPath $SCRIPTS -PathType Container) {
    if (-not (Test-Path -LiteralPath $themeprefs)) { Fail 3 "[Err3] Failed to match line in: $themeprefs" }
    $tpContent = Get-Content -LiteralPath $themeprefs -Raw
    if ($tpContent -match 'Datum') {
        # Already installed
    } elseif ($tpContent -match 'local visualStyleValues') {
        Backup-File -Path $themeprefs
        Append-LineAfter -Path $themeprefs -Regex 'local visualStyleValues[ \t]*=[ \t]*\{' -Line 'visualStyleChoices[#visualStyleChoices+1]="💾"; visualStyleValues[#visualStyleValues+1]="Datum"'
    } else {
        Fail 3 "[Err3] Failed to match line in: $themeprefs"
    }
} else {
    Fail 4 '[Err4] Failed to install Scripts components.'
}


# Sounds
if (Test-Path -LiteralPath $SOUNDS -PathType Container) {
    $menuMusicLua = Join-Path $SOUNDS '_common menu music\default.lua'
    if (-not (Test-Path -LiteralPath $menuMusicLua)) { Fail 3 "[Err3] Failed to match line in: $menuMusicLua" }
    $mmContent = Get-Content -LiteralPath $menuMusicLua -Raw
    if ($mmContent -match 'Datum') {
        # Already installed
    } elseif ($mmContent -match 'local songs') {
        Backup-File -Path $menuMusicLua
        Append-LineAfter -Path $menuMusicLua -Regex '\}' -Line 'songs["Datum"]="everglow"'
    } else {
        Fail 3 "[Err3] Failed to match line in: $menuMusicLua"
    }

    $gameOverLua = Join-Path $SOUNDS 'ScreenGameOver music.lua'
    if (-not (Test-Path -LiteralPath $gameOverLua)) { Fail 3 "[Err3] Failed to match line in: $gameOverLua" }
    $goContent = Get-Content -LiteralPath $gameOverLua -Raw
    if ($goContent -match 'Datum') {
        # Already installed
    } elseif ($goContent -match 'audio_file') {
        Backup-File -Path $gameOverLua
        Insert-LineBefore -Path $gameOverLua -Regex 'end' -Line 'elseif style == "Datum" then audio_file = "todolist.ogg"'
    } else {
        Fail 3 "[Err3] Failed to match line in: $gameOverLua"
    }

    # Copy music files into the target theme
    $everglow = Join-Path $PWD 'Sounds\_common menu music\everglow (loop).ogg'
    $todolist = Join-Path $PWD 'Sounds\todolist.ogg'
    Copy-Item -LiteralPath $everglow -Destination (Join-Path $SOUNDS '_common menu music') -Force
    Copy-Item -LiteralPath $todolist -Destination $SOUNDS -Force

    # Handle Evaluation Pass/Fail folders if they exist (ZMod only)
    $evalPass = Join-Path $SOUNDS 'Evaluation Pass'
    $evalFail = Join-Path $SOUNDS 'Evaluation Fail'
    if ((Test-Path -LiteralPath $evalPass -PathType Container) -and (Test-Path -LiteralPath $evalFail -PathType Container)) {
        $wipPass = Join-Path $PWD 'Sounds\Evaluation Pass\workinprogress (loop).ogg'
        $wipFail = Join-Path $PWD 'Sounds\Evaluation Fail\workinprogress (loop).ogg'
        Copy-Item -LiteralPath $wipPass -Destination $evalPass -Force
        Copy-Item -LiteralPath $wipFail -Destination $evalFail -Force
    }
    # TODO: SL Evaluation music installation, because its different.

    if ($DO_SOUNDS_INSTALLATION) {
        $soundsBackupDir = Join-Path $PWD '.backup\Sounds'
        if (-not (Test-Path -LiteralPath $soundsBackupDir)) {
            New-Item -ItemType Directory -Path $soundsBackupDir -Force | Out-Null
        }

        $overwriteDir = Join-Path $PWD 'Sounds\_overwrites'
        $replaceList = @()
        if (Test-Path -LiteralPath $overwriteDir -PathType Container) {
            $replaceList = @(Get-ChildItem -LiteralPath $overwriteDir -Filter '*.ogg' -File)
        }

        # Back up current version of SFX
        foreach ($f in $replaceList) {
            $original = Join-Path $SOUNDS $f.Name
            if (Test-Path -LiteralPath $original -PathType Leaf) {
                Copy-Item -LiteralPath $original -Destination $soundsBackupDir -Force
            }
        }
        # Install new sounds
        foreach ($f in $replaceList) {
            Copy-Item -LiteralPath $f.FullName -Destination $SOUNDS -Force
        }
    }
} else {
    Fail 4 '[Err4] Failed to install Sounds components.'
}

Write-Host ""
Write-Host '"Datum" Visual Style installed successfully!'
Write-Host ""