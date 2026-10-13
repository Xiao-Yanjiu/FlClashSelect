import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:tray/tray.dart';

class TrayPopupActions {
  final Map<String, int> _ids = {};
  final Map<int, void Function()> _callbacks = {};
  int register(String key, void Function()? callback) {
    final id = _ids.putIfAbsent(key, () => _ids.length + 1);
    if (callback != null) {
      _callbacks[id] = callback;
    } else {
      _callbacks.remove(id);
    }
    return id;
  }

  void dispatch(String message) => _callbacks[int.tryParse(message)]?.call();
  void clear() {
    _ids.clear();
    _callbacks.clear();
  }
}

class ThemedTrayPopup {
  final String? _testExecutable;
  final void Function(String)? _onMessage;
  final Map<String, String>? _testPalette;
  ThemedTrayPopup()
    : _testExecutable = null,
      _onMessage = null,
      _testPalette = null;
  ThemedTrayPopup.forTest({
    required String executable,
    required Map<String, String> palette,
    required void Function(String) onMessage,
  }) : _testExecutable = executable,
       _testPalette = palette,
       _onMessage = onMessage;
  Process? _process;
  Directory? _stateDirectory;
  String? _pendingState;
  bool _writing = false;
  bool _bootstrapped = false;
  Map<String, String> _palette = {};

  bool get isOpen => _process != null;
  final _actions = TrayPopupActions();

  Future<bool> open(List<TrayMenuItem> menu, bool started) async {
    if (_process != null) return true;
    final file = File(
      _testExecutable ??
          '${appPath.executableDirPath}/select-engine/FlClashSelectTray.exe',
    );
    if (!await file.exists()) return false;
    try {
      if (_testPalette != null) {
        _palette = _testPalette;
      } else {
        final colors = globalState.theme.context.colorScheme;
        String hex(dynamic color) =>
            '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
        _palette = {
          'background': hex(colors.surface),
          'surface': hex(colors.surfaceContainerHigh),
          'border': hex(colors.outlineVariant),
          'foreground': hex(colors.onSurface),
          'accent': hex(colors.secondaryContainer),
          'onAccent': hex(colors.onSecondaryContainer),
        };
      }
      _stateDirectory = await Directory.systemTemp.createTemp(
        'FlClashSelect-tray-',
      );
      _bootstrapped = false;
      final process = await Process.start(file.path, [
        _testExecutable == null ? '--state-file' : '--stream-test',
        '${_stateDirectory!.path}/state.json',
      ]);
      _process = process;
      unawaited(process.stdin.done.catchError((Object _) {}));
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _onMessage?.call(line);
            _actions.dispatch(line);
          });
      unawaited(
        process.stderr.transform(utf8.decoder).forEach((line) {
          _onMessage?.call('ERROR:$line');
        }),
      );
      unawaited(
        process.exitCode.then((code) {
          if (identical(_process, process)) close();
        }),
      );
      update(menu, started);
      return true;
    } catch (_) {
      close();
      return false;
    }
  }

  void update(List<TrayMenuItem> menu, bool started) {
    final process = _process;
    if (process == null) return;
    final groups = <List<Map<String, Object?>>>[];
    var row = <Map<String, Object?>>[];
    for (final item in menu) {
      if (item is TrayMenuSeparator) {
        if (row.isNotEmpty) groups.add(row);
        row = [];
        continue;
      }
      final (label, detail, enabled, checked, action) = switch (item) {
        TrayMenuAction() => (
          item.label,
          item.detail,
          item.enabled,
          false,
          item.onSelected,
        ),
        TrayMenuCheckbox() => (
          item.label,
          item.detail,
          item.enabled,
          item.checked,
          item.onSelected,
        ),
        _ => ('', null, false, false, null),
      };
      if (label.isEmpty) continue;
      final id = _actions.register(label, enabled ? action : null);
      row.add({
        'id': id,
        'label': label,
        'detail': detail ?? '',
        'enabled': enabled,
        'selected': groups.isEmpty && row.length == 1 ? started : checked,
        'close': identical(item, menu.first) || identical(item, menu.last),
      });
    }
    if (row.isNotEmpty) groups.add(row);
    // Windows tail contains selective proxy, auto launch, copy, then exit.
    if (groups.length >= 4 && groups[groups.length - 2].length == 3) {
      final tail = groups[groups.length - 2];
      groups.last.insert(0, tail.removeLast());
    }
    final payload = jsonEncode({..._palette, 'rows': groups});
    if (!_bootstrapped) {
      _bootstrapped = true;
      process.stdin.writeln(payload);
    }
    _pendingState = payload;
    if (!_writing) unawaited(_writeStates(process, _stateDirectory!));
  }

  Future<void> _writeStates(Process process, Directory directory) async {
    _writing = true;
    try {
      while (identical(_process, process) && _pendingState != null) {
        final payload = _pendingState!;
        _pendingState = null;
        final file = File('${directory.path}/pending.json');
        await file.writeAsString(payload, flush: true);
        if (!identical(_process, process)) break;
        await file.rename('${directory.path}/state.json');
      }
    } catch (error) {
      commonPrint.log('Tray state update failed: $error');
    } finally {
      _writing = false;
      if (!identical(_process, process)) unawaited(_cleanState(directory));
      if (identical(_process, process) && _pendingState != null) {
        unawaited(_writeStates(process, directory));
      }
    }
  }

  Future<void> _cleanState(Directory directory) async {
    for (final name in ['state.json', 'pending.json']) {
      try {
        await File('${directory.path}/$name').delete();
      } on FileSystemException {
        continue;
      }
    }
    try {
      await directory.delete();
    } on FileSystemException {
      return;
    }
  }

  void close() {
    final process = _process;
    _process = null;
    _pendingState = null;
    final directory = _stateDirectory;
    _stateDirectory = null;
    _actions.clear();
    process?.kill();
    if (directory != null && !_writing) unawaited(_cleanState(directory));
  }
}
