# v0.18 验证

- flutter pub get --offline 成功；flutter analyze --no-pub --no-fatal-infos 通过，6 条既有提示，无错误/警告。
- 配置、更新平台选择、监控映射、流量计量与请求检查 58 项通过。
- 选择性代理、监控界面、节点卡片和关于页回归 47 项通过。
- widgets 与动态文案扫描 495 项通过；修复 Windows 路径分隔符导致生成文案文件误报。
- Windows 生产与 SAFE_MODE 资源构建；SAFE_MODE 启动成功，只关闭本任务记录的自有进程。
- Android 构建、签名与结构结果见发布校验文件；没有已连接真机测试，不宣称实际网络拦截或所有连接识别已自动验证。

APK v2 签名、应用 ID com.xiaoyanjiu.flclashselect、版本 0.18.0、最低 SDK 24 与 ARM64 架构通过 aapt / apksigner 核验；证书与本地固定私钥对应。公开指纹和 APK 校验值见 APK_VERIFICATION.json。


## Windows v0.18.1 修复验证

独立文件设置、真实 SharedPreferences API 保存/重新读取、旧配置迁移及首次关闭三项启动设置测试通过；更新检测与 Android 监控回归通过。依赖解析与静态检查通过（仅既有 info）。Windows 发布与 SAFE_MODE 资源构建通过，使用上游原生 runner 与此前验证的本地辅助程序。Android APK 仍为 v0.18.0，签名与验证记录不变。
