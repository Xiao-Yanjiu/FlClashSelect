# v0.18 验证

- flutter pub get --offline 成功；flutter analyze --no-pub --no-fatal-infos 通过，6 条既有提示，无错误/警告。
- 配置、更新平台选择、监控映射、流量计量与请求检查 58 项通过。
- 选择性代理、监控界面、节点卡片和关于页回归 47 项通过。
- widgets 与动态文案扫描 495 项通过；修复 Windows 路径分隔符导致生成文案文件误报。
- Windows 生产与 SAFE_MODE 资源构建；SAFE_MODE 启动成功，只关闭本任务记录的自有进程。
- Android 构建、签名与结构结果见发布校验文件；没有已连接真机测试，不宣称实际网络拦截或所有连接识别已自动验证。

APK v2 签名、应用 ID com.xiaoyanjiu.flclashselect、版本 0.18.0、最低 SDK 24 与 ARM64 架构通过 aapt / apksigner 核验；证书与本地固定私钥对应。公开指纹和 APK 校验值见 APK_VERIFICATION.json。
