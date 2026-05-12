import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// HMAC-SHA256 khớp backend: `"[METHOD]:[path]:[timestampMs]"` → header [X-Timestamp], [X-Signature] (hex thường).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.passwordResolver});

  /// Trả về mật khẩu HMAC (ADMIN_PASSWORD) đang mở khoá trong RAM; null → từ chối request.
  final String? Function() passwordResolver;

  static const String kSkipHmacAuth = 'skipHmacAuth';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (options.extra[kSkipHmacAuth] == true) {
        handler.next(options);
        return;
      }

      final path = options.uri.path;
      if (path.endsWith('/api/health') || path == '/api/health') {
        handler.next(options);
        return;
      }

      final password = passwordResolver();
      if (password == null || password.isEmpty) {
        handler.reject(
          DioException(
            requestOptions: options,
            error: StateError('HMAC password not available (config locked or missing)'),
            type: DioExceptionType.unknown,
          ),
        );
        return;
      }

      if (path.isEmpty) {
        handler.reject(
          DioException(
            requestOptions: options,
            error: StateError('Request path is empty — cannot sign'),
            type: DioExceptionType.unknown,
          ),
        );
        return;
      }

      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final method = options.method.toUpperCase();
      final payload = '$method:$path:$ts';
      final signature = _hmacSha256Hex(password, payload);

      options.headers['X-Timestamp'] = ts;
      options.headers['X-Signature'] = signature;

      handler.next(options);
    } catch (e, st) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          stackTrace: st,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  static String _hmacSha256Hex(String secret, String message) {
    final mac = Hmac(sha256, utf8.encode(secret));
    final digest = mac.convert(utf8.encode(message));
    final sb = StringBuffer();
    for (final b in digest.bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
