class SelectTraffic {
  final String id, process, domain, ip, protocol, rule;
  final int pid, port, upload, download, ageMs;
  final double uploadRate, downloadRate;
  const SelectTraffic({
    this.rule = '',
    required this.id,
    required this.process,
    required this.domain,
    required this.ip,
    required this.protocol,
    required this.pid,
    required this.port,
    required this.upload,
    required this.download,
    required this.ageMs,
    this.uploadRate = 0,
    this.downloadRate = 0,
  });
  factory SelectTraffic.fromJson(Map<String, dynamic> value) => SelectTraffic(
    rule: value['rule'] as String? ?? '',
    id: value['id'] as String,
    process: value['process'] as String,
    domain: value['domain'] as String,
    ip: value['ip'] as String,
    protocol: value['protocol'] as String,
    pid: value['pid'] as int,
    port: value['port'] as int,
    upload: value['upload'] as int,
    download: value['download'] as int,
    ageMs: value['ageMs'] as int,
  );
  SelectTraffic withRates(double up, double down) => SelectTraffic(
    rule: rule,
    id: id,
    process: process,
    domain: domain,
    ip: ip,
    protocol: protocol,
    pid: pid,
    port: port,
    upload: upload,
    download: download,
    ageMs: ageMs,
    uploadRate: up,
    downloadRate: down,
  );
}

class SelectTrafficMeter {
  DateTime? _previousTime;
  Map<String, SelectTraffic> _previous = {};
  List<SelectTraffic> _current = [];
  List<SelectTraffic> update(Map<String, dynamic> snapshot, DateTime now) {
    final time = DateTime.tryParse('${snapshot['updated']}');
    if (time == null || now.toUtc().difference(time).inSeconds > 3) {
      _previousTime = null;
      _previous = {};
      _current = [];
      return [];
    }
    if (time == _previousTime) return _current;
    final seconds = _previousTime == null
        ? 0.0
        : time.difference(_previousTime!).inMicroseconds / 1000000;
    final rows = (snapshot['flows'] as List)
        .map((value) => SelectTraffic.fromJson(value as Map<String, dynamic>))
        .toList();
    _current =
        rows.map((row) {
          final previous = _previous[row.id];
          if (previous == null || seconds <= 0) return row;
          final up = row.upload - previous.upload;
          final down = row.download - previous.download;
          return row.withRates(
            up < 0 ? 0 : up / seconds,
            down < 0 ? 0 : down / seconds,
          );
        }).toList()..sort(
          (a, b) => (b.uploadRate + b.downloadRate).compareTo(
            a.uploadRate + a.downloadRate,
          ),
        );
    _previous = {for (final row in rows) row.id: row};
    _previousTime = time;
    return _current;
  }
}
