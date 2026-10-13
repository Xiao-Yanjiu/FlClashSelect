import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/select/direct_ip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Core extends Mock implements CoreHandlerInterface {}

void main() {
  setUpAll(() => registerFallbackValue(const OutboundIpParams(timeout: 0)));
  test(
    'running core IP query pins DIRECT regardless of selected proxy',
    () async {
      final core = _Core();
      when(() => core.outboundIp(any())).thenAnswer(
        (_) async => const OutboundIpResult(
          url: 'https://www.cloudflare.com/cdn-cgi/trace',
          body: 'ip=203.0.113.5\nloc=CN\n',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(container.dispose);
      final answer = await container.read(directIpProvider.future);
      expect(answer!.ip, '203.0.113.5');
      final params =
          verify(() => core.outboundIp(captureAny())).captured.single
              as OutboundIpParams;
      expect(params.proxyName, directOutbound);
    },
  );
  test(
    'IP lookup works with core stopped through host direct reader',
    () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          coreStatusProvider.overrideWithBuild(
            (_, _) => CoreStatus.disconnected,
          ),
          directIpReaderProvider.overrideWithValue(() async {
            calls++;
            return const IpInfo(ip: '203.0.113.6', countryCode: 'CN');
          }),
        ],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(directIpProvider.future))!.ip,
        '203.0.113.6',
      );
      expect(calls, 1);
    },
  );
  test('network change triggers a new direct IP lookup immediately', () async {
    final core = _Core();
    when(() => core.outboundIp(any())).thenAnswer(
      (_) async => const OutboundIpResult(
        url: 'https://www.cloudflare.com/cdn-cgi/trace',
        body: 'ip=203.0.113.5\nloc=CN\n',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(directIpProvider, (_, _) {});
    await container.read(directIpProvider.future);
    container.read(routeTrackerProvider.notifier).bumpHostEpoch();
    await container.read(directIpProvider.future);
    final params = verify(
      () => core.outboundIp(captureAny()),
    ).captured.cast<OutboundIpParams>();
    expect(params.length, 2);
    expect(params.every((item) => item.proxyName == directOutbound), isTrue);
  });
}
