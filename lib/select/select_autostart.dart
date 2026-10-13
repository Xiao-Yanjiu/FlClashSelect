import 'dart:async';

import 'select_profile.dart';

class SelectAutostart {
  final Future<SelectProfile> Function() load;
  final Future<void> Function(SelectProfile) start;
  final Future<void> Function() stop;
  final void Function(Object) onError;
  bool _ready = false;
  bool _paused = false;
  bool _closed = false;
  int _revision = 0;
  Future<void> _pending = Future.value();

  SelectAutostart({
    required this.load,
    required this.start,
    required this.stop,
    required this.onError,
  });

  Future<void> coreReady(bool ready) {
    if (_closed || _ready == ready) return _pending;
    _ready = ready;
    _paused = false;
    return refresh();
  }

  void pause() {
    _paused = true;
    _revision++;
  }

  Future<void> refresh() {
    final revision = ++_revision;
    _pending = _pending.then((_) async {
      if (_closed || revision != _revision) return;
      try {
        if (!_ready) {
          await stop();
          return;
        }
        final profile = await load();
        if (_closed || revision != _revision || _paused || !profile.autoStart) {
          return;
        }
        await start(profile);
        if (_closed || !_ready || _paused) await stop();
      } catch (error) {
        if (!_closed) onError(error);
      }
    });
    return _pending;
  }

  void close() {
    _closed = true;
    _revision++;
    unawaited(_pending.then((_) => stop()));
  }
}
