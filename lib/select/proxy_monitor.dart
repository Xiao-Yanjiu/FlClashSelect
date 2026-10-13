import 'package:fl_clash/models/models.dart';

Map<String, dynamic> proxyMonitorSnapshot(
  List<TrackerInfo> connections,
  DateTime now,
  String unknownProcess,
) => {
  'updated': now.toUtc().toIso8601String(),
  'flows': [
    for (final connection in connections)
      if (connection.chains.isNotEmpty &&
          !const {
            'DIRECT',
            'REJECT',
            'REJECT-DROP',
            'PASS',
          }.contains(connection.chains.first.toUpperCase()))
        {
          'id': connection.id,
          'process': connection.metadata.process.isNotEmpty
              ? connection.metadata.process
              : unknownProcess,
          'domain': connection.metadata.host,
          'ip': connection.metadata.destinationIP,
          'protocol': connection.metadata.network,
          'rule': '${connection.rule} / ${connection.chains.first}',
          'pid': connection.metadata.uid,
          'port': int.tryParse(connection.metadata.destinationPort) ?? 0,
          'upload': connection.upload,
          'download': connection.download,
          'ageMs': now
              .difference(connection.start)
              .inMilliseconds
              .clamp(0, 1 << 31),
        },
  ],
};
