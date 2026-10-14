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


## v0.19.0 验证

- 52 项卡片拖动、节点过滤与内核启停回归通过。新增高度控制后，60 项尺寸拖动/换位、节点过滤及配置模型测试通过，1 项高度保存 JSON 回归通过。
- Android ServiceStateMachine 42 项测试通过，0 失败、0 错误。
- 代码生成、依赖解析、静态检查通过（6 项既有 info）；Windows 发布与 SAFE_MODE 资源及 Android APK 构建通过。
- APK 应用 ID、0.19.0 版本、ARM64、minSdk 24、targetSdk 37 及 APK v2 签名验证通过，证书与 v0.18.0 一致。
- 扩大的仪表盘/更新检查为 115 通过、4 失败：add_widget_test 的窄屏显示触发未修改的 traffic_summary.dart 行溢出，记录为后续问题；没有把该套检查列为全部通过。
- 未在 Android 真机运行；构建及触摸控件模拟测试不代替真机验证。
