import 'dart:convert';

class SelectConnection {
  final DateTime time;
  final String process;
  final int pid;
  final String domain;
  final String ip;
  final int port;
  final bool proxied;
  final String protocol;

  const SelectConnection({
    required this.time,
    required this.process,
    required this.pid,
    required this.domain,
    required this.ip,
    required this.port,
    required this.proxied,
    required this.protocol,
  });

  String get endpoint => ip.contains(':') ? '[$ip]:$port' : '$ip:$port';

  bool matches(String query) => '$process $pid $domain $ip $port $protocol'
      .toLowerCase()
      .contains(query.trim().toLowerCase());

  static SelectConnection? parse(String line) {
    try {
      final value = jsonDecode(line) as Map<String, dynamic>;
      if (value['kind'] != 'connection') return null;
      final time = DateTime.parse(value['time'] as String).toLocal();
      if (value['process'] is String) {
        return SelectConnection(
          time: time,
          process: value['process'] as String,
          pid: value['pid'] as int,
          domain: value['domain'] as String? ?? '',
          ip: value['ip'] as String,
          port: value['port'] as int,
          proxied: value['action'] == 'proxy',
          protocol: value['protocol'] as String? ?? 'TCP',
        );
      }
      final match = RegExp(
        r'^(.*?) \[(\d+)\] (.+):(\d+) (.*)$',
      ).firstMatch(value['message'] as String? ?? '');
      if (match == null) return null;
      return SelectConnection(
        time: time,
        process: match[1]!,
        pid: int.parse(match[2]!),
        domain: '',
        ip: match[3]!,
        port: int.parse(match[4]!),
        proxied: match[5]!.startsWith('Proxy'),
        protocol: match[5]!.contains('(UDP)') ? 'UDP' : 'TCP',
      );
    } on Object {
      return null;
    }
  }
}
