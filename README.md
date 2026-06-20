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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
