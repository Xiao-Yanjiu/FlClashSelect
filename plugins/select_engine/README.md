# FlClash Select Windows packet engine

The proxy engine is built from InterceptSuite/ProxyBridge v4.1.0,
commit c9646aaa5991aecb2559141a4f944b82513d2e30 (MIT).
https://github.com/InterceptSuite/ProxyBridge/tree/v4.1.0
The sole portability patch changes static __forceinline to static inline
in pb_internal.h for Clang/MinGW. Engine source is under proxybridge/.

WinDivert 2.2.2 signed x64 driver and DLL are from the official binary ZIP:
https://github.com/basil00/WinDivert/releases/tag/v2.2.2
Corresponding source is under windivert-source/; its licenses are retained.
No service or scheduled task is installed by SelectRelay. WinDivert manages
its kernel driver when opened; starting capture requires administrator rights.

The helper watches the owning FlClash process and the private core listener.
It closes capture when its parent exits, when disabled or when the core stops.
Live rule updates replace rules without resetting observed DNS. Existing connections can be disrupted
when changing rules; new application connections should be used to test matches.
DNS-domain matching uses ordinary DNS observations and cannot reliably match
encrypted DNS or names already cached before engine startup.

Build: Zig 0.13.0 cc, x86_64-windows-gnu target, all proxybridge/*.c sources,
PROXYBRIDGE_EXPORTS, -O2 -shared, link the official WinDivert.lib plus
ws2_32, iphlpapi and advapi32. Compile SelectRelay.cs with Framework64 csc,
/target:winexe /platform:x64 /r:System.Web.Extensions.dll.
Run FlClashSelectRelay.exe --self-test to validate exports without starting capture.

Select 0.4 adds ProxyBridge_GetObservedDomain, which reads observed DNS cache
without reverse DNS queries. Structured connection rows are written separately
to connections.jsonl; diagnostic events remain in events.jsonl. Domain mappings
are observations and may be ambiguous on shared IPs. The native fixture in
tests/domain_observation_test.c verifies IPv4, IPv6 and unknown addresses
without starting packet capture. Starting with the core is opt-in, persisted
in rules.json; ordinary launches still require Windows administrator approval.

Select 0.5 adds pb_select_stats.c: bounded, original-process/endpoint counters
for intercepted TCP/UDP payload in each direction. Snapshots refresh at 500ms;
GUI rates use snapshot timestamps. Counts include encrypted payload/retransmits,
exclude IP/TCP headers and are independent of core global totals. The native
fixture exercises packet parsing attribution without starting WinDivert capture.
The speed worker now excludes warmup and uses a sustained sample, with a
256 MiB transfer cap and a minimum useful sample duration.

Select 0.6 adds per-thread rule match identifiers and records the native matched
rule label in each flow snapshot. Callback ABI now includes the rule string;
relay and DLL must be upgraded together. The fixture checks rule identity along
with destination and packet byte attribution. Compile with C11 TLS support.
