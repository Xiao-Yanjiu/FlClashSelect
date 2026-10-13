import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<IpInfo?> readHostIp(HttpClient client) async {
  client.findProxy = (_) => 'DIRECT';
  client.connectionTimeout = const Duration(seconds: 5);
  for (final source in ipInfoSources.entries.where(
    (entry) => entry.key.startsWith('https:'),
  )) {
    try {
      final request = await client
          .getUrl(Uri.parse(source.key))
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        continue;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
      return source.value(body);
    } on Object {
      continue;
    }
  }
  return null;
}

final directIpReaderProvider = Provider<Future<IpInfo?> Function()>((ref) {
  return () async {
    final client = HttpClient();
    try {
      return await readHostIp(
        client,
      ).timeout(const Duration(seconds: 18), onTimeout: () => null);
    } finally {
      client.close(force: true);
    }
  };
});

final directIpProvider = FutureProvider.autoDispose<IpInfo?>((ref) async {
  ref.watch(routeTrackerProvider.select((state) => state.hostEpoch));
  final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
  if (connected) {
    return parseOutboundIp(
      await lookupOutboundIp(ref.read(coreHandlerProvider), directOutbound),
    );
  }
  return ref.read(directIpReaderProvider)();
});
