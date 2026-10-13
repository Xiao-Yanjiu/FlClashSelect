import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/select/proxy_monitor.dart';
import 'package:fl_clash/select/select_traffic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'monitors proxied flows and preserves authoritative totals and metadata',
    () {
      final now = DateTime.utc(2026, 10, 13);
      TrackerInfo connection(String node) => TrackerInfo(
        id: node,
        start: now.subtract(const Duration(seconds: 2)),
        metadata: const Metadata(
          process: 'com.android.chrome',
          host: 'github.com',
          destinationIP: '1.2.3.4',
          destinationPort: '443',
          network: 'tcp',
          uid: 123,
        ),
        chains: [node, 'GLOBAL'],
        rule: 'DomainSuffix',
        rulePayload: 'github.com',
        upload: 100,
        download: 200,
      );
      final snapshot = proxyMonitorSnapshot(
        [connection('Node'), connection('DIRECT'), connection('REJECT')],
        now,
        'Unknown',
      );
      final rows = SelectTrafficMeter().update(snapshot, now);
      expect(rows, hasLength(1));
      expect(rows.single.process, 'com.android.chrome');
      expect(rows.single.domain, 'github.com');
      expect(rows.single.rule, 'DomainSuffix / Node');
      expect(rows.single.download, 200);
    },
  );
  test('unresolved apps and domains remain unknown or raw IP', () {
    final now = DateTime.utc(2026, 10, 13);
    final row = TrackerInfo(
      id: 'a',
      start: now,
      metadata: const Metadata(destinationIP: '1.2.3.4'),
      chains: ['Node'],
      rule: 'Match',
      rulePayload: '',
    );
    final data = proxyMonitorSnapshot([row], now, 'Unknown');
    final flow = SelectTrafficMeter().update(data, now).single;
    expect(flow.process, 'Unknown');
    expect(flow.domain, isEmpty);
    expect(flow.ip, '1.2.3.4');
  });
}
