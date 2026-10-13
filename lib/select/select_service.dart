import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:path/path.dart' show join;

import 'select_profile.dart';
import 'select_connections.dart';
import 'select_autostart.dart';

class SelectService {
  String? _token;
  int _launchRevision = 0;
  Future<void>? _starting;
  String? autostartError;
  late final autostart = SelectAutostart(
    load: load,
    start: start,
    stop: () => stop(manual: false),
    onError: (error) => autostartError = '$error',
  );

  Future<Directory> get directory async => Directory(
    join(await appPath.homeDirPath, 'selective'),
  ).create(recursive: true);

  Future<File> _file(String name) async =>
      File(join((await directory).path, name));

  Future<void> _write(String name, Object value) async {
    final file = await _file(name);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }

  Future<SelectProfile> load() async {
    final file = await _file('rules.json');
    return await file.exists()
        ? SelectProfile.decodeSettings(await file.readAsString())
        : SelectProfile.defaults();
  }

  Future<void> save(SelectProfile profile) async {
    if (profile.rules.length > 240) {
      throw const FormatException('Too many rules');
    }
    profile.toBridgeProfile();
    await _write('rules.json', jsonDecode(profile.encodeSettings()));
  }

  Future<void> start(SelectProfile profile) =>
      _starting ??= _start(profile).whenComplete(() => _starting = null);

  Future<void> _start(SelectProfile profile) async {
    final revision = ++_launchRevision;
    autostartError = null;
    if (safeModeBuild) throw StateError('Safe mode');
    if ((await status())['state'] == 'running') return;
    await save(profile);
    if (revision != _launchRevision) return;
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    _token =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _write('session.json', {'token': _token, 'enabled': true});
    final helper = join(
      appPath.executableDirPath,
      'select-engine',
      'FlClashSelectRelay.exe',
    );
    if (!await File(helper).exists()) {
      throw FileSystemException('Missing select engine', helper);
    }
    final parameters = [(await directory).path, _token!, '$pid'];
    final administrator = await Process.run(helper, ['--is-admin']);
    if (revision != _launchRevision) return;
    bool started;
    if (administrator.exitCode == 0) {
      await Process.start(helper, parameters, mode: ProcessStartMode.detached);
      started = true;
    } else {
      started =
          windows?.runas(
            helper,
            '"${parameters[0]}" ${parameters[1]} ${parameters[2]}',
          ) ??
          false;
    }
    if (!started) {
      await stop();
      throw StateError('Administrator approval cancelled');
    }
    final watch = Stopwatch()..start();
    while (watch.elapsed < const Duration(seconds: 20)) {
      if (revision != _launchRevision) return;
      final value = await status();
      if (value['token'] == _token) {
        if (value['state'] == 'running') return;
        if (value['state'] == 'failed') throw StateError('${value['error']}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await stop();
    throw TimeoutException('Select engine did not start');
  }

  Future<void> stop({bool manual = true}) async {
    _launchRevision++;
    if (manual) autostart.pause();
    final file = await _file('session.json');
    if (!await file.exists()) return;
    final session =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    session['enabled'] = false;
    await _write('session.json', session);
  }

  Future<Map<String, dynamic>> status() async {
    try {
      final file = await _file('status.json');
      if (!await file.exists()) return {'state': 'stopped'};
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final updated = DateTime.tryParse('${value['updated']}');
      if ((value['state'] == 'running' || value['state'] == 'waiting') &&
          (updated == null ||
              DateTime.now().toUtc().difference(updated) >
                  const Duration(seconds: 4))) {
        return {'state': 'stopped'};
      }
      return value;
    } on FileSystemException {
      return {'state': 'stopped'};
    } on FormatException {
      return {'state': 'stopped'};
    }
  }

  Future<Map<String, dynamic>> traffic() async {
    try {
      if ((await status())['state'] != 'running') return {'flows': []};
      final file = await _file('traffic.json');
      if (!await file.exists()) return {'flows': []};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FileSystemException {
      return {'flows': []};
    } on FormatException {
      return {'flows': []};
    }
  }

  Future<List<SelectConnection>> connections() async {
    try {
      final current = await _file('connections.jsonl');
      final files = await current.exists()
          ? [File('${current.path}.previous'), current]
          : [await _file('events.jsonl.previous'), await _file('events.jsonl')];
      final records = <SelectConnection>[];
      for (final file in files) {
        if (!await file.exists()) continue;
        for (final line in await file.readAsLines()) {
          final record = SelectConnection.parse(line);
          if (record != null) records.add(record);
        }
      }
      return records.reversed.take(2000).toList();
    } on FileSystemException {
      return [];
    }
  }

  Future<List<String>> events() async {
    try {
      final file = await _file('events.jsonl');
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      return lines
          .where((line) => SelectConnection.parse(line) == null)
          .skip(max(0, lines.length - 80))
          .map((line) {
            try {
              final event = jsonDecode(line) as Map<String, dynamic>;
              final time = DateTime.parse('${event['time']}').toLocal();
              return '${time.toIso8601String().substring(11, 19)} ${event['message']}';
            } on FormatException {
              return line;
            }
          })
          .toList()
          .reversed
          .toList();
    } on FileSystemException {
      return [];
    }
  }
}

final selectService = SelectService();
