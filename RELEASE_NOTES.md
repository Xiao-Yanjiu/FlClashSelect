# v0.18.0 测试版

- 新增 Android arm64 APK：独立应用 ID 与签名；订阅、节点选择、延迟测试、VPN 和规则。
- Android 将选择性代理卡片改为代理连接监控：应用、域名/IP、规则/节点和流量，过滤直连与拒绝；Windows 选择性代理功能保留。
- Windows / Android 更新检查改为 Xiao-Yanjiu/FlClashSelect，包含测试版并分别匹配 Windows 免安装 ZIP、Android APK，失败明确提示。
- Windows 包内目录 FlClashSelect-v0.18；首次默认关闭自启动、静默启动和自动运行；1400×720 初始仪表盘保留。

GPL v3 衍生项目，保留 FlClash 作者署名和第三方许可。Windows 与 Android 部分原生组件复用匹配上游发布，来源、SHA256 和对应源码完整提供。APK 不含 Windows 拦截驱动或下载测速 EXE；原作者 Firebase 配置不用于本应用。

监控每秒读取内核快照，可能遗漏极短连接；未知应用或域名不猜测，显示未知/IP。真机网络功能需要用户环境验证。更新检查提示下载，不自动安装或覆盖。
