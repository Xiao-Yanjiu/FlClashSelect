import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('portable data and cache stay beside the executable', () async {
    if (!Platform.isWindows ||
        !const bool.fromEnvironment('SELECT_PORTABLE', defaultValue: true)) {
      return;
    }
    final expected = join(
      dirname(Platform.resolvedExecutable),
      safeModeBuild ? 'select-test-data' : 'select-data',
    );
    AppPath.temporaryDirectory = () async => Directory.systemTemp;
    expect(await appPath.homeDirPath, expected);
    expect((await appPath.cacheDir.future).path, join(expected, 'cache'));
    expect(
      await appPath.sharedPreferencesPath,
      join(expected, 'shared_preferences.json'),
    );
    expect(await Directory(expected).exists(), isTrue);
  });
}
