import 'package:fl_clash/select/select_traffic.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> snapshot(
  DateTime time,
  int up,
  int down, {
  String id = 'one',
}) => {
  'updated': time.toIso8601String(),
  'flows': [
    {
      'id': id,
      'process': 'msedge.exe',
      'domain': 'github.com',
      'ip': '20.205.243.166',
      'port': 443,
      'pid': 123,
      'protocol': 'TCP',
      'upload': up,
      'download': down,
      'ageMs': 0,
    },
  ],
};

void main() {
  test('rates use measured snapshot intervals and retain per-flow totals', () {
    final meter = SelectTrafficMeter();
    final time = DateTime.utc(2026, 10, 13);
    expect(
      meter.update(snapshot(time, 100, 1000), time).single.downloadRate,
      0,
    );
    final next = time.add(const Duration(milliseconds: 500));
    final row = meter.update(snapshot(next, 200, 3000), next).single;
    expect(row.uploadRate, 200);
    expect(row.downloadRate, 4000);
    expect(row.download, 3000);
    expect(row.process, 'msedge.exe');
    expect(row.domain, 'github.com');
    expect(
      meter.update(snapshot(next, 200, 3000), next).single.downloadRate,
      4000,
    );
  });
  test(
    'stopped snapshots and reused flow identifiers never show old traffic',
    () {
      final meter = SelectTrafficMeter();
      final time = DateTime.utc(2026, 10, 13);
      meter.update(snapshot(time, 100, 1000), time);
      final next = time.add(const Duration(seconds: 1));
      expect(
        meter
            .update(snapshot(next, 0, 0, id: 'new-session'), next)
            .single
            .downloadRate,
        0,
      );
      expect(
        meter.update(
          snapshot(next, 0, 0),
          next.add(const Duration(seconds: 4)),
        ),
        isEmpty,
      );
      expect(meter.update({'flows': []}, next), isEmpty);
    },
  );
}
