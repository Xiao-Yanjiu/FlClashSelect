import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpCard(
    WidgetTester tester, {
    required double width,
    required double unitHeight,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MediaQuery.withClampedTextScaling(
                  minScaleFactor: textScale,
                  maxScaleFactor: textScale,
                  child: Builder(
                    builder: (context) {
                      globalState.measure = Measure.of(context, textScale);
                      globalState.theme = CommonTheme.of(context, textScale);
                      return DashboardWidgetMetrics(
                        unitHeight: unitHeight,
                        child: const OutboundMode(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final highlight = find.byKey(const ValueKey('outbound-mode-highlight'));

  Finder rowOf(Mode mode) {
    return find
        .ancestor(of: find.text(mode.label), matching: find.byType(InkWell))
        .first;
  }

  Color highlightColor() {
    final box = find.descendant(
      of: highlight,
      matching: find.byType(DecoratedBox),
    );
    final decoration =
        (box.evaluate().first.widget as DecoratedBox).decoration
            as ShapeDecoration;
    return decoration.color!;
  }

  testWidgets('the phone-height card lists every mode on one line each', (
    tester,
  ) async {
    await pumpCard(tester, width: 280, unitHeight: 80);

    for (final mode in Mode.values) {
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('three equal width modes are horizontal and highlight follows', (
    tester,
  ) async {
    await pumpCard(tester, width: 280, unitHeight: 80);
    final rule = tester.getRect(rowOf(Mode.rule));
    final global = tester.getRect(rowOf(Mode.global));
    final direct = tester.getRect(rowOf(Mode.direct));
    expect(rule.right, lessThan(global.left));
    expect(global.right, lessThan(direct.left));
    expect(rule.top, closeTo(global.top, 0.01));
    expect(global.top, closeTo(direct.top, 0.01));
    expect(rule.width, closeTo(global.width, 0.01));
    expect(global.width, closeTo(direct.width, 0.01));
    expect(tester.getSize(find.byType(OutboundMode)).height, 80);
    await tester.tap(rowOf(Mode.direct));
    await tester.pumpAndSettle();
    expect(container.read(patchClashConfigProvider).mode, Mode.direct);
    expect(tester.getRect(highlight), direct);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'global warns and direct reads as safe, each in a container tone',
    (tester) async {
      await pumpCard(tester, width: 280, unitHeight: 80);
      final colorScheme = Theme.of(
        tester.element(find.byType(OutboundMode)),
      ).colorScheme;
      final colors = <Mode, Color>{};
      for (final mode in Mode.values) {
        await tester.tap(rowOf(mode));
        await tester.pumpAndSettle();
        colors[mode] = highlightColor();
      }

      expect(colors[Mode.rule], colorScheme.secondaryContainer);
      double hueOf(Color color) => Hct.fromInt(color.toARGB32()).hue;
      double hueGap(double a, double b) {
        final d = (a - b).abs() % 360;
        return d > 180 ? 360 - d : d;
      }

      expect(
        hueGap(hueOf(colors[Mode.global]!), hueOf(colorScheme.warning)),
        lessThan(10),
      );
      expect(
        hueGap(hueOf(colors[Mode.direct]!), hueOf(colorScheme.success)),
        lessThan(10),
      );
      expect(colors.values.toSet(), hasLength(Mode.values.length));
    },
  );
}
