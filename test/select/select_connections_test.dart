import 'dart:convert';

import 'package:fl_clash/select/select_connections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'structured DNS observation shows process, destination and forwarding',
    () {
      final record = SelectConnection.parse(
        jsonEncode({
          'time': '2026-10-13T01:41:39Z',
          'kind': 'connection',
          'process': 'msedge.exe',
          'pid': 123,
          'domain': 'github.com',
          'ip': '20.205.243.166',
          'port': 443,
          'action': 'proxy',
          'protocol': 'TCP',
        }),
      )!;
      expect(record.domain, 'github.com');
      expect(record.proxied, isTrue);
      expect(record.matches('GitHub'), isTrue);
      expect(record.matches('msedge.exe'), isTrue);
      expect(record.matches('20.205'), isTrue);
    },
  );

  test('actual old Edge log remains visible without inventing its domain', () {
    final record = SelectConnection.parse(
      jsonEncode({
        'time': '2026-10-13T01:41:39.4269403Z',
        'kind': 'connection',
        'message':
            'msedge.exe [29512] 20.205.243.166:443 Proxy SOCKS5://127.0.0.1:17891',
      }),
    )!;
    expect(record.proxied, isTrue);
    expect(record.domain, isEmpty);
    expect(record.pid, 29512);
    expect(record.endpoint, '20.205.243.166:443');
  });

  test('IPv6 is displayed unambiguously and noise is excluded', () {
    final record = SelectConnection.parse(
      jsonEncode({
        'time': '2026-10-13T01:41:39Z',
        'kind': 'connection',
        'message': 'msedge.exe [123] 2001:db8::1:443 Direct (UDP)',
      }),
    )!;
    expect(record.endpoint, '[2001:db8::1]:443');
    expect(record.proxied, isFalse);
    expect(record.protocol, 'UDP');
    expect(
      SelectConnection.parse('{"kind":"engine","message":"UDP warning"}'),
      isNull,
    );
    expect(SelectConnection.parse('{partial'), isNull);
  });
}
