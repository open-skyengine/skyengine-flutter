# SkyEngine Flutter

SkyEngine Flutter 是基于 Flutter 开发的 MRP 应用模拟器前端。项目通过
`dart:ffi` 加载 Rust 实现的 [SkyEngine v2](skyengine)，提供 MRP 文件管理、
应用商店、虚拟按键、触摸输入、画面渲染、音频播放和运行参数配置等功能。

## 功能概览

- 使用 SkyEngine v2 解析并运行 MRP 应用
- 通过稳定的 `skyengine_api_*` C ABI 对接 Flutter
- 在独立原生线程中运行虚拟机，避免持续阻塞 Flutter UI 线程
- 支持 RGB565 帧缓冲到 Flutter RGBA 图像的渲染
- 支持按键、触摸、拖动和文本输入
- 支持 MRP 文件导入、本地应用管理和应用商店
- 支持 Android、Windows 和 Linux 的共享库构建与打包

## 获取源码

本项目使用 Git 子模块管理 SkyEngine v2。克隆时需要同时拉取子模块：

```bash
git clone --recurse-submodules <repository-url>
```

如果已经完成普通克隆，可以执行：

```bash
git submodule update --init --recursive
```

## 开发环境

- Flutter stable
- Rust stable 与 Cargo
- Android 构建需要 Android SDK、NDK 和对应的 Rust 目标
- Windows 构建需要启用 C++ 桌面开发工具链
- Linux 构建需要 Flutter Linux 桌面依赖

安装 Android 手机 ABI 对应的 Rust 目标：

```powershell
rustup target add aarch64-linux-android armv7-linux-androideabi
```

安装 Flutter 依赖：

```bash
flutter pub get
```

## 运行与构建

运行 Flutter 应用：

```bash
flutter run
```

构建 Android APK：

```bash
flutter build apk --release --target-platform android-arm,android-arm64
```

构建 Windows 应用：

```powershell
flutter build windows --release
```

Gradle/CMake 会自动调用 Cargo 编译共享库，不需要在仓库中提交预编译的
`.so` 或 `.dll` 文件。Android 和 Linux 使用 `libskyengine.so`，Windows
使用 `skyengine.dll`。

## 测试

检查 Flutter 代码：

```bash
flutter analyze
flutter test
```

检查 SkyEngine core 与 Flutter FFI 桥接层：

```bash
cd skyengine
cargo test -p skyengine-core -p skyengine-ffi
cargo clippy -p skyengine-core -p skyengine-ffi --all-targets -- -D warnings
```

## Android 分架构 APK

Debug APK 和通用 Release APK 会包含调试资源或多个原生 ABI，因此体积较大。
本地安装或直接分发时，可以构建分架构 Release APK：

```powershell
.\tool\build_android_split_apks.ps1
```

脚本会分别生成：

- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`

应安装与设备 ABI 匹配的 APK。现代 Android 设备通常使用 `arm64-v8a`。

带 `v*` 标签的 CI 发布会保留通用包，并同时发布两个分架构包：

- `skyengine-v<version>.apk`：通用包
- `skyengine-v<version>-arm64-v8a.apk`
- `skyengine-v<version>-armeabi-v7a.apk`

发布流程还会以相同版本号将 APK 上传到模拟器更新服务。需要配置
`MRP_SERVER`，并提供具有 `emulator_apk:publish` 权限的
`MRP_ACCESS_TOKEN` secret。手动发布示例：

```powershell
$env:MRP_SERVER = "https://example.com"
$env:MRP_ACCESS_TOKEN = "mrp_at_xxxx"
node tool/publish_emulator_apk.js `
  --file build/app/outputs/flutter-apk/app-arm64-v8a-release.apk `
  --architecture arm64-v8a
```

## 许可证

本项目采用 [MIT 许可证](LICENSE)。SkyEngine 子模块也采用 MIT 许可证，
详见 [`skyengine/LICENSE`](skyengine/LICENSE)。
