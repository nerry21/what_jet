# ═══════════════════════════════════════════════════════════════════════════════
# WhatsJet Design System — Auto Migration (PowerShell for Windows)
# ═══════════════════════════════════════════════════════════════════════════════
#
# CARA PAKAI:
#   1. Letakkan file ini di root project (sejajar pubspec.yaml)
#   2. Buka PowerShell di folder project
#   3. Jalankan:
#      powershell -ExecutionPolicy Bypass -File migrate_design_system.ps1
#
# ═══════════════════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Continue"
$LIB = "lib"
$BACKUP = "lib_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Cyan
Write-Host "    WhatsJet Premium Design System - Auto Migration" -ForegroundColor Cyan
Write-Host "  ==========================================================" -ForegroundColor Cyan
Write-Host ""

# ─── Pre-flight ──────────────────────────────────────────────────────────────
if (-not (Test-Path "$LIB\main.dart")) {
    Write-Host "  ERROR: lib\main.dart not found. Run from project root." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path "$LIB\core\theme")) {
    Write-Host "  ERROR: lib\core\theme\ not found." -ForegroundColor Red
    exit 1
}

# ─── Step 0: Backup ─────────────────────────────────────────────────────────
Write-Host "  [0/8] Creating backup..." -ForegroundColor Yellow
Copy-Item -Recurse -Force $LIB $BACKUP
Write-Host "  OK  Backup created -> $BACKUP\" -ForegroundColor Green
Write-Host ""

# ─── Step 1: Update main.dart ───────────────────────────────────────────────
Write-Host "  [1/8] Updating main.dart..." -ForegroundColor Yellow

$mainContent = [System.IO.File]::ReadAllText("$LIB\main.dart", [System.Text.Encoding]::UTF8)

if (-not $mainContent.Contains("core/theme/app_theme.dart")) {
    $mainContent = $mainContent.Replace(
        "import 'core/config/app_config.dart';",
        "import 'core/config/app_config.dart';`nimport 'core/theme/app_theme.dart';"
    )
    Write-Host "  OK  Added AppTheme import" -ForegroundColor Green
}

$mainContent = $mainContent.Replace("theme: AppConfig.theme()", "theme: AppTheme.light()")
[System.IO.File]::WriteAllText("$LIB\main.dart", $mainContent, [System.Text.Encoding]::UTF8)
Write-Host "  OK  theme -> AppTheme.light()" -ForegroundColor Green
Write-Host ""

# ─── Step 2: Find all presentation files ────────────────────────────────────
Write-Host "  [2/8] Scanning presentation files..." -ForegroundColor Yellow

$presFiles = Get-ChildItem -Path "$LIB\features" -Recurse -Filter "*.dart" |
    Where-Object { $_.FullName -like "*\presentation\*" }

Write-Host "  OK  Found $($presFiles.Count) presentation files" -ForegroundColor Green
Write-Host ""

# ─── Step 3: Add design system imports ──────────────────────────────────────
Write-Host "  [3/8] Adding design system imports..." -ForegroundColor Yellow

