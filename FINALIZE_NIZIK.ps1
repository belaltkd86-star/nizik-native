$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "=== NIZIK FINALIZER ===" -ForegroundColor Green

$manifest = Join-Path $root "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
    $xml = Get-Content $manifest -Raw -Encoding UTF8

    # Preserve all existing manifest content (including deep links), only ensure required permissions/name.
    if ($xml -notmatch 'android.permission.INTERNET') {
        $xml = $xml -replace '(<manifest\b[^>]*>)', '$1`r`n    <uses-permission android:name="android.permission.INTERNET" />'
    }
    if ($xml -notmatch 'android.permission.ACCESS_COARSE_LOCATION') {
        $xml = $xml -replace '(<manifest\b[^>]*>)', '$1`r`n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />'
    }
    if ($xml -notmatch 'android.permission.ACCESS_FINE_LOCATION') {
        $xml = $xml -replace '(<manifest\b[^>]*>)', '$1`r`n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />'
    }

    $xml = [regex]::Replace(
        $xml,
        '(<application\b[^>]*\bandroid:label=")[^"]*(")',
        '$1نزیک$2',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    [System.IO.File]::WriteAllText($manifest, $xml, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Android manifest: OK" -ForegroundColor Green
} else {
    Write-Warning "AndroidManifest.xml not found; skipped."
}

Write-Host "Running flutter pub get..."
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

$icon1 = Join-Path $root "assets\branding\nizik_icon_1024.png"
$icon2 = Join-Path $root "assets\branding\nizik_icon_foreground_1024.png"
if ((Test-Path $icon1) -and (Test-Path $icon2)) {
    Write-Host "Generating app icons..."
    dart run flutter_launcher_icons
    if ($LASTEXITCODE -ne 0) { throw "flutter_launcher_icons failed" }
} else {
    Write-Warning "Branding icon assets are missing, so icon generation was skipped."
}

$splash = Join-Path $root "assets\branding\nizik_splash_logo_1024.png"
if (Test-Path $splash) {
    Write-Host "Generating splash screen..."
    dart run flutter_native_splash:create
    if ($LASTEXITCODE -ne 0) { throw "flutter_native_splash failed" }
} else {
    Write-Warning "Splash asset is missing, so splash generation was skipped."
}

Write-Host ""
Write-Host "DONE - Nizik final configuration is ready." -ForegroundColor Green
