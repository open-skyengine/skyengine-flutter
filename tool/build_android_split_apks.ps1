param(
  [switch]$Clean,
  [string]$SymbolDir = "build\symbols\android-split-arm"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  if ($Clean) {
    flutter clean
  }

  flutter build apk `
    --release `
    --target-platform "android-arm,android-arm64" `
    --split-per-abi `
    --split-debug-info="$SymbolDir"

  Get-ChildItem -Path "build\app\outputs\flutter-apk" -Filter "app-*-release.apk" |
    Where-Object { $_.Name -in @("app-armeabi-v7a-release.apk", "app-arm64-v8a-release.apk") } |
    Sort-Object Name |
    Select-Object Name, @{Name = "MB"; Expression = { [math]::Round($_.Length / 1MB, 2) } }, FullName |
    Format-Table -AutoSize
} finally {
  Pop-Location
}
