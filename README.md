# FlClash Select

基于 [chen08209/FlClash](https://github.com/chen08209/FlClash) 修改的 Windows 选择性代理客户端。保留原作者署名和开源许可；这是独立衍生项目，由 Xiao-Yanjiu 维护。

## 下载

[v0.17.0 测试版源码与 Windows x64 免安装包](https://github.com/Xiao-Yanjiu/FlClashSelect/releases/tag/v0.17.0)

下载 `FlClashSelect-0.17-windows-portable.zip`，解压整个目录后运行 `FlClashSelect.exe`。更新前备份 `select-data`，退出旧版本后启动新版本。发布包不包含订阅、节点账号或个人设置。首次默认窗口为 **1400×720**。

## 功能

- 继承 FlClash 的订阅、节点选择、规则/全局/直连、系统代理和 TUN 功能。
- Windows 选择性代理：按程序或域名匹配，与当前内核、出站模式和选中节点共享出口；可保持系统代理与 TUN 关闭。
- 仪表盘显示程序、目标域名、命中规则和流量统计，支持合并列、拖动卡片和紧凑节点选择。
- 节点延迟及下载测速；托盘提供主题按钮和实时状态。
- 托盘颜色优先级：**TUN 正红 > 系统代理橘红 > 内核/选择性代理蓝 > 全部关闭灰**。

## 使用与限制

阅读 [使用说明及注意事项](USAGE.md)、[构建说明](BUILDING.md) 和 [本版本验证记录](VERIFICATION.md)。当前发布为 Windows x64 测试版，继承的其他平台源码不代表新增选择性代理功能已支持这些平台。

域名匹配依赖观测到的普通 DNS；加密 DNS、DNS 缓存、共享 IP 和浏览器连接复用可能影响匹配和域名显示。选择性代理通常需要管理员权限；首次修改规则后建议重新建立目标应用连接。

## 许可与致谢

本衍生项目沿用 **GNU GPL v3**，全文见 [LICENSE](LICENSE)。保留 FlClash、Clash.Meta/mihomo、ProxyBridge、WinDivert 以及其他组件的原作者和许可证；第三方文件按各自许可分发，详见 [第三方声明](THIRD_PARTY_NOTICES.md)。程序按许可证原文提供，不作额外保证。

重新分发修改版时，应保留原有署名与许可证，并按照适用许可提供对应源码。原项目介绍保留在 [UPSTREAM_README.md](UPSTREAM_README.md) 和 [UPSTREAM_README_zh_CN.md](UPSTREAM_README_zh_CN.md)。

## 源码结构

`lib/select/` 为选择性代理逻辑；`plugins/select_engine/` 包含拦截引擎、托盘/转发辅助程序和驱动对应源码；`core/cmd/select-speed/` 为测速程序。`core/Clash.Meta/` 在本仓库直接包含源码快照，固定来源版本见 [UPSTREAM.md](UPSTREAM.md)。

问题请提交到 [本仓库 Issues](https://github.com/Xiao-Yanjiu/FlClashSelect/issues)，附版本、Windows 版本、复现步骤和已脱敏的日志。


免安装包内目录为 `FlClashSelect-v0.17`。首次启动默认关闭“自启动”“静默启动”“自动运行”，窗口正常显示，请先添加订阅或配置。升级并保留旧 `select-data` 时会保留用户之前的设置；可在“工具 → 常规设置 → 启动与后台”手动关闭这三项。
