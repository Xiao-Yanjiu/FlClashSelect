import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/dashboard/widgets/select_proxy_card.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

Group _group(String name, List<String> proxies) => Group(
  type: GroupType.Selector,
  name: name,
  hidden: false,
  all: [for (final proxy in proxies) Proxy(name: proxy, type: 'ss')],
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.listen(groupsProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  Future<void> pumpCard(WidgetTester tester, {double unitHeight = 80}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 448,
                child: DashboardWidgetMetrics(
                  unitHeight: unitHeight,
                  child: const SelectProxyCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('compact nodes and search share a single header row', (
    tester,
  ) async {
    container.read(groupsProvider.notifier).value = [
      _group('Proxy', ['Alpha', 'Beta', 'Gamma', 'Delta', 'REJECT', 'Auto']),
      _group('Auto', []),
    ];
    await pumpCard(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ProxyCard), findsNWidgets(4));
    for (final widget in tester.widgetList<ProxyCard>(find.byType(ProxyCard))) {
      expect(widget.type, ProxyCardType.min);
    }
    final cards = find.byType(ProxyCard);
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    final third = tester.getRect(cards.at(2));
    final fourth = tester.getRect(cards.at(3));
    expect(first.top, second.top);
    expect(third.top, fourth.top);
    expect(third.top, greaterThan(first.bottom));
    expect(
      fourth.bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(GridView)).bottom + 0.01),
    );
    expect(
      tester.widgetList<ProxyCard>(cards).map((card) => card.proxy.name),
      isNot(contains('REJECT')),
    );
    expect(
      tester.widgetList<ProxyCard>(cards).map((card) => card.proxy.name),
      isNot(contains('Auto')),
    );
    final group = tester.getCenter(find.byType(DropdownButton<String>));
    final search = tester.getCenter(find.byType(TextField));
    expect(group.dy, closeTo(search.dy, 1));
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pumpAndSettle();
    expect(find.byType(ProxyCard), findsOneWidget);
    expect(
      tester.widget<ProxyCard>(find.byType(ProxyCard)).proxy.name,
      'Alpha',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('timeout nodes hide and return after a successful retest', (
    tester,
  ) async {
    container.read(groupsProvider.notifier).value = [
      _group('Proxy', ['Good', 'Failed', 'Untested']),
    ];
    final url = container.read(realTestUrlProvider(null));
    container.read(delayDataSourceProvider.notifier).setDelays([
      Delay(url: url, name: 'Good', value: 80),
      Delay(url: url, name: 'Failed', value: -1),
    ]);
    await pumpCard(tester);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ProxyCard>(find.byType(ProxyCard))
          .map((card) => card.proxy.name),
      ['Good', 'Untested'],
    );
    container
        .read(delayDataSourceProvider.notifier)
        .setDelay(Delay(url: url, name: 'Failed', value: 40));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ProxyCard>(find.byType(ProxyCard))
          .map((card) => card.proxy.name),
      ['Failed', 'Good', 'Untested'],
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
