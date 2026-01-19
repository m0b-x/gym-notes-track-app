# Script to update re_editor package with cursor handle patch
# Run from the project root: .\scripts\update_re_editor.ps1
# Works on Windows and macOS/Linux (via PowerShell Core)

param(
    [string]$Version = "0.8.0"
)

$ErrorActionPreference = "Stop"

# Paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PackagesDir = Join-Path $ProjectRoot "packages"
$ReEditorDest = Join-Path $PackagesDir "re_editor"

# Function to find pub cache
function Find-PubCache {
    param([string]$PackageName, [string]$PackageVersion)
    
    $SearchPaths = @()
    
    # Get pub cache from environment or flutter config
    $PubCacheEnv = $env:PUB_CACHE
    if ($PubCacheEnv -and (Test-Path $PubCacheEnv)) {
        $SearchPaths += Join-Path $PubCacheEnv "hosted\pub.dev"
    }
    
    # Platform-specific default locations
    if ($IsWindows -or ($env:OS -eq "Windows_NT")) {
        # Windows: %LOCALAPPDATA%\Pub\Cache
        if ($env:LOCALAPPDATA) {
            $SearchPaths += Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
        }
        # Flutter SDK bundled cache (check flutter location)
        $FlutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
        if ($FlutterCmd) {
            $FlutterRoot = Split-Path (Split-Path $FlutterCmd.Source)
            $SearchPaths += Join-Path $FlutterRoot "PubCache\hosted\pub.dev"
            $SearchPaths += Join-Path $FlutterRoot ".pub-cache\hosted\pub.dev"
        }
    } else {
        # macOS/Linux: ~/.pub-cache
        $Home = $env:HOME
        if ($Home) {
            $SearchPaths += Join-Path $Home ".pub-cache\hosted\pub.dev"
        }
        # Flutter SDK bundled cache
        $FlutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
        if ($FlutterCmd) {
            $FlutterRoot = Split-Path (Split-Path $FlutterCmd.Source)
            $SearchPaths += Join-Path $FlutterRoot ".pub-cache\hosted\pub.dev"
        }
    }
    
    # Search for the package
    foreach ($basePath in $SearchPaths) {
        $fullPath = Join-Path $basePath "$PackageName-$PackageVersion"
        if (Test-Path $fullPath) {
            return $fullPath
        }
    }
    
    return $null
}

$FlutterPubCache = Find-PubCache -PackageName "re_editor" -PackageVersion $Version

if (-not $FlutterPubCache) {
    Write-Error "re_editor v$Version not found in pub cache. Run 'flutter pub get' first."
    exit 1
}

Write-Host "Updating re_editor from: $FlutterPubCache" -ForegroundColor Cyan

# Remove existing
if (Test-Path $ReEditorDest) {
    Write-Host "Removing existing re_editor..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $ReEditorDest
}

# Create packages directory if needed
if (-not (Test-Path $PackagesDir)) {
    New-Item -ItemType Directory -Path $PackagesDir | Out-Null
}

# Copy fresh version
Write-Host "Copying re_editor v$Version..." -ForegroundColor Yellow
Copy-Item -Recurse $FlutterPubCache $ReEditorDest

# Remove unnecessary folders
Write-Host "Cleaning up unnecessary files..." -ForegroundColor Yellow
$FoldersToRemove = @("example", "test", "arts", ".dart_tool")
foreach ($folder in $FoldersToRemove) {
    $path = Join-Path $ReEditorDest $folder
    if (Test-Path $path) {
        Remove-Item -Recurse -Force $path
        Write-Host "  Removed: $folder" -ForegroundColor DarkGray
    }
}

# Apply the cursor handle patch
Write-Host "Applying cursor handle patch..." -ForegroundColor Yellow
$SelectionFile = Join-Path $ReEditorDest "lib\src\_code_selection.dart"

if (-not (Test-Path $SelectionFile)) {
    Write-Error "Could not find _code_selection.dart"
    exit 1
}

$content = Get-Content $SelectionFile -Raw

# The patch: change hideHandle() to showHandle(context) on single tap
$oldCode = 'widget.selectionOverlayController.hideHandle();
      widget.selectionOverlayController.hideToolbar();
    }
    widget.inputController.ensureInput();
  }

  void _onMobileLongPressedStart'

$newCode = 'widget.selectionOverlayController.showHandle(context);
      widget.selectionOverlayController.hideToolbar();
    }
    widget.inputController.ensureInput();
  }

  void _onMobileLongPressedStart'

if ($content -match [regex]::Escape('widget.selectionOverlayController.hideHandle();')) {
    $content = $content -replace [regex]::Escape($oldCode), $newCode
    Set-Content $SelectionFile -Value $content -NoNewline
    Write-Host "  Patch applied successfully!" -ForegroundColor Green
} elseif ($content -match [regex]::Escape('widget.selectionOverlayController.showHandle(context);')) {
    Write-Host "  Patch already applied." -ForegroundColor Green
} else {
    Write-Warning "Could not find the code to patch. The re_editor version may have changed."
}

Write-Host "`nDone! Run 'flutter pub get' to apply changes." -ForegroundColor Cyan
