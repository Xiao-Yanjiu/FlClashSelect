# 构建说明

## 工具链与完整源码

Windows：Flutter 3.47.4 / Dart 3.13.3、Visual Studio C++ 桌面工具链、Go 1.26.4、Rust/Cargo、Zig 0.13.0、.NET Framework C# 编译器。依赖锁文件包含在仓库中，Clash.Meta 源码已直接包含。完整通用构建入口和工具要求见 .agents/commands.md。

```powershell
flutter pub get
dart run intl_utils:generate
dart run build_runner build
flutter analyze --no-fatal-infos
flutter test test/select/ test/common/tray_test.dart
dart setup.dart windows
```

## 选择性代理辅助程序

下载上游 WinDivert 2.2.2 正式 x64 包，保留 WinDivert.dll、WinDivert64.sys、WinDivert.lib 和对应许可。不要用未签名的自编驱动替代正式驱动。

ProxyBridge DLL 的 Zig/C11 编译选项和链接库见 plugins/select_engine/README.md；编译该目录 proxybridge 下的所有 C 源文件（含 pb_select_stats.c），定义 PROXYBRIDGE_EXPORTS，链接 WinDivert.lib、ws2_32、iphlpapi、advapi32，输出 ProxyBridgeCore.dll。

C# 编译器通常为 `%WINDIR%/Microsoft.NET/Framework64/v4.0.30319/csc.exe`。SelectRelay.cs 使用 `/target:winexe /platform:x64 /r:System.Web.Extensions.dll`；SelectTrayPopup.cs 再加入 `/r:System.Windows.Forms.dll /r:System.Drawing.dll`。输出 FlClashSelectRelay.exe、FlClashSelectTray.exe。

在 core 目录运行：

```powershell
$env:CGO_ENABLED='0'
go build -trimpath -ldflags '-H windowsgui -s -w' -o FlClashSelectSpeed.exe ./cmd/select-speed
```

将以上辅助程序、ProxyBridgeCore.dll、WinDivert.dll、WinDivert64.sys 及许可证一起放入 Windows bundle 的 select-engine 目录。程序、DLL 的 ABI 必须成套更新。

SVG 托盘变体生成：`python tool/generate_select_tray_icons.py --resvg <resvg.exe 路径>`，本发布使用公开 resvg 0.45.1。

## 本发布的实际构建路径

v0.17 的 runner、原生插件、Rust DLL、Go 主内核复用匹配的 FlClash v0.8.99 包；新编译 Dart UI、ProxyBridge 扩展、Relay、托盘程序和测速程序。为了复用上游原生件，临时构建副本关闭 native hooks，规范源码仍保留 hooks。具体资产命令和上游包校验值见 SELECT_BUILD.md；本仓库不宣称当前包是完全独立从零构建或字节级可复现。

本地自动测试如需启动桌面应用，使用 `SAFE_MODE=true`；完整 Release 的安装、节点和管理员网络行为应在自己的环境验证。


## Android v0.18

使用 Flutter 3.47.4、JDK 17、Gradle 9.8.0、Android SDK 37.0、NDK 28.2.13676358 和 CMake 3.22.1。正常源码构建保留原生 hooks 开启，需要 Go、Rust 以及宿主编译环境（Windows Rust MSVC 需要相应 Build Tools），安装 Rust aarch64-linux-android 目标；在 android/local.properties 中配置 SDK 与签名参数，在 android/app/keystore.jks 放自己的签名文件。不得提交这些私有文件。

flutter pub get
flutter build apk --release --target-platform android-arm64

本次 APK 构建使用独立工作副本：原生 hooks 关闭，暂时移除 :core 的 externalNativeBuild 块，向 :core/src/main/jniLibs/arm64-v8a 放入通过上游 SHA256SUMS 校验的同版本 libclash.so、libcore.so 和 librust_api.so；Flutter UI 与 Android 模块重新构建，使用自己的签名。具体 URL 和每个复用库 SHA256 见 ANDROID_NATIVE_PROVENANCE.json。发布源码保留完整原生构建路径，未包含预编译 SO、签名私钥或机器配置。构建网络临时使用公开插件镜像解决 TLS 不可达，镜像配置仅在本地构建缓存中。
