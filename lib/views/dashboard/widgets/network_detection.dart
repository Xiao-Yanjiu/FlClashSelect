import 'package:fl_clash/common/common.dart';
import 'dart:async';
import 'package:fl_clash/select/direct_ip.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/icons/icons.dart';

import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/probe_start_hold.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection>
    with ProbeStartHold<NetworkDetection> {
  Timer? _refreshTimer;
  Timer? _retryTimer;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(appVisibleProvider, (previous, visible) {
      if (previous == false && visible) ref.invalidate(directIpProvider);
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(directIpProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final result = ref.watch(directIpProvider);
    ref.listen(directIpProvider, (previous, next) {
      _retryTimer?.cancel();
      if (next.isLoading) return;
      if (next.asData?.value != null) {
        _failures = 0;
        return;
      }
      _failures++;
      final delay = Duration(
        seconds: _failures <= 2
            ? 5
            : _failures <= 5
            ? 10
            : 20,
      );
      _retryTimer = Timer(delay, () {
        if (mounted) ref.invalidate(directIpProvider);
      });
    });
    final entry = ProbeEntry(
      phase: result.isLoading
          ? ProbePhase.probing
          : result.asData?.value == null
          ? ProbePhase.failed
          : ProbePhase.fresh,
      value: result.asData?.value,
    );
    final ipInfo = entry.value;
    final failed = shownPhase(entry) == ProbePhase.failed;
    final localIp = ref.watch(localIpProvider);
    final style = context.textTheme.bodySmall;
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 1),
      child: CommonCard(
        radius: DashboardWidgetMetrics.radiusOf(context),
        onPressed: () => ref.invalidate(directIpProvider),
        child: Padding(
          padding: DashboardWidgetMetrics.paddingOf(
            context,
          ).copyWith(top: 8, bottom: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  Text('IP', style: style),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: appLocalizations.tip,
                      onPressed: () => dialogs.showMessage(
                        title: appLocalizations.tip,
                        message: TextSpan(text: appLocalizations.directIpTip),
                        cancelable: false,
                      ),
                      icon: const GlyphIcon(AppGlyphs.info, size: 14),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ipInfo != null
                          ? IpQualityText(
                              ip: ipInfo.ip,
                              openDetails: true,
                              style: style,
                            )
                          : failed
                          ? Text(
                              'Timeout',
                              style: style?.copyWith(
                                color: context.colorScheme.error,
                              ),
                            )
                          : const SizedBox(
                              width: 14,
                              height: 14,
                              child: CommonCircleLoading(),
                            ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(appLocalizations.intranetIP, style: style),
                  const SizedBox(width: 6),
                  Expanded(
                    child: localIp == null
                        ? const Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CommonCircleLoading(),
                            ),
                          )
                        : Text(
                            localIp.isEmpty
                                ? appLocalizations.noNetwork
                                : localIp,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
