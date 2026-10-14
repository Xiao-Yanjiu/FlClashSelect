# FlClash Select

基于 [chen08209/FlClash](https://github.com/chen08209/FlClash) 修改的 Windows / Android 代理客户端。保留原作者署名和开源许可；这是独立衍生项目，由 Xiao-Yanjiu 维护。

## 下载

[v0.19.0：Windows 免安装包、Android APK 与源码](https://github.com/Xiao-Yanjiu/FlClashSelect/releases/tag/v0.19.0)

下载 `FlClashSelect-0.19.0-windows-portable.zip`，解压整个目录后运行 `FlClashSelect.exe`。更新前备份 `select-data`，退出旧版本后启动新版本。发布包不包含订阅、节点账号或个人设置。首次默认窗口为 **1400×720**。

## 功能

- 继承 FlClash 的订阅、节点选择、规则/全局/直连、系统代理和 TUN 功能。
- Windows 选择性代理：按程序或域名匹配，与当前内核、出站模式和选中节点共享出口；可保持系统代理与 TUN 关闭。
- 仪表盘显示程序、目标域名、命中规则和流量统计，支持合并列、拖动卡片和紧凑节点选择。
- 节点延迟及下载测速；托盘提供主题按钮和实时状态。
- 托盘颜色优先级：**TUN 正红 > 系统代理橘红 > 内核/选择性代理蓝 > 全部关闭灰**。

## 使用与限制

阅读 [使用说明及注意事项](USAGE.md)、[构建说明](BUILDING.md) 和 [本版本验证记录](VERIFICATION.md)。当前发布支持 Windows x64 与 Android arm64；选择性代理拦截仅在 Windows 支持。Android 使用 VPN 与内核规则，监控卡片读取代理连接快照。

域名匹配依赖观测到的普通 DNS；加密 DNS、DNS 缓存、共享 IP 和浏览器连接复用可能影响匹配和域名显示。选择性代理通常需要管理员权限；首次修改规则后建议重新建立目标应用连接。

## 许可与致谢

本衍生项目沿用 **GNU GPL v3**，全文见 [LICENSE](LICENSE)。保留 FlClash、Clash.Meta/mihomo、ProxyBridge、WinDivert 以及其他组件的原作者和许可证；第三方文件按各自许可分发，详见 [第三方声明](THIRD_PARTY_NOTICES.md)。程序按许可证原文提供，不作额外保证。

重新分发修改版时，应保留原有署名与许可证，并按照适用许可提供对应源码。原项目介绍保留在 [UPSTREAM_README.md](UPSTREAM_README.md) 和 [UPSTREAM_README_zh_CN.md](UPSTREAM_README_zh_CN.md)。

## 源码结构

`lib/select/` 为选择性代理逻辑；`plugins/select_engine/` 包含拦截引擎、托盘/转发辅助程序和驱动对应源码；`core/cmd/select-speed/` 为测速程序。`core/Clash.Meta/` 在本仓库直接包含源码快照，固定来源版本见 [UPSTREAM.md](UPSTREAM.md)。

问题请提交到 [本仓库 Issues](https://github.com/Xiao-Yanjiu/FlClashSelect/issues)，附版本、Windows 版本、复现步骤和已脱敏的日志。


免安装包内目录为 `FlClashSelect-v0.19.0`。首次启动默认关闭“自启动”“静默启动”“自动运行”，窗口正常显示，请先添加订阅或配置。Windows 设置独立保存在 `select-data/shared_preferences.json`，新解压目录不会读取其他安装的设置。已有 `select-data/database.sqlite` 且没有独立设置文件时，仅迁移旧配置与版本记录，保留配置选择，并关闭这三项；之后尊重用户保存的设置。旧系统设置文件不修改。


## Android 与更新

Android 安装 `FlClashSelect-0.19.0-android-arm64.apk`，需要 64 位 ARM 手机。保留订阅、节点切换、延迟测试、VPN 和规则功能；不含 Windows 选择性代理驱动、托盘或下载测速 EXE。代理监控显示应用、域名/IP、规则/节点及流量，可按表头分组合并。无法识别的信息标记为未知；每秒读取的快照可能遗漏极短连接，最多保留当前卡片会话的 2000 个连接观测，流量以最后观测值为准。

两端在“工具 → 关于 → 检查更新”读取本仓库公开 Releases，自动检查也使用本仓库。包含测试版，按平台选择 Windows ZIP 或 Android arm64 APK；只提示并打开下载链接，不自动覆盖文件或安装。检测失败会明确显示网络错误。0.17 及更早版本需要先手动升级到 0.18 才能使用本仓库更新检测。

APK 使用独立应用 ID `com.xiaoyanjiu.flclashselect` 与本项目签名，可和原版共存。签名私钥只保存在维护者本地，源码和发布包不含私钥。无需使用原作者 Firebase 工程，本构建不包含 Firebase 遥测依赖。移动端首次使用 VPN 需要系统授权。


Android VPN 与内核按钮同步开启/关闭，不再占据单独卡片。仪表盘编辑时直接拖动卡片换位，监控卡片下边缘可调整高度并保存。两端仪表盘代理卡片隐藏 Timeout 节点，未测试节点仍显示，整组重新测试成功后恢复显示。