$importCount = 0
foreach ($file in $presFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)

    if ($content.Contains("core/theme/app_colors.dart")) { continue }
    if (-not $content.Contains("AppConfig.")) { continue }

    # Count depth from lib/features/.../presentation/.../*.dart
    $relPath = $file.FullName.Substring($file.FullName.IndexOf("features"))
    $depth = ($relPath.Split('\').Count)
    $prefix = "../" * $depth

    $importBlock = @"
import '${prefix}core/theme/app_colors.dart';
import '${prefix}core/theme/app_typography.dart';
import '${prefix}core/theme/app_dimensions.dart';
import '${prefix}core/theme/app_animations.dart';
import '${prefix}core/theme/app_components.dart';
"@

    $content = $importBlock + "`n" + $content
    [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
    $importCount++
}
Write-Host "  OK  Added imports to $importCount files" -ForegroundColor Green
Write-Host ""

# ─── Step 4: Replace AppConfig colors ───────────────────────────────────────
Write-Host "  [4/8] Replacing AppConfig color references..." -ForegroundColor Yellow

# Define all color replacements
$colorReplacements = @(
    # AppConfig named colors
    @("AppConfig.green",            "AppColors.primary")
    @("AppConfig.greenLight",       "AppColors.primary200")
    @("AppConfig.purple",           "AppColors.accent")
    @("AppConfig.purpleLight",      "AppColors.accent200")
    @("AppConfig.softBackground",   "AppColors.scaffoldBackground")
    @("AppConfig.softBackgroundAlt","AppColors.borderLight")
    @("AppConfig.danger",           "AppColors.error")
    @("AppConfig.success",          "AppColors.success")
    @("AppConfig.mutedText",        "AppColors.neutral500")
    @("AppConfig.subtleText",       "AppColors.neutral300")
    @("AppConfig.bubbleIncoming",   "AppColors.bubbleIncoming")
    @("AppConfig.bubbleOutgoing",   "AppColors.bubbleOutgoing")
    @("AppConfig.bubbleOutgoingAlt","AppColors.bubbleOutgoingGradientEnd")
    @("AppConfig.readReceipt",      "AppColors.readReceipt")

    # Common hardcoded hex colors
    @("const Color(0xFFF5F5F5)",    "AppColors.scaffoldBackground")
    @("Color(0xFFF5F5F5)",          "AppColors.scaffoldBackground")
    @("const Color(0xFFE8E8E8)",    "AppColors.borderLight")
    @("Color(0xFFE8E8E8)",          "AppColors.borderLight")
    @("const Color(0xFFF0F0F0)",    "AppColors.neutral50")
    @("Color(0xFFF0F0F0)",          "AppColors.neutral50")
    @("const Color(0xFF65676B)",    "AppColors.neutral500")
    @("Color(0xFF65676B)",          "AppColors.neutral500")
    @("const Color(0xFF999999)",    "AppColors.neutral300")
    @("Color(0xFF999999)",          "AppColors.neutral300")
    @("const Color(0xFF00A884)",    "AppColors.primary600")
    @("Color(0xFF00A884)",          "AppColors.primary600")
    @("const Color(0xFF00D084)",    "AppColors.primary200")
    @("Color(0xFF00D084)",          "AppColors.primary200")
    @("const Color(0xFF8764D5)",    "AppColors.accent")
    @("Color(0xFF8764D5)",          "AppColors.accent")
    @("const Color(0xFFFF4757)",    "AppColors.error")
    @("Color(0xFFFF4757)",          "AppColors.error")
    @("const Color(0xFF31A24C)",    "AppColors.success")
    @("Color(0xFF31A24C)",          "AppColors.success")
    @("const Color(0xFF53BDEB)",    "AppColors.readReceipt")
    @("Color(0xFF53BDEB)",          "AppColors.readReceipt")
    @("const Color(0xFFFFF5F5)",    "AppColors.error50")
    @("Color(0xFFFFF5F5)",          "AppColors.error50")
    @("const Color(0xFFFFF4E5)",    "AppColors.warning50")
    @("Color(0xFFFFF4E5)",          "AppColors.warning50")
    @("const Color(0xFF9A6700)",    "AppColors.warning800")
    @("Color(0xFF9A6700)",          "AppColors.warning800")

    # Colors.white/black in styling
    @("color: Colors.white",        "color: AppColors.white")
    @("color: Colors.black87",      "color: AppColors.neutral800")
    @("color: Colors.black",        "color: AppColors.neutral800")
)

$colorFileCount = 0
$allFiles = @($presFiles) + @(Get-Item "$LIB\main.dart")

foreach ($file in $allFiles) {
    $path = if ($file -is [string]) { $file } else { $file.FullName }
    if (-not (Test-Path $path)) { continue }

    $content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $original = $content

    foreach ($pair in $colorReplacements) {
        $content = $content.Replace($pair[0], $pair[1])
    }

    if ($content -ne $original) {
        [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
        $colorFileCount++
    }
}
Write-Host "  OK  Replaced colors in $colorFileCount files" -ForegroundColor Green
Write-Host ""

# ─── Step 5: Replace BorderRadius ───────────────────────────────────────────
Write-Host "  [5/8] Replacing BorderRadius magic numbers..." -ForegroundColor Yellow

$radiusReplacements = @(
    @("BorderRadius.circular(28)",  "AppRadii.borderRadiusXxxl")
    @("BorderRadius.circular(24)",  "AppRadii.borderRadiusXxl")
    @("BorderRadius.circular(22)",  "AppRadii.borderRadiusXl")
    @("BorderRadius.circular(20)",  "AppRadii.borderRadiusXl")
    @("BorderRadius.circular(18)",  "AppRadii.borderRadiusLg")
    @("BorderRadius.circular(16)",  "AppRadii.borderRadiusLg")
    @("BorderRadius.circular(14)",  "AppRadii.borderRadiusMd")
    @("BorderRadius.circular(12)",  "AppRadii.borderRadiusMd")
    @("BorderRadius.circular(10)",  "AppRadii.borderRadiusSm")
    @("BorderRadius.circular(999)", "AppRadii.borderRadiusPill")
)

$radiusFileCount = 0
foreach ($file in $presFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $original = $content

    foreach ($pair in $radiusReplacements) {
        $content = $content.Replace($pair[0], $pair[1])
    }

    if ($content -ne $original) {
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
        $radiusFileCount++
    }
}
Write-Host "  OK  Replaced radii in $radiusFileCount files" -ForegroundColor Green
Write-Host ""

# ─── Step 6: Replace spacing ────────────────────────────────────────────────
Write-Host "  [6/8] Replacing SizedBox spacing..." -ForegroundColor Yellow

$spacingReplacements = @(
    @("const SizedBox(height: 4)",  "AppSpacing.verticalXs")
    @("SizedBox(height: 4)",        "AppSpacing.verticalXs")
    @("const SizedBox(height: 8)",  "AppSpacing.verticalSm")
    @("SizedBox(height: 8)",        "AppSpacing.verticalSm")
    @("const SizedBox(height: 12)", "AppSpacing.verticalMd")
    @("SizedBox(height: 12)",       "AppSpacing.verticalMd")
    @("const SizedBox(height: 16)", "AppSpacing.verticalLg")
    @("SizedBox(height: 16)",       "AppSpacing.verticalLg")
    @("const SizedBox(height: 24)", "AppSpacing.verticalXxl")
    @("SizedBox(height: 24)",       "AppSpacing.verticalXxl")
    @("const SizedBox(height: 32)", "AppSpacing.verticalXxxl")
    @("SizedBox(height: 32)",       "AppSpacing.verticalXxxl")
    @("const SizedBox(width: 4)",   "AppSpacing.horizontalXs")
    @("SizedBox(width: 4)",         "AppSpacing.horizontalXs")
    @("const SizedBox(width: 8)",   "AppSpacing.horizontalSm")
    @("SizedBox(width: 8)",         "AppSpacing.horizontalSm")
    @("const SizedBox(width: 12)",  "AppSpacing.horizontalMd")
    @("SizedBox(width: 12)",        "AppSpacing.horizontalMd")
    @("const SizedBox(width: 16)",  "AppSpacing.horizontalLg")
    @("SizedBox(width: 16)",        "AppSpacing.horizontalLg")
)

$spacingFileCount = 0
foreach ($file in $presFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $original = $content

    foreach ($pair in $spacingReplacements) {
        $content = $content.Replace($pair[0], $pair[1])
    }

    if ($content -ne $original) {
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
        $spacingFileCount++
    }
}
Write-Host "  OK  Replaced spacing in $spacingFileCount files" -ForegroundColor Green
Write-Host ""

# ─── Step 7: Cleanup unused AppConfig imports ───────────────────────────────
Write-Host "  [7/8] Cleaning up unused AppConfig imports..." -ForegroundColor Yellow

$cleanupCount = 0
foreach ($file in $presFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)

    if ($content.Contains("app_config.dart")) {
        # Count how many times AppConfig. appears (excluding import line)
        $lines = $content.Split("`n")
        $usageCount = 0
        foreach ($line in $lines) {
            if ($line -notmatch "^import " -and $line.Contains("AppConfig.")) {
                $usageCount++
            }
        }

        if ($usageCount -eq 0) {
            # Remove the import line
            $newLines = $lines | Where-Object { $_ -notmatch "import.*app_config\.dart" }
            $content = $newLines -join "`n"
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            $cleanupCount++
        }
    }
}
Write-Host "  OK  Cleaned $cleanupCount unused AppConfig imports" -ForegroundColor Green
Write-Host ""

# ─── Step 8: Report ─────────────────────────────────────────────────────────
Write-Host "  [8/8] Done!" -ForegroundColor Yellow
Write-Host ""

# Count remaining
$remainConfig = 0
$remainColors = 0
foreach ($file in $presFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $lines = $content.Split("`n")
    foreach ($line in $lines) {
        if ($line -notmatch "^import " -and $line.Contains("AppConfig.")) { $remainConfig++ }
        if ($line -match "Color\(0x") { $remainColors++ }
    }
}

Write-Host "  ==========================================================" -ForegroundColor Cyan
Write-Host "    Migration Complete!" -ForegroundColor Cyan
Write-Host "  ==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [OK] Theme:    main.dart -> AppTheme.light()" -ForegroundColor Green
Write-Host "  [OK] Imports:  $importCount files updated" -ForegroundColor Green
Write-Host "  [OK] Colors:   $colorFileCount files migrated" -ForegroundColor Green
Write-Host "  [OK] Radii:    $radiusFileCount files migrated" -ForegroundColor Green
Write-Host "  [OK] Spacing:  $spacingFileCount files migrated" -ForegroundColor Green
Write-Host "  [OK] Cleanup:  $cleanupCount unused imports removed" -ForegroundColor Green
Write-Host ""
Write-Host "  Remaining (manual/Claude Code):" -ForegroundColor Yellow
Write-Host "    $remainConfig AppConfig refs (non-color: baseUrl, appTitle)" -ForegroundColor White
Write-Host "    $remainColors inline Color(0x...) (unique per-widget)" -ForegroundColor White
Write-Host ""
Write-Host "  Backup: $BACKUP\" -ForegroundColor DarkGray
Write-Host "  Rollback: Copy-Item -Recurse -Force $BACKUP\* lib\" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Next: flutter analyze && flutter run" -ForegroundColor Cyan
Write-Host ""
