import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/select/select_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectAutostartProvider = Provider<void>((ref) {
  if (!Platform.isWindows || safeModeBuild) return;
  void update() {
    unawaited(
      selectService.autostart.coreReady(
        ref.read(isStartProvider) &&
            ref.read(coreStatusProvider) == CoreStatus.connected,
      ),
    );
  }

  ref.listen(isStartProvider, (_, _) => update());
  ref.listen(coreStatusProvider, (_, _) => update());
  update();
  ref.onDispose(selectService.autostart.close);
});
