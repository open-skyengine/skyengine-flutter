# skyengine

A new Flutter project.

## Native SkyEngine library

The app loads SkyEngine v2 through `dart:ffi`. The `skyengine` submodule builds
the Rust runtime as a native shared library named `libskyengine.so` on Android
and Linux or `skyengine.dll` on Windows. Flutter drives the runtime through the
stable `skyengine_api_*` C ABI while the VM runs on its own native thread.

Install Rust and the Android targets before building an APK:

```powershell
rustup target add aarch64-linux-android armv7-linux-androideabi
flutter build apk --release --target-platform android-arm,android-arm64
```

The Gradle/CMake build compiles and packages the shared library automatically;
prebuilt `.so` files are not checked into this repository. Windows and Linux
Flutter builds use the same CMake target and copy the resulting shared library
next to the application executable.

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
