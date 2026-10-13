import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dashboard/widget_registry.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/dashboard/widgets/select_traffic_card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import '../helpers/test_app.dart';

void main() {
  test('card uses editable registry and is no wider than network speed', () {
    final item = DashboardWidget.selectTraffic.widget;
    expect(item.key, const ValueKey(DashboardWidget.selectTraffic));
    expect(dashboardWidgetOf(item), DashboardWidget.selectTraffic);
    expect(
      item.crossAxisCellCount,
      DashboardWidget.networkSpeed.widget.crossAxisCellCount,
    );
  });
  test('legacy layout receives the card once; removal remains saved', () {
    final props = AppSettingProps.fromJson({
      'dashboardWidgets': ['networkSpeed'],
    });
    expect(props.dashboardWidgets, [
      DashboardWidget.networkSpeed,
      DashboardWidget.selectTraffic,
      DashboardWidget.selectProxyPanel,
      DashboardWidget.trafficSummary,
    ]);
    final removed = props.copyWith(
      dashboardWidgets: [DashboardWidget.networkSpeed],
    );
    expect(AppSettingProps.fromJson(removed.toJson()).dashboardWidgets, [
      DashboardWidget.networkSpeed,
    ]);
  });
  testWidgets(
    'compact card uses one row per process and fits within network card height',
    (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: TestApp(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: DashboardWidgetMetrics(
                  unitHeight: 80,
                  child: SelectTrafficCard(
                    reader: () async => {
                      'updated': DateTime.now().toUtc().toIso8601String(),
                      'flows': [
                        {
                          'id': 'a',
                          'process': 'msedge.exe',
                          'domain': 'github.com',
                          'rule': '*.github.com',
                          'ip': '20.205.243.166',
                          'port': 443,
                          'pid': 123,
                          'protocol': 'TCP',
                          'upload': 2048,
                          'download': 1048576,
                          'ageMs': 1,
                        },
                      ],
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('msedge.exe'), findsOneWidget);
      expect(find.text('github.com'), findsOneWidget);
      expect(find.text('*.github.com'), findsOneWidget);
      final y = tester.getCenter(find.text('msedge.exe')).dy;
      expect(
        tester.widget<Text>(find.text('msedge.exe')).textAlign,
        TextAlign.left,
      );
      expect(tester.getCenter(find.text('github.com')).dy, closeTo(y, 1));
      expect(tester.getCenter(find.text('*.github.com')).dy, closeTo(y, 1));
      expect(tester.getSize(find.byType(CommonCard)).height, equals(356));
      final header = find.byKey(const ValueKey('select-group-1'));
      final before = tester.widget<Text>(header).style!.color;
      await tester.tap(header);
      await tester.pump();
      expect(tester.widget<Text>(header).style!.color, isNot(before));
      await tester.tap(header);
      await tester.pump();
      expect(tester.widget<Text>(header).style!.color, before);
      expect(find.byType(Switch), findsOneWidget);
      expect(
        find.byKey(const ValueKey('select-engine-toggle')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

