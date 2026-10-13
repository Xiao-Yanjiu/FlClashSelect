import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/widgets/widgets.dart';

import 'select_profile.dart';
import 'select_service.dart';

class SelectAutoStartItem extends StatefulWidget {
  final SelectService? service;
  const SelectAutoStartItem({super.key, this.service});
  @override
  State<SelectAutoStartItem> createState() => _SelectAutoStartItemState();
}

class _SelectAutoStartItemState extends State<SelectAutoStartItem> {
  bool _value = false, _busy = true;
  String? _error;
  SelectService get _service => widget.service ?? selectService;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final profile = await _service.load();
      if (mounted) setState(() => _value = profile.autoStart);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _set(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await _service.load();
      await _service.save(
        SelectProfile(
          host: profile.host,
          port: profile.port,
          rules: profile.rules,
          autoStart: value,
        ),
      );
      if (mounted) setState(() => _value = value);
      await _service.autostart.refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListItem.toggle(
    title: Text(context.appLocalizations.selectAutoStart),
    subtitle: _error == null ? null : Text(_error!),
    value: _value,
    onChanged: _busy ? null : (value) => unawaited(_set(value)),
  );
}
