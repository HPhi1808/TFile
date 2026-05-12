import 'dart:convert';

/// Bốn giá trị cấu hình ứng dụng (sau khi giải mã nằm trong RAM).
class AppConfigData {
  const AppConfigData({
    required this.channelId,
    required this.botToken,
    required this.apiBackend,
    required this.password,
  });

  final String channelId;
  final String botToken;

  /// Base URL backend (ví dụ `https://xxx.onrender.com`, không có dấu `/` cuối cũng được).
  final String apiBackend;

  /// Mật khẩu HMAC gửi lên backend (`ADMIN_PASSWORD`).
  final String password;

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'botToken': botToken,
        'apiBackend': apiBackend,
        'password': password,
      };

  factory AppConfigData.fromJson(Map<String, dynamic> json) {
    return AppConfigData(
      channelId: json['channelId'] as String? ?? '',
      botToken: json['botToken'] as String? ?? '',
      apiBackend: json['apiBackend'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static AppConfigData fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return AppConfigData.fromJson(map);
  }
}
