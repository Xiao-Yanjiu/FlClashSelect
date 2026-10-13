import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'select_profile.dart';
import 'select_connections.dart';
import 'select_service.dart';

class SelectView extends ConsumerStatefulWidget {
  const SelectView({super.key, this.service});
  final SelectService? service;
  @override
  ConsumerState<SelectView> createState() => _SelectViewState();
}

class _SelectViewState extends ConsumerState<SelectView> {
  SelectService get _service => widget.service ?? selectService;
  final _pattern = TextEditingController();
  List<SelectRule> _rules = [];
  bool _proxyOnly = true;
  String _query = '';
  List<SelectConnection> _connections = [];
  SelectRuleKind _kind = SelectRuleKind.application;
  Timer? _timer;
  bool _busy = true;
  bool _refreshing = false;
  String _phase = 'stopped';
  String? _error;
  List<String> _events = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refresh()),
    );
  }

  Future<void> _load() async {
    try {
      final profile = await _service.load();
      if (mounted) {
        setState(() {
          _rules = profile.rules.toList();
        });
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final status = await _service.status();
      final events = await _service.events();
      final connections = await _service.connections();
      if (mounted) {
        setState(() {
          _phase = '${status['state']}';
          _events = events;
          _connections = connections;
          if (_service.autostartError != null) _error = _service.autostartError;
          if (_phase == 'failed') _error = '${status['error']}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRules(List<SelectRule> next) async {
    final current = await _service.load();
    await _service.save(
      SelectProfile(
        host: current.host,
        port: current.port,
        autoStart: current.autoStart,
        rules: List.unmodifiable(next),
      ),
    );
    if (mounted) setState(() => _rules = next);
  }

  void _add() {
    final value = _pattern.text.trim();
    if (!SelectProfile.isValidPattern(_kind, value) ||
        _rules.length >= 240 ||
        _rules.any(
          (rule) =>
              rule.kind == _kind &&
              rule.pattern.toLowerCase() == value.toLowerCase(),
        )) {
      setState(() => _error = context.appLocalizations.selectInvalid);
      return;
    }
    unawaited(
      _run(() async {
        await _changeRules([..._rules, SelectRule(_kind, value)]);
        _pattern.clear();
      }),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pattern.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final running = _phase == 'running' || _phase == 'waiting';
    final status = switch (_phase) {
      'running' => l.selectRunning,
      'waiting' => l.selectWaiting,
      'failed' => l.selectFailed,
      _ => l.selectIdle,
    };
    final connections = _connections
        .where(
          (record) => (!_proxyOnly || record.proxied) && record.matches(_query),
        )
        .take(200)
        .toList();
    return CommonScaffold(
      title: l.selectTitle,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.contentTopPadding, bottom: 24),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(status),
            subtitle: Text(l.selectAuth),
            trailing: Switch(
              value: running,
              onChanged: _busy
                  ? null
                  : (value) => unawaited(
                      _run(() async {
                        if (!value) {
                          await _service.stop();
                          return;
                        }
                        if (safeModeBuild) throw StateError(l.selectSafeMode);
                        if (!ref.read(isStartProvider) ||
                            ref.read(coreStatusProvider) !=
                                CoreStatus.connected) {
                          throw StateError(l.selectCoreRequired);
                        }
                        await _service.start(await _service.load());
                      }),
                    ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(_error!),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pattern,
                  enabled: !_busy,
                  decoration: InputDecoration(labelText: l.selectPattern),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 104,
                child: DropdownButtonFormField<SelectRuleKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: SelectRuleKind.application,
                      child: Text(l.selectTypeProcess),
                    ),
                    DropdownMenuItem(
                      value: SelectRuleKind.domain,
                      child: Text(l.selectTypeDomain),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _kind = value!),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _busy ? null : _add, child: Text(l.add)),
            ],
          ),
          const SizedBox(height: 12),
          for (final rule in _rules)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Switch(
                value: rule.enabled,
                onChanged: _busy
                    ? null
                    : (value) {
                        final next = _rules.toList();
                        next[next.indexOf(rule)] = rule.withEnabled(value);
                        unawaited(_run(() => _changeRules(next)));
                      },
              ),
              title: Text(rule.pattern),
              subtitle: Text(
                rule.kind == SelectRuleKind.application
                    ? l.selectTypeProcess
                    : l.selectTypeDomain,
              ),
              trailing: IconButton(
                tooltip: l.delete,
                icon: const GlyphIcon(AppGlyphs.delete),
                onPressed: _busy
                    ? null
                    : () => unawaited(
                        _run(
                          () => _changeRules(
                            _rules.where((value) => value != rule).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: Text(l.selectDiagnostics),
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.selectProxyOnly),
                value: _proxyOnly,
                onChanged: (value) =>
                    setState(() => _proxyOnly = value ?? true),
              ),
              TextField(
                decoration: InputDecoration(labelText: l.selectSearch),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: connections.isEmpty
                    ? Center(child: Text(l.selectNoConnections))
                    : ListView.builder(
                        itemCount: connections.length,
                        itemBuilder: (context, index) {
                          final record = connections[index];
                          final time = record.time.toIso8601String().substring(
                            11,
                            19,
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: SelectableText(
                              '${record.process} → ${record.domain.isEmpty ? record.endpoint : record.domain}',
                            ),
                            subtitle: SelectableText(
                              '$time · PID ${record.pid} · ${record.protocol} · ${record.endpoint}\n${record.proxied ? l.selectForwarded : l.selectDirect}${record.domain.isEmpty ? ' · ${l.selectUnknownDomain}' : ''}',
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                _events.isEmpty ? l.selectEmptyEvents : _events.join('\n'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
