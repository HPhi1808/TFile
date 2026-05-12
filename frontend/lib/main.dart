import 'package:flutter/material.dart';

import 'core/core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TFileApp());
}

/// Skeleton: thay bằng router của bạn. Luồng: [ConfigStartupHelper.resolve] → Unlock / Setup.
class TFileApp extends StatelessWidget {
  const TFileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TFile',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const _BootstrapHome(),
    );
  }
}

class _BootstrapHome extends StatefulWidget {
  const _BootstrapHome();

  @override
  State<_BootstrapHome> createState() => _BootstrapHomeState();
}

class _BootstrapHomeState extends State<_BootstrapHome> {
  ConfigStartupStep? _step;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _step = null;
      _error = null;
    });
    try {
      final step = await ConfigStartupHelper.resolve();
      if (mounted) setState(() => _step = step);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Lỗi khởi động: $_error')),
      );
    }
    if (_step == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    switch (_step!) {
      case ConfigStartupStep.needsSetup:
        return Scaffold(
          appBar: AppBar(title: const Text('Thiết lập')),
          body: Center(
            child: Text(
              'Chưa có tfile_config.enc — hiển thị màn hình Setup (URL, token, …) rồi gọi ConfigService.saveConfig.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        );
      case ConfigStartupStep.needsUnlock:
        return Scaffold(
          appBar: AppBar(title: const Text('Mở khoá')),
          body: Center(
            child: Text(
              'Đã có cấu hình — hiển thị form nhập passphrase rồi gọi ConfigService.unlockWithPassphrase.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        );
    }
  }
}
