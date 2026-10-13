import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test(
    'dedicated ingress preserves subscription listeners and pins GLOBAL',
    () async {
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: Directory.systemTemp.path,
          profileId: 7,
          rawConfig: {
            'listeners': [
              {
                'name': 'existing',
                'type': 'http',
                'listen': '127.0.0.1',
                'port': 17001,
              },
              {'name': 'SELECT-OUTBOUND', 'type': 'socks', 'port': 17002},
            ],
          },
          realPatchConfig: const PatchClashConfig(),
          overrideDns: false,
          overrideNtp: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash',
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;
      final listeners = config['listeners'] as YamlList;
      expect(
        listeners.where((item) => item['name'] == 'existing'),
        hasLength(1),
      );
      final owned = listeners
          .where((item) => item['name'] == 'SELECT-OUTBOUND')
          .toList();
      expect(owned, hasLength(1));
      if (Platform.isWindows && !safeModeBuild) {
        expect(owned.single['port'], 17891);
        expect(owned.single['proxy'], isNull);
        expect(owned.single['listen'], '127.0.0.1');
        expect(owned.single['users'], isEmpty);
      }
    },
  );
}
