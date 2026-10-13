import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:fl_clash/common/windows_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SharedPreferences API persists and reloads independent portable settings',
    () async {
      final folder = await Directory.systemTemp.createTemp('select-api-');
      final previous = SharedPreferencesStorePlatform.instance;
      try {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = WindowsPreferences(
          File('${folder.path}/settings.json'),
        );
        final settings = await SharedPreferences.getInstance();
        await settings.setStringList('nodes', ['last-node']);
        await settings.setBool('autoRun', false);
        await settings.reload();
        expect(settings.getStringList('nodes'), ['last-node']);
        expect(settings.getBool('autoRun'), false);
        await settings.clear();
        expect(settings.getKeys(), isEmpty);
      } finally {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = previous;
        await folder.delete(recursive: true);
      }
    },
  );
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('select-prefs-'),
  );
  tearDown(() async => directory.delete(recursive: true));
  test(
    'fresh portable settings ignore a neighbouring existing installation',
    () async {
      final old = WindowsPreferences(
        File('${directory.path}/old/shared_preferences.json'),
      );
      await old.setValue('Bool', 'flutter.autoRun', true);
      final fresh = WindowsPreferences(
        File('${directory.path}/new/shared_preferences.json'),
      );
      expect(await fresh.getAll(), isEmpty);
      expect((await old.getAll())['flutter.autoRun'], true);
    },
  );
  test(
    'serial writes persist settings for a later launch without losing keys',
    () async {
      final file = File(
        '${directory.path}/select-data/shared_preferences.json',
      );
      final store = WindowsPreferences(file);
      await Future.wait([
        store.setValue('String', 'flutter.config', 'last-node'),
        store.setValue('Bool', 'flutter.autoRun', false),
      ]);
      final reopened = WindowsPreferences(file);
      expect(await reopened.getAll(), {
        'flutter.config': 'last-node',
        'flutter.autoRun': false,
      });
      await reopened.remove('flutter.config');
      expect(await reopened.getAll(), {'flutter.autoRun': false});
      await reopened.clear();
      expect(await reopened.getAll(), isEmpty);
    },
  );
  test(
    'existing installation keeps its selected node with startup flags disabled',
    () async {
      final legacy = InMemorySharedPreferencesStore.withData({
        'flutter.config': jsonEncode({
          'selectedMap': {'GLOBAL': 'saved-node'},
          'appSettingProps': {
            'autoRun': true,
            'silentLaunch': true,
            'autoLaunch': true,
          },
        }),
      });
      final store = await WindowsPreferences.open(
        File('${directory.path}/migrated.json'),
        migrateExistingInstallation: true,
        legacy: legacy,
      );
      final config = jsonDecode(
        (await store.getAll())['flutter.config'] as String,
      );
      expect(config['selectedMap'], {'GLOBAL': 'saved-node'});
      expect(config['appSettingProps'], {
        'autoRun': false,
        'silentLaunch': false,
        'autoLaunch': false,
      });
      final fresh = await WindowsPreferences.open(
        File('${directory.path}/fresh.json'),
        migrateExistingInstallation: false,
        legacy: legacy,
      );
      expect(await fresh.getAll(), isEmpty);
    },
  );
  test('damaged settings are reported and never silently replaced', () async {
    final file = File('${directory.path}/shared_preferences.json');
    await file.writeAsString('broken');
    final store = WindowsPreferences(file);
    await expectLater(store.getAll(), throwsFormatException);
    await expectLater(
      store.setValue('Bool', 'flutter.autoRun', true),
      throwsFormatException,
    );
    expect(await file.readAsString(), 'broken');
  });
}
