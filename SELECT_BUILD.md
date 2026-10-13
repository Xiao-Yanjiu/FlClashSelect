# FlClash Select 0.17

Based on FlClash v0.8.99, commit 68c71b8ef9b7486a224972eb371ff153c6b2de0f.
Mihomo submodule: 8597778c7df410ebe88c57e59eaab32d203156df.
Original chen08209 authorship and GPL-3.0 notices remain.

Dart UI/assets compiled with Flutter 3.47.4 / Dart 3.13.3. Matching upstream
Windows runner, plugins, Rust DLL and original Go core/helper are reused.
Official bundle SHA256: 9ff3a9315b51e6665669bfde9b0323ddb671a22d0a9647987b4cc5e574007f4f.
Original native components were not rebuilt. New packet engine/relay and
FlClashSelectSpeed.exe and FlClashSelectTray.exe ARE compiled from included source.

Selective rules intercept matched programs/domains and send to loopback mixed
listener 17891, sharing dashboard mode and routing. Unmatched packets bypass.
The compact telemetry view uses the existing DashboardWidget registry/grid.
App settings have a one-time migration marker so removed cards stay removed.
Native rules use thread-local match identifiers to copy matched rule labels into
flow snapshots; the fixture checks rule identity alongside byte attribution.
The telemetry extension counts intercepted TCP/UDP payload per original process
and destination, emitting bounded fresh snapshots. It does not infer app traffic
from global core totals. Native snapshot/protocol boundaries are locally tested;
live privileged capture with the new binary remains unverified by the agent.
The standalone speed worker parses the applied config and pins the selected
adapter without applying OS/network settings. TLS verification stays enabled,
and adapter failures never fall back to direct connectivity.

Canonical pubspec retains native hooks. Build-only copy disables setup/rust_api
hooks to reuse matching original components. Build commands:

    flutter pub get
    flutter assemble --output=<assets> -dTargetPlatform=windows-x64 -dBuildMode=release release_bundle_windows-x64_assets
    # safe launch: add -dDartDefines=U0FGRV9NT0RFPXRydWU=
    # Generate Windows system-proxy/TUN SVG variants with public resvg 0.45.1:
    python tool/generate_select_tray_icons.py --resvg <path-to-resvg.exe>
    # from core/: Go 1.26.4, CGO_ENABLED=0
    go build -trimpath -ldflags '-H windowsgui -s -w' -o <bundle>/select-engine/FlClashSelectSpeed.exe ./cmd/select-speed

Stage windows/app.so as data/app.so, flutter_assets under data/, native asset
DLLs beside the runner, compiled helpers in select-engine/. Rename runner to
FlClashSelect.exe. Connections are stored separately in connections.jsonl with observed DNS
domain, original process/PID, destination IP/port and actual engine routing decision.
No reverse DNS guesses are made. Autostart is opt-in and follows the existing
core readiness signals through an observer; it does not own the core process.
Portable data: select-data; safe data: select-test-data.
Packet source, WinDivert corresponding source and licenses: plugins/select_engine/.
