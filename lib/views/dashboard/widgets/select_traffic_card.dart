import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/enum/enum.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/select/select_service.dart';
import 'package:fl_clash/select/select_traffic.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/icons/icons.dart';
import '../widget_metrics.dart';

class SelectTrafficCard extends ConsumerStatefulWidget {
  final Future<Map<String, dynamic>> Function()? reader;
  const SelectTrafficCard({super.key, this.reader});
  @override
  ConsumerState<SelectTrafficCard> createState() => _SelectTrafficCardState();
}

class _SelectTrafficCardState extends ConsumerState<SelectTrafficCard> {
  final _meter = SelectTrafficMeter();
  Timer? _timer;
  bool _reading = false;
  List<SelectTraffic> _rows = [];
  final Map<String, SelectTraffic> _ledger = {};
  final Map<String, DateTime> _activity = {};
  final Set<int> _groupFields = {0};
  bool _enabled = false, _busy = false;
  String? _error;

  Future<void> _toggle(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (value) {
        final l = context.appLocalizations;
        if (safeModeBuild) throw StateError(l.selectSafeMode);
        if (!ref.read(isStartProvider) ||
            ref.read(coreStatusProvider) != CoreStatus.connected) {
          throw StateError(l.selectCoreRequired);
        }
        await selectService.start(await selectService.load());
      } else {
        await selectService.stop();
      }
      await _poll();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<SelectTraffic> _grouped() {
    final groups = <String, List<SelectTraffic>>{};
    final active = {for (final row in _rows) row.id: row};
    for (final row in _ledger.values) {
      final values = [
        row.process,
        row.domain.isEmpty ? row.ip : row.domain,
        row.rule,
      ];
      final key = _groupFields.isEmpty
          ? row.id
          : jsonEncode([
              for (var i = 0; i < 3; i++)
                if (_groupFields.contains(i)) values[i],
            ]);
      groups.putIfAbsent(key, () => []).add(row);
    }
    return [
      for (final entry in groups.entries)
        (() {
          final latest = entry.value.reduce(
            (a, b) => _activity[b.id]!.isAfter(_activity[a.id]!) ? b : a,
          );
          return SelectTraffic(
            id: entry.key,
            process: latest.process,
            domain: latest.domain,
            ip: latest.ip,
            rule: latest.rule,
            protocol: latest.protocol,
            pid: latest.pid,
            port: latest.port,
            ageMs: latest.ageMs,
            upload: entry.value.fold(0, (sum, row) => sum + row.upload),
            download: entry.value.fold(0, (sum, row) => sum + row.download),
            uploadRate: entry.value.fold(
              0.0,
              (sum, row) => sum + (active[row.id]?.uploadRate ?? 0),
            ),
            downloadRate: entry.value.fold(
              0.0,
              (sum, row) => sum + (active[row.id]?.downloadRate ?? 0),
            ),
          );
        })(),
    ];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_poll()),
    );
  }

  Future<void> _poll() async {
    if (_reading) return;
    _reading = true;
    try {
      final snapshot = await (widget.reader ?? selectService.traffic)();
      if (widget.reader == null) {
        final status = await selectService.status();
        if (mounted)
          _enabled =
              status['state'] == 'running' || status['state'] == 'waiting';
      }
      final rows = _meter.update(snapshot, DateTime.now());
      if (mounted)
        setState(() {
          _rows = rows;
          for (final row in rows) {
            _ledger[row.id] = row;
            _activity[row.id] = DateTime.parse(
              snapshot['updated'] as String,
            ).subtract(Duration(milliseconds: row.ageMs));
          }
        });
    } catch (_) {
      if (mounted) setState(() => _rows = []);
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _bytes(num value) {
    if (value >= 1048576) return '${(value / 1048576).toStringAsFixed(2)} MiB';
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KiB';
    return '${value.toStringAsFixed(0)} B';
  }

  String _compact(num value) {
    if (value >= 1048576) return '${(value / 1048576).toStringAsFixed(1)}M';
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)}K';
    return '${value.toStringAsFixed(0)}B';
  }

  Widget _cell(String value, int flex, {TextStyle? style}) => Expanded(
    flex: flex,
    child: Tooltip(
      message: value,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: style,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final style = context.textTheme.bodySmall;
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 4),
      child: CommonCard(
        radius: DashboardWidgetMetrics.radiusOf(context),
        child: Padding(
          padding: DashboardWidgetMetrics.paddingOf(
            context,
          ).copyWith(top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InfoHeader(
                      padding: EdgeInsets.zero,
                      info: Info(
                        label: l.selectTrafficTitle,
                        glyph: AppGlyphs.networkCheck,
                      ),
                    ),
                  ),
                  Switch(
                    key: const ValueKey('select-engine-toggle'),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: _enabled,
                    onChanged: _busy
                        ? null
                        : (value) => unawaited(_toggle(value)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_error != null)
                Tooltip(
                  message: _error!,
                  child: Text(
                    _error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              Row(
                children: [
                  for (final (index, title) in [
                    l.selectTypeProcess,
                    l.selectTypeDomain,
                    l.selectMatchedRule,
                  ].indexed)
                    Expanded(
                      flex: index == 0 ? 3 : 4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          selected: _groupFields.contains(index),
                          label: title,
                          button: true,
                          child: InkWell(
                            customBorder: AppShape.all(4),
                            onTap: () => setState(() {
                              if (!_groupFields.add(index)) {
                                _groupFields.remove(index);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                title,
                                key: ValueKey('select-group-$index'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style?.copyWith(
                                  color: _groupFields.contains(index)
                                      ? context.colorScheme.success
                                      : context.colorScheme.onSurfaceVariant,
                                  fontWeight: _groupFields.contains(index)
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  _cell(l.selectFlowColumn, 5, style: style),
                ],
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final rows = _grouped();
                    if (rows.isEmpty) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Text(l.selectNoActiveTraffic, style: style),
                      );
                    }
                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      itemExtent: 22,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return Row(
                          children: [
                            _cell(row.process, 3, style: style),
                            _cell(
                              row.domain.isEmpty ? row.ip : row.domain,
                              4,
                              style: style,
                            ),
                            _cell(
                              row.rule.isEmpty ? '—' : row.rule,
                              4,
                              style: style,
                            ),
                            Expanded(
                              flex: 5,
                              child: Tooltip(
                                message:
                                    '↑ ${_bytes(row.upload)} ↓ ${_bytes(row.download)}',
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 51,
                                      child: Text(
                                        '↑${_compact(row.upload)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.left,
                                        style: style,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '↓${_compact(row.download)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.left,
                                        style: style,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

