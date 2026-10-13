import 'dart:async';

import 'package:fl_clash/select/select_autostart.dart';
import 'package:fl_clash/select/select_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old settings keep autostart off; new settings round trip', () {
    expect(
      SelectProfile.decodeSettings(
        '{"host":"127.0.0.1","port":17891,"rules":[]}',
      ).autoStart,
      isFalse,
    );
    const profile = SelectProfile(autoStart: true, rules: []);
    expect(
      SelectProfile.decodeSettings(profile.encodeSettings()).autoStart,
      isTrue,
    );
  });

  test(
    'starts on readiness, pauses manually and restarts on next core run',
    () async {
      var starts = 0;
      var stops = 0;
      final owner = SelectAutostart(
        load: () async => const SelectProfile(autoStart: true, rules: []),
        start: (_) async => starts++,
        stop: () async => stops++,
        onError: (_) => fail('unexpected error'),
      );
      await owner.coreReady(true);
      await owner.coreReady(true);
      expect(starts, 1);
      owner.pause();
      await owner.refresh();
      expect(starts, 1);
      await owner.coreReady(false);
      expect(stops, 1);
      await owner.coreReady(true);
      expect(starts, 2);
      owner.close();
    },
  );

  test(
    'late start stops when core goes away; no concurrent second launch',
    () async {
      final entered = Completer<void>();
      final started = Completer<void>();
      var starts = 0;
      var stops = 0;
      final owner = SelectAutostart(
        load: () async => const SelectProfile(autoStart: true, rules: []),
        start: (_) async {
          starts++;
          entered.complete();
          await started.future;
        },
        stop: () async => stops++,
        onError: (_) => fail('unexpected error'),
      );
      final initial = owner.coreReady(true);
      await entered.future;
      final next = owner.coreReady(false);
      started.complete();
      await initial;
      await next;
      expect(starts, 1);
      expect(stops, greaterThanOrEqualTo(1));
      owner.close();
    },
  );

  test(
    'failed admin start is reported without repeated automatic prompts',
    () async {
      var calls = 0;
      final errors = <Object>[];
      final owner = SelectAutostart(
        load: () async => const SelectProfile(autoStart: true, rules: []),
        start: (_) async {
          calls++;
          throw StateError('admin cancelled');
        },
        stop: () async {},
        onError: errors.add,
      );
      await owner.coreReady(true);
      await owner.coreReady(true);
      expect(calls, 1);
      expect(errors.single.toString(), contains('admin cancelled'));
      owner.close();
    },
  );

  test('closing before settings load completes prevents launch', () async {
    final loading = Completer<SelectProfile>();
    var starts = 0;
    final owner = SelectAutostart(
      load: () => loading.future,
      start: (_) async => starts++,
      stop: () async {},
      onError: (_) => fail('unexpected error'),
    );
    final pending = owner.coreReady(true);
    await Future<void>.delayed(Duration.zero);
    owner.close();
    loading.complete(const SelectProfile(autoStart: true, rules: []));
    await pending;
    expect(starts, 0);
  });
}
