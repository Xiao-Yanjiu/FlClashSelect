import 'dart:async';
import 'package:tray/tray.dart';
import 'dart:io';
import 'dart:convert';
import 'package:fl_clash/common/themed_tray_popup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'click ID stays valid across repeated refreshes and uses latest callback',
    () {
      final actions = TrayPopupActions();
      var called = 0;
      final id = actions.register('rule', () => called = 1);
      for (var i = 0; i < 100; i++) {
        expect(actions.register('rule', () => called = 2), id);
        actions.register('global', () => called = 3);
      }
      actions.dispatch('$id');
      expect(called, 2);
      actions.clear();
      actions.dispatch('$id');
      expect(called, 2);
    },
  );
  test(
    'native button click reaches Dart callback after state refresh',
    () async {
      final actions = TrayPopupActions();
      var selected = 'global';
      final id = actions.register('rule', () => selected = 'rule');
      final temp = Directory.systemTemp.createTempSync('tray-click-test');
      final helper = Platform.environment['SELECT_TRAY_HELPER']!;
      Map<String, Object> spec(bool selected) => {
        'background': '#191919',
        'surface': '#303030',
        'border': '#606060',
        'foreground': '#eeeeee',
        'accent': '#405070',
        'onAccent': '#ffffff',
        'rows': [
          [
            {
              'id': id,
              'label': 'rule',
              'detail': '',
              'enabled': true,
              'selected': selected,
              'close': false,
            },
          ],
        ],
      };
      final process = await Process.start(helper, [
        '--render-updated',
        '${temp.path}/updated.png',
      ]);
      process.stdin.writeln(jsonEncode(spec(false)));
      for (var i = 0; i < 100; i++) {
        actions.register('rule', () => selected = 'rule');
      }
      process.stdin.writeln(jsonEncode(spec(true)));
      await process.stdin.close();
      final output = await process.stdout.transform(utf8.decoder).join();
      final errors = await process.stderr.transform(utf8.decoder).join();
      expect(await process.exitCode, 0, reason: errors);
      for (final line in const LineSplitter().convert(output)) {
        actions.dispatch(line);
      }
      expect(selected, 'rule');
      expect(File('${temp.path}/updated.png').existsSync(), isTrue);
      temp.deleteSync(recursive: true);
    },
    skip:
        !Platform.isWindows ||
        Platform.environment['SELECT_TRAY_HELPER'] == null,
  );
  test(
    'same open popup receives changed state through production update method',
    () async {
      final messages = StreamController<String>();
      final history = <String>[];
      final reader = StreamIterator(messages.stream);
      final popup = ThemedTrayPopup.forTest(
        executable: Platform.environment['SELECT_TRAY_HELPER']!,
        palette: {
          'background': '#191919',
          'surface': '#303030',
          'border': '#606060',
          'foreground': '#eeeeee',
          'accent': '#405070',
          'onAccent': '#ffffff',
        },
        onMessage: (line) {
          history.add(line);
          if (line != 'SENT' && line != 'RECEIVED' && !messages.isClosed)
            messages.add(line);
        },
      );
      try {
        expect(
          await popup.open([
            TrayMenuCheckbox(label: 'rule', checked: false, onSelected: () {}),
          ], false),
          isTrue,
        );
        expect(
          await reader.moveNext().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw StateError('timed out: $history'),
          ),
          isTrue,
        );
        expect(reader.current, 'READY');
        popup.update([
          TrayMenuCheckbox(label: 'rule', checked: true, onSelected: () {}),
        ], false);
        expect(
          await reader.moveNext().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw StateError('timed out: $history'),
          ),
          isTrue,
        );
        expect(reader.current, 'STATE:Selected');
        popup.update([
          TrayMenuCheckbox(label: 'rule', checked: false, onSelected: () {}),
        ], false);
        expect(
          await reader.moveNext().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw StateError('timed out: $history'),
          ),
          isTrue,
        );
        expect(reader.current, 'STATE:');
        expect(popup.isOpen, isTrue);
      } finally {
        popup.close();
        await reader.cancel();
        await messages.close();
      }
    },
    skip:
        !Platform.isWindows ||
        Platform.environment['SELECT_TRAY_HELPER'] == null,
  );
}
