# FlClash Select v0.18.1（Windows 修复版）

- 修复免安装版继承系统共用设置导致静默启动、自动运行的问题。设置独立保存在 select-data/shared_preferences.json。
- 首次解压默认关闭自启动、静默启动、自动运行。已有本地数据库首次升级迁移旧配置并关闭这三项；独立设置保存后按用户选择运行。
- ZIP 内目录为 FlClashSelect-v0.18.1；不含订阅、节点账号、个人数据或签名私钥。
- Windows 与 Android 从本仓库 Releases 检测对应平台更新。检测后提示下载，不自动覆盖或安装。
- Android APK 继续使用 [v0.18.0](https://github.com/Xiao-Yanjiu/FlClashSelect/releases/tag/v0.18.0)，ARM64 / Android 7+。监控为每秒代理连接快照，可能遗漏极短连接；尚未在真机验证。
- GNU GPL v3；保留 FlClash 和第三方署名，见 LICENSE、THIRD_PARTY_NOTICES.md、BUILDING.md。

Windows 更新前备份 select-data，关闭旧版后解压新目录，按需迁移 select-data。选择性代理需要管理员权限，域名识别受 DNS 缓存和加密 DNS 影响。
