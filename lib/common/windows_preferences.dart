import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences_platform_interface/types.dart';

import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class WindowsPreferences extends SharedPreferencesStorePlatform {
  WindowsPreferences(this.file);

  static Future<WindowsPreferences> open(
    File file, {
    required bool migrateExistingInstallation,
    required SharedPreferencesStorePlatform legacy,
  }) async {
    final store = WindowsPreferences(file);
    if (!migrateExistingInstallation || await file.exists()) return store;
    final values = await legacy.getAll();
    final raw = values['flutter.config'];
    if (raw is! String) return store;
    final config = jsonDecode(raw) as Map<String, dynamic>;
    final settings = Map<String, dynamic>.from(
      config['appSettingProps'] as Map<String, dynamic>? ?? {},
    );
    settings.addAll({
      'autoLaunch': false,
      'silentLaunch': false,
      'autoRun': false,
    });
    config['appSettingProps'] = settings;
    await store.setValue('String', 'flutter.config', jsonEncode(config));
    final version = values['flutter.version'];
    if (version is int) await store.setValue('Int', 'flutter.version', version);
    return store;
  }

  final File file;
  Future<void> _pending = Future<void>.value();

  Future<Map<String, Object>> _read() async {
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid portable preferences');
    }
    return Map<String, Object>.from(decoded);
  }

  Future<bool> _write(void Function(Map<String, Object>) change) {
    final result = _pending.then((_) async {
      final values = await _read();
      change(values);
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp-$pid');
      await temporary.writeAsString(jsonEncode(values), flush: true);
      await temporary.rename(file.path);
      return true;
    });
    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    await _pending;
    return _read();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      _write((values) => values[key] = value);

  @override
  Future<bool> remove(String key) => _write((values) => values.remove(key));

  @override
  Future<bool> clear() => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: 'flutter.')),
  );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) => _write(
    (values) =>
        values.removeWhere((key, _) => _matches(key, parameters.filter)),
  );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final values = await getAll();
    values.removeWhere((key, _) => !_matches(key, parameters.filter));
    return values;
  }

  bool _matches(String key, PreferencesFilter filter) =>
      key.startsWith(filter.prefix) &&
      (filter.allowList == null || filter.allowList!.contains(key));
}
