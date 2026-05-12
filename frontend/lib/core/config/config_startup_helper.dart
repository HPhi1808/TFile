import 'config_service.dart';

/// Bước khởi động UI (sau [ConfigService.scanConfigPresence]).
enum ConfigStartupStep {
  /// Không có file → màn hình nhập URL backend, bot token, channel, passphrase lần đầu.
  needsSetup,

  /// Có file → màn hình nhập passphrase để giải mã.
  needsUnlock,
}

class ConfigStartupHelper {
  ConfigStartupHelper._();

  static Future<ConfigStartupStep> resolve() async {
    final presence = await ConfigService.instance.scanConfigPresence();
    switch (presence) {
      case ConfigFilePresence.absent:
        return ConfigStartupStep.needsSetup;
      case ConfigFilePresence.present:
        return ConfigStartupStep.needsUnlock;
    }
  }
}
