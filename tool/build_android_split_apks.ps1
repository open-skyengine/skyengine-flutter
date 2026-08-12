param(
  [switch]$Clean,
  [string]$SymbolDir = "build\symbols\android-split-arm",
  [string]$AppStoreBaseUrl = $env:APP_STORE_BASE_URL,
  [string]$AppStoreAppId = $env:APP_STORE_APP_ID,
  [string]$AppStoreAppSecret = $env:APP_STORE_APP_SECRET
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  if ($Clean) {
    flutter clean
    if ($LASTEXITCODE -ne 0) {
      throw "flutter clean failed with exit code $LASTEXITCODE"
    }
  }

  # 未提供时沿用 app_store_api.dart 内置的开发凭据。
  $dartDefines = @()
  if ($AppStoreBaseUrl) {
    $dartDefines += "--dart-define=APP_STORE_BASE_URL=$AppStoreBaseUrl"
  }
  if ($AppStoreAppId) {
    $dartDefines += "--dart-define=APP_STORE_APP_ID=$AppStoreAppId"
  }
  if ($AppStoreAppSecret) {
    $dartDefines += "--dart-define=APP_STORE_APP_SECRET=$AppStoreAppSecret"
  }

  $outputDir = "build\app\outputs\flutter-apk"
  $targets = @(
    @{ Platform = "android-arm64"; Abi = "arm64-v8a" },
    @{ Platform = "android-arm"; Abi = "armeabi-v7a" }
  )

  foreach ($target in $targets) {
    flutter build apk `
      --release `
      --target-platform $target.Platform `
      --split-debug-info="$SymbolDir" `
      @dartDefines
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter build failed for $($target.Abi) with exit code $LASTEXITCODE"
    }

    Copy-Item `
      -Path "$outputDir\app-release.apk" `
      -Destination "$outputDir\app-$($target.Abi)-release.apk" `
      -Force
  }

  Get-ChildItem -Path $outputDir -Filter "app-*-release.apk" |
    Where-Object { $_.Name -in @("app-armeabi-v7a-release.apk", "app-arm64-v8a-release.apk") } |
    Sort-Object Name |
    Select-Object Name, @{Name = "MB"; Expression = { [math]::Round($_.Length / 1MB, 2) } }, FullName |
    Format-Table -AutoSize
} finally {
  Pop-Location
}
