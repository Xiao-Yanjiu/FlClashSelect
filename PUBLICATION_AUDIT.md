# 发布内容检查

发布内容不包含个人订阅、运行状态、Git 凭据、缓存或本机配置。私钥标记的三个文件均是上游公开示例/测试数据，已与公开提交的 Git 对象核对一致（仅统一 Windows CRLF/LF 换行）：

- [core/Clash.Meta/docs/config.yaml](https://github.com/chen08209/Clash.Meta/blob/8597778c7df410ebe88c57e59eaab32d203156df/docs/config.yaml)；Git blob `7e51bb88237e4ce26416e282706881a0fef3f847`；SHA256 `911025d23d9aaf8985b8ec0983dd5be27782f2be80b5c69149f0629d38cacee0`。
- [core/Clash.Meta/test/config/example.org-key.pem](https://github.com/chen08209/Clash.Meta/blob/8597778c7df410ebe88c57e59eaab32d203156df/test/config/example.org-key.pem)；Git blob `dbe9a3db3e057589524a3674659398260577a5d0`；SHA256 `3543f1ca0ea8fbae9c1f69c7a721cce5a01720af70192affe1432bc7420ee352`。
- [core/Clash.Meta/transport/openvpn/config_test.go](https://github.com/chen08209/Clash.Meta/blob/8597778c7df410ebe88c57e59eaab32d203156df/transport/openvpn/config_test.go)；Git blob `70314285e6a6596fc53da50e9c4101b794393e99`；SHA256 `c598f1cca08e5da932e09e3713d24ada9939b3cde20eaa57e561966afc01138c`。

上游固定提交：`8597778c7df410ebe88c57e59eaab32d203156df`。这些数据只供测试，不是本机部署证书，也不应在实际服务中使用。
