import 'dart:convert';

import 'package:fl_clash/select/select_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'application and domain rules follow exclusions and default to direct',
    () {
      const profile = SelectProfile(
        rules: [
          SelectRule(SelectRuleKind.application, 'Discord.exe'),
          SelectRule(SelectRuleKind.domain, '*.github.com'),
          SelectRule(SelectRuleKind.domain, 'disabled.example', enabled: false),
        ],
      );
      final config = profile.toBridgeProfile();
      final rules = config['ProxyRules']! as List;
      expect(rules.first['Action'], 'DIRECT');
      expect(rules[2]['ProcessName'], 'Discord.exe');
      expect(rules[3]['TargetDomains'], '*.github.com');
      expect(rules[3]['TargetHosts'], '*');
      expect(rules.last['Action'], 'DIRECT');
      expect(rules.length, 5);
      expect((config['ProxyConfigs']! as List).first['Port'], '17891');
      expect(
        SelectProfile.decodeSettings(
          profile.encodeSettings(),
        ).rules.last.enabled,
        isFalse,
      );
    },
  );

  test('rejects URLs, rule separators and oversized native fields', () {
    expect(
      SelectProfile.isValidPattern(
        SelectRuleKind.domain,
        'https://github.com/path',
      ),
      isFalse,
    );
    expect(
      SelectProfile.isValidPattern(SelectRuleKind.application, 'x.exe;*.exe'),
      isFalse,
    );
    expect(
      SelectProfile.isValidPattern(SelectRuleKind.domain, '*.github.com'),
      isTrue,
    );
    expect(
      SelectProfile.isValidPattern(
        SelectRuleKind.application,
        '${List.filled(100, "中").join()}.exe',
      ),
      isFalse,
    );
    expect(utf8.encode('Discord.exe').length, lessThan(240));
  });
}
