# FlClash Select v0.19.0

- 手机端 VPN 随内核按钮同步启停，移除单独 VPN 卡片及“正在开启/关闭 VPN”的提示；系统首次 VPN 授权与错误提示保留。
- 手机仪表盘进入编辑后可直接拖动卡片换位。监控卡片下边缘提供高度调整条，保存后保留高度。
- 手机和桌面仪表盘代理卡片隐藏延迟测试结果 Timeout 的节点；未测试节点仍显示，重新测试成功后恢复显示。隐藏节点仍参与整组延迟测试。
- Windows 延续独立免安装设置，首次自启动、静默启动、自动运行关闭。两端从本仓库检测对应平台更新。

Android ARM64 / Android 7+，本版使用与 v0.18.0 相同签名，可覆盖安装保留配置，尚未在真机验证。Windows ZIP 内目录为 FlClashSelect-v0.19.0；更新前备份 select-data 并退出旧版本。发布包不含个人订阅、配置或签名私钥。

GNU GPL v3，保留 FlClash 及第三方作者署名，见 LICENSE、THIRD_PARTY_NOTICES.md 与 BUILDING.md。Android 连接监控为每秒快照，极短连接和部分应用/域名可能无法识别。

已知检查限制：扩大仪表盘测试时，未修改的 traffic_summary 窄屏行出现溢出，4 项添加卡片测试失败。本次拖动、尺寸调整、节点过滤、设置保存和 Android 服务状态机测试通过；问题记录在 VERIFICATION.md。
