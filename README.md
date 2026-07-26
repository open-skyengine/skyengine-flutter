# skyengine

A new Flutter project.

## Android APK size

Debug APKs and universal release APKs are large because they include Flutter
debug assets or multiple native ABIs. For local installation or direct
distribution, build split release APKs:

```powershell
.\tool\build_android_split_apks.ps1
```

The script generates one APK per Android phone ABI:

- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`

Install the APK matching the target device ABI. On modern phones this is usually
`app-arm64-v8a-release.apk`.

Tagged CI releases publish three APKs while keeping the original unsuffixed
filename for the universal package:

- `skyengine-v<version>.apk` (universal)
- `skyengine-v<version>-arm64-v8a.apk`
- `skyengine-v<version>-armeabi-v7a.apk`

The release workflow also publishes each APK to the emulator update server under
the same version code. Configure `MRP_SERVER` and an `MRP_ACCESS_TOKEN` secret
with the `emulator_apk:publish` scope. To publish one package manually:

```powershell
$env:MRP_SERVER = "https://example.com"
$env:MRP_ACCESS_TOKEN = "mrp_at_xxxx"
node tool/publish_emulator_apk.js `
  --file build/app/outputs/flutter-apk/app-arm64-v8a-release.apk `
  --architecture arm64-v8a
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
