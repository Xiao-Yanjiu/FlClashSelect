import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show join;

class NodeSpeed {
  const NodeSpeed({
    required this.phase,
    this.bytes = 0,
    this.micros = 0,
    this.error,
    this.node = '',
  });
  final String phase;
  final int bytes;
  final int micros;
  final String? error;
  final String node;
  bool get running => phase == 'loading' || phase == 'running';
  double get megabytesPerSecond => micros == 0 ? 0 : bytes / micros;

  factory NodeSpeed.fromJson(Map<String, dynamic> value) => NodeSpeed(
    phase: value['state'] as String,
    bytes: value['bytes'] as int? ?? 0,
    micros: value['micros'] as int? ?? 0,
    error: value['error'] as String?,
    node: value['proxy'] as String? ?? '',
  );
}

class NodeSpeedRunner {
  Process? _process;
  int _generation = 0;

  void cancel() {
    _generation++;
    _process?.kill();
    _process = null;
  }

  Future<NodeSpeed> run({
    required String node,
    required String configPath,
    required Map<String, String> picks,
    required void Function(NodeSpeed) onProgress,
  }) async {
    final generation = ++_generation;
    final path = join(
      appPath.executableDirPath,
      'select-engine',
      'FlClashSelectSpeed.exe',
    );
    final process = await Process.start(path, [
      '--config',
      configPath,
      '--proxy',
      node,
      '--picks',
      jsonEncode(picks),
    ]);
    if (generation != _generation) {
      process.kill();
      return const NodeSpeed(phase: 'stopped');
    }
    _process = process;
    var result = NodeSpeed(phase: 'loading', node: node);
    final stderr = process.stderr.transform(utf8.decoder).join();
    final watchdog = Timer(const Duration(seconds: 45), () => process.kill());
    try {
      await for (final line
          in process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        try {
          result = NodeSpeed.fromJson(jsonDecode(line) as Map<String, dynamic>);
          if (generation == _generation) onProgress(result);
        } on FormatException {
          continue;
        }
      }
      final exit = await process.exitCode;
      final detail = await stderr;
      if (generation != _generation) return const NodeSpeed(phase: 'stopped');
      if (exit != 0 && result.phase != 'failed') {
        return NodeSpeed(
          phase: 'failed',
          node: node,
          error: detail.isEmpty ? 'Speed worker exited ($exit)' : detail,
        );
      }
      if (result.running) {
        return NodeSpeed(
          phase: 'failed',
          node: node,
          error: 'Speed worker did not return a result',
        );
      }
      return result;
    } finally {
      watchdog.cancel();
      process.kill();
      if (_process == process) _process = null;
    }
  }
}

final nodeSpeedRunnerProvider = Provider<NodeSpeedRunner>((ref) {
  final runner = NodeSpeedRunner();
  ref.onDispose(runner.cancel);
  return runner;
});

final nodeSpeedsProvider = NotifierProvider<NodeSpeeds, Map<String, NodeSpeed>>(
  NodeSpeeds.new,
);

class NodeSpeeds extends Notifier<Map<String, NodeSpeed>> {
  int _generation = 0;
  String? _active;

  @override
  Map<String, NodeSpeed> build() {
    final runner = ref.read(nodeSpeedRunnerProvider);
    ref.onDispose(() {
      _generation++;
      _active = null;
      runner.cancel();
    });
    ref.listen(currentProfileIdProvider, (previous, next) {
      if (previous != next) {
        cancel();
        state = {};
      }
    });
    ref.listen(coreStatusProvider, (_, next) {
      if (next != CoreStatus.connected) cancel();
    });
    return {};
  }

  void cancel() {
    _generation++;
    ref.read(nodeSpeedRunnerProvider).cancel();
    final active = _active;
    if (active != null) {
      state = {...state, active: const NodeSpeed(phase: 'stopped')};
    }
    _active = null;
  }

  Future<void> test(String cardName) async {
    if (cardName.isEmpty) return;
    if (_active == cardName) {
      cancel();
      return;
    }
    cancel();
    final generation = ++_generation;
    _active = cardName;
    final selected = ref
        .read(realSelectedProxyStateProvider(cardName))
        .proxyName;
    final node = selected.isEmpty ? cardName : selected;
    state = {...state, cardName: NodeSpeed(phase: 'loading', node: node)};
    try {
      if (safeModeBuild) {
        throw StateError(currentAppLocalizations.selectSafeMode);
      }
      if (!ref.read(isStartProvider)) {
        throw StateError(currentAppLocalizations.selectCoreRequired);
      }
      final result = await ref
          .read(nodeSpeedRunnerProvider)
          .run(
            node: node,
            configPath: await appPath.configFilePath,
            picks: ref.read(selectedMapProvider),
            onProgress: (result) {
              if (generation == _generation) {
                state = {...state, cardName: result};
              }
            },
          );
      if (generation == _generation) state = {...state, cardName: result};
    } catch (error) {
      if (generation == _generation) {
        state = {
          ...state,
          cardName: NodeSpeed(phase: 'failed', node: node, error: '$error'),
        };
      }
    } finally {
      if (generation == _generation) _active = null;
    }
  }
}
