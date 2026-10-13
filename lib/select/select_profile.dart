import 'dart:convert';

enum SelectRuleKind { application, domain }

class SelectRule {
  final SelectRuleKind kind;
  final String pattern;
  final bool enabled;

  const SelectRule(this.kind, this.pattern, {this.enabled = true});

  SelectRule withEnabled(bool value) =>
      SelectRule(kind, pattern, enabled: value);

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'pattern': pattern,
    'enabled': enabled,
  };

  factory SelectRule.fromJson(Map<String, dynamic> json) => SelectRule(
    SelectRuleKind.values.byName(json['kind'] as String),
    json['pattern'] as String,
    enabled: json['enabled'] as bool? ?? true,
  );
}

class SelectProfile {
  static const directProcesses = [
    'FlClashSelect.exe',
    'FlClash.exe',
    'v2rayN.exe',
    'xray.exe',
    'sing-box.exe',
    'clash.meta.exe',
    'FlClashCore.exe',
    'ProxyBridge_CLI.exe',
    'ProxyBridge.exe',
  ];

  final bool autoStart;
  final String host;
  final int port;
  final List<SelectRule> rules;

  const SelectProfile({
    this.autoStart = false,
    this.host = '127.0.0.1',
    this.port = 17891,
    required this.rules,
  });

  factory SelectProfile.defaults() => const SelectProfile(
    rules: [
      SelectRule(SelectRuleKind.application, 'ChatGPT.exe'),
      SelectRule(SelectRuleKind.application, 'codex.exe'),
      SelectRule(SelectRuleKind.application, 'Discord.exe'),
      SelectRule(SelectRuleKind.domain, 'github.com'),
      SelectRule(SelectRuleKind.domain, '*.github.com'),
      SelectRule(SelectRuleKind.domain, 'githubusercontent.com'),
      SelectRule(SelectRuleKind.domain, '*.githubusercontent.com'),
      SelectRule(SelectRuleKind.domain, 'githubassets.com'),
      SelectRule(SelectRuleKind.domain, '*.githubassets.com'),
    ],
  );

  static bool isValidPattern(SelectRuleKind kind, String pattern) {
    if (utf8.encode(pattern).length > 240) {
      return false;
    }
    if (kind == SelectRuleKind.application) {
      return RegExp(
        r'^[^\\/:*?";<>|]+\.exe$',
        caseSensitive: false,
      ).hasMatch(pattern);
    }
    final domain = pattern.startsWith('*.') ? pattern.substring(2) : pattern;
    return domain.length <= 253 &&
        domain.split('.').length >= 2 &&
        domain
            .split('.')
            .every(
              (label) => RegExp(
                r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
              ).hasMatch(label),
            );
  }

  String encodeSettings() => jsonEncode({
    'autoStart': autoStart,
    'host': host,
    'port': port,
    'rules': rules.map((rule) => rule.toJson()).toList(),
  });

  factory SelectProfile.decodeSettings(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return SelectProfile(
      autoStart: json['autoStart'] as bool? ?? false,
      host: json['host'] as String,
      port: json['port'] as int,
      rules: (json['rules'] as List)
          .map((rule) => SelectRule.fromJson(rule as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, Object> toBridgeProfile({bool temporaryAll = false}) {
    if (host != '127.0.0.1' || port < 1 || port > 65535) {
      throw const FormatException('Invalid loopback proxy endpoint');
    }
    for (final rule in rules) {
      if (!isValidPattern(rule.kind, rule.pattern)) {
        throw const FormatException('Invalid rule pattern');
      }
    }
    Map<String, Object> entry(
      String process,
      String hosts,
      String action, {
      String domains = '*',
    }) => {
      'ProcessName': process,
      'TargetHosts': hosts,
      'TargetDomains': domains,
      'TargetPorts': '*',
      'Protocol': 'BOTH',
      'Action': action,
      'IsEnabled': true,
      'ProxyConfigId': 1,
    };
    return {
      'Version': '1.0',
      'LocalhostViaProxy': false,
      'IsTrafficLoggingEnabled': true,
      'ProxyConfigs': [
        {
          'Id': 1,
          'Type': 'socks5',
          'Host': host,
          'Port': '$port',
          'Username': '',
          'Password': '',
          'SendDomainToProxy': true,
        },
      ],
      'ProxyRules': [
        entry(directProcesses.join('; '), '*', 'DIRECT'),
        entry(
          '*',
          '127.*; ::1; 10.*; 192.168.*; 172.16.0.0-172.31.255.255',
          'DIRECT',
        ),
        for (final rule in rules.where((rule) => rule.enabled))
          entry(
            rule.kind == SelectRuleKind.application ? rule.pattern : '*',
            '*',
            'PROXY',
            domains: rule.kind == SelectRuleKind.domain ? rule.pattern : '*',
          ),
        entry('*', '*', temporaryAll ? 'PROXY' : 'DIRECT'),
      ],
    };
  }
}
