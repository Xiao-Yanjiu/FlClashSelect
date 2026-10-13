import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/select/select_profile.dart';
import 'package:fl_clash/select/select_connections.dart';
import 'package:fl_clash/select/select_autostart_item.dart';
import 'package:fl_clash/select/select_service.dart';
import 'package:fl_clash/select/select_view.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _Service extends SelectService {
  bool fail = false;
  String phase = 'stopped';
  SelectProfile? saved;
  @override
  Future<SelectProfile> load() async =>
      saved ??
      const SelectProfile(
        rules: [SelectRule(SelectRuleKind.application, 'Discord.exe')],
      );
  @override
  Future<Map<String, dynamic>> status() async => {'state': phase};
  @override
  Future<List<String>> events() async => [
    'Discord.exe [123] github.com:443 PROXY',
  ];
  @override
  Future<List<SelectConnection>> connections() async => [
    SelectConnection(
      time: DateTime(2026, 10, 13, 9),
      process: 'msedge.exe',
      pid: 123,
      domain: 'github.com',
      ip: '20.205.243.166',
      port: 443,
      proxied: true,
      protocol: 'TCP',
    ),
    SelectConnection(
      time: DateTime(2026, 10, 13, 9),
      process: 'msedge.exe',
      pid: 123,
      domain: 'example.com',
      ip: '192.0.2.1',
      port: 443,
      proxied: false,
      protocol: 'TCP',
    ),
  ];
  @override
  Future<void> save(SelectProfile value) async {
    if (fail) throw StateError('save failed');
    saved = value;
  }

  @override
  Future<void> stop({bool manual = true}) async {
    phase = 'stopped';
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Service service, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(child: SelectView(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('single input row autosaves addition and has no exit selector', (
    tester,
  ) async {
    final service = _Service();
    await _mount(tester, service);
    final l = currentAppLocalizations;
    expect(
      find.byType(DropdownButtonFormField<SelectRuleKind>),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text(l.selectSave), findsNothing);
    expect(find.textContaining('msedge.exe → github.com'), findsNothing);
    expect(find.text(l.selectAutoStart), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'git.exe');
    await tester.tap(find.widgetWithText(FilledButton, l.add));
    await tester.pumpAndSettle();
    expect(service.saved?.rules.map((rule) => rule.pattern), [
      'Discord.exe',
      'git.exe',
    ]);
    await tester.scrollUntilVisible(
      find.text('git.exe'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('git.exe'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), null);
  });

  testWidgets(
    'failed addition leaves stored rules unchanged and releases controls',
    (tester) async {
      final service = _Service()..fail = true;
      await _mount(tester, service);
      await tester.enterText(find.byType(TextField).first, 'git.exe');
      await tester.tap(
        find.widgetWithText(FilledButton, currentAppLocalizations.add),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('save failed'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'git.exe'), findsNothing);
      expect(service.saved, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, currentAppLocalizations.add),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), null);
    },
  );

  testWidgets('enabled packet engine can be disabled with the page switch', (
    tester,
  ) async {
    final service = _Service()..phase = 'running';
    await _mount(tester, service);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(service.phase, 'stopped');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), null);
  });

  testWidgets('rule input row fits a narrow desktop window', (tester) async {
    await _mount(tester, _Service(), size: const Size(500, 900));
    expect(tester.takeException(), null);
    final field = tester.getRect(find.byType(TextField).first);
    final type = tester.getRect(
      find.byType(DropdownButtonFormField<SelectRuleKind>),
    );
    final add = tester.getRect(
      find.widgetWithText(FilledButton, currentAppLocalizations.add),
    );
    expect(field.center.dy, closeTo(type.center.dy, 4));
    expect(type.center.dy, closeTo(add.center.dy, 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('connection search and proxy filter exclude diagnostic noise', (
    tester,
  ) async {
    await _mount(tester, _Service());
    await tester.tap(find.text(currentAppLocalizations.selectDiagnostics));
    await tester.pumpAndSettle();
    expect(find.textContaining('msedge.exe → github.com'), findsOneWidget);
    expect(find.textContaining('msedge.exe → example.com'), findsNothing);
    expect(find.textContaining('github.com:443 PROXY'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'not-found.exe');
    await tester.pumpAndSettle();
    expect(
      find.text(currentAppLocalizations.selectNoConnections),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).last, 'example.com');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.textContaining('msedge.exe → example.com'), findsOneWidget);
    expect(find.textContaining('msedge.exe → github.com'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), null);
  });

  testWidgets(
    'startup settings item persists selection and rules page preserves it',
    (tester) async {
      final service = _Service();
      await tester.pumpWidget(
        TestApp(
          child: Scaffold(body: SelectAutoStartItem(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.saved!.autoStart, isTrue);
      await tester.pumpWidget(const SizedBox());
      await _mount(tester, service);
      await tester.enterText(find.byType(TextField).first, 'git.exe');
      await tester.tap(
        find.widgetWithText(FilledButton, currentAppLocalizations.add),
      );
      await tester.pumpAndSettle();
      expect(service.saved!.autoStart, isTrue);
      expect(service.saved!.rules.last.pattern, 'git.exe');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'startup option shares standard row style and sits between auto run and on demand',
    (tester) async {
      await _mount(tester, _Service());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: globalState.container,
          child: const TestApp(child: GeneralView()),
        ),
      );
      await tester.pumpAndSettle();
      final l = currentAppLocalizations;
      final option = find.text(l.selectAutoStart);
      expect(option, findsOneWidget);
      expect(
        tester.getCenter(find.text(l.autoRun)).dy,
        lessThan(tester.getCenter(option).dy),
      );
      expect(
        tester.getCenter(option).dy,
        lessThan(tester.getCenter(find.text(l.onDemand)).dy),
      );
      expect(
        find.ancestor(of: option, matching: find.byType(ListItem)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('selective proxy is a dedicated desktop navigation item', () {
    final items = navigation.getItems(hasProxies: true);
    final item = items.singleWhere(
      (item) => item.label == PageLabel.selectiveProxy,
    );
    expect(item.modes, contains(NavigationItemMode.desktop));
  });
}
