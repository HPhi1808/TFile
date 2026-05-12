import 'package:dio/dio.dart';

import '../config/config_service.dart';
import 'auth_interceptor.dart';

/// Tạo [Dio] gắn baseUrl từ cấu hình đã mở khoá + [AuthInterceptor].
Dio createAuthenticatedDio({
  Duration connectTimeout = const Duration(seconds: 20),
  Duration receiveTimeout = const Duration(seconds: 30),
}) {
  final cfg = ConfigService.instance.memoryConfig;
  if (cfg == null) {
    throw StateError('createAuthenticatedDio: config not unlocked');
  }
  final base = cfg.apiBackend.trim().replaceAll(RegExp(r'/+$'), '');
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      passwordResolver: () => ConfigService.instance.memoryConfig?.password,
    ),
  );

  return dio;
}
