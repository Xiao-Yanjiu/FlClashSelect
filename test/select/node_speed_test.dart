import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/select/node_speed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Runner extends NodeSpeedRunner {
  String? node;
  int cancellations = 0;
  Completer<NodeSpeed>? pending;
  @override
  void cancel() {
    cancellations++;
  }

  @override
  Future<NodeSpeed> run({
    required String node,
    required String configPath,
    required Map<String, String> picks,
    required void Function(NodeSpeed) onProgress,
  }) async {
    this.node = node;
    onProgress(
      NodeSpeed(phase: 'running', node: node, bytes: 1000, micros: 1000),
    );
    return pending == null
        ? NodeSpeed(phase: 'done', node: node, bytes: 2000000, micros: 1000000)
        : pending!.future;
  }
}

ProviderContainer _container(_Runner runner) => ProviderContainer(
  overrides: [
    nodeSpeedRunnerProvider.overrideWithValue(runner),
    isStartProvider.overrideWithValue(true),
    coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
    selectedMapProvider.overrideWithValue({'GLOBAL': 'selected-node'}),
    currentProfileIdProvider.overrideWithBuild((_, _) => 1),
    groupsProvider.overrideWithBuild(
      (_, _) => const [
        Group(name: 'GLOBAL', type: GroupType.Selector, now: 'selected-node'),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    AppPath.supportDirectory = () async => Directory.systemTemp;
    AppPath.temporaryDirectory = () async => Directory.systemTemp;
    AppPath.cacheDirectory = () async => Directory.systemTemp;
  });

  test(
    'selected group resolves to its actual node and stores card speed',
    () async {
      final runner = _Runner();
      final container = _container(runner);
      addTearDown(container.dispose);
      await container.read(nodeSpeedsProvider.notifier).test('GLOBAL');
      expect(runner.node, 'selected-node');
      final result = container.read(nodeSpeedsProvider)['GLOBAL']!;
      expect(result.phase, 'done');
      expect(result.megabytesPerSecond, 2);
    },
  );

  test('cancel ignores a late successful result', () async {
    final runner = _Runner()..pending = Completer<NodeSpeed>();
    final container = _container(runner);
    addTearDown(container.dispose);
    final controller = container.read(nodeSpeedsProvider.notifier);
    final job = controller.test('selected-node');
    await Future<void>.delayed(Duration.zero);
    controller.cancel();
    runner.pending!.complete(
      const NodeSpeed(phase: 'done', bytes: 2000000, micros: 1000000),
    );
    await job;
    expect(
      container.read(nodeSpeedsProvider)['selected-node']!.phase,
      'stopped',
    );
    expect(runner.cancellations, greaterThan(1));
  });

  test('disposal cancels worker and does not publish late data', () async {
    final runner = _Runner()..pending = Completer<NodeSpeed>();
    final container = _container(runner);
    final job = container
        .read(nodeSpeedsProvider.notifier)
        .test('selected-node');
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    runner.pending!.complete(const NodeSpeed(phase: 'done'));
    await job;
    expect(runner.cancellations, greaterThan(1));
  });
}
