import 'dart:convert';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'monitor height defaults and saved height survive settings serialization',
    () {
      expect(AppSettingProps.fromJson({}).proxyMonitorHeightUnits, 4);
      const settings = AppSettingProps(proxyMonitorHeightUnits: 3.75);
      final saved =
          jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>;
      expect(AppSettingProps.fromJson(saved).proxyMonitorHeightUnits, 3.75);
    },
  );
}
