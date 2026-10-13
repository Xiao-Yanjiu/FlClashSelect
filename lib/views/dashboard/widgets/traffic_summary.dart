import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class TrafficSummaryCard extends ConsumerWidget {
  const TrafficSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(trafficsProvider).list.safeLast(const Traffic());
    final total = ref.watch(totalTrafficProvider);
    final l = context.appLocalizations;
    Widget line(String label, String value) => Row(
      children: [
        Text(label, style: context.textTheme.bodySmall),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: context.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 1),
      child: CommonCard(
        radius: DashboardWidgetMetrics.radiusOf(context),
        child: Padding(
          padding: DashboardWidgetMetrics.paddingOf(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              line(l.networkSpeed, speed.speedText),
              line(
                l.trafficUsage,
                '↑ ${total.up.traffic.show}   ↓ ${total.down.traffic.show}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
