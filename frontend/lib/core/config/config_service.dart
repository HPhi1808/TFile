import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_config_data.dart';

/// Trạng thái khởi động: có file cấu hình mã hoá hay chưa.
enum ConfigFilePresence {
  /// Chưa có [kConfigFileName] trong thư mục documents của app.
  absent,

  /// Đã có file — cần passphrase để giải mã (hoặc Setup mới nếu người dùng ghi đè).
  present,
}

/// Quản lý cấu hình: lưu / đọc AES-256-CBC, key từ passphrase (đệm 32 byte UTF-8).
class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  static const String kConfigFileName = 'tfile_config.enc';

  /// IV cố định 16 byte (AES block) đứng trước ciphertext trong file.
  static const int _ivLength = 16;

  AppConfigData? _unlocked;

  /// Cấu hình đã mở khoá (RAM). Chỉ dùng sau [unlockWithPassphrase] / [saveConfig].
  AppConfigData? get memoryConfig => _unlocked;

  bool get isUnlocked => _unlocked != null;

  /// Đường dẫn file cấu hình trong [getApplicationDocumentsDirectory].
  Future<File> configFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, kConfigFileName));
  }

  /// Quét có file cấu hình hay không (không đọc nội dung).
  Future<ConfigFilePresence> scanConfigPresence() async {
    try {
      final file = await configFile();
      if (await file.exists() && await file.length() > _ivLength) {
        return ConfigFilePresence.present;
      }
      return ConfigFilePresence.absent;
    } catch (e, st) {
      throw ConfigException('scanConfigPresence failed: $e', cause: e, stackTrace: st);
    }
  }

  /// Ghi cấu hình: [passphrase] làm key AES (đệm 32 byte), [data] JSON rồi mã hoá.
  Future<void> saveConfig(String passphrase, AppConfigData data) async {
    try {
      if (passphrase.isEmpty) {
        throw ConfigException('passphrase must not be empty');
      }
      final key = _keyFromPassphrase(passphrase);
      final iv = IV.fromSecureRandom(_ivLength);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final plain = utf8.encode(data.toJsonString());
      final encrypted = encrypter.encryptBytes(plain, iv: iv);

      final ivBytes = iv.bytes;
      final cipherBytes = encrypted.bytes;
      final out = Uint8List(ivBytes.length + cipherBytes.length);
      out.setAll(0, ivBytes);
      out.setAll(ivBytes.length, cipherBytes);

      final file = await configFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(out, flush: true);

      _unlocked = data;
    } catch (e, st) {
      if (e is ConfigException) rethrow;
      throw ConfigException('saveConfig failed: $e', cause: e, stackTrace: st);
    }
  }

  /// Giải mã file hiện có bằng passphrase; thành công thì lưu [memoryConfig].
  Future<void> unlockWithPassphrase(String passphrase) async {
    try {
      if (passphrase.isEmpty) {
        throw ConfigException('passphrase must not be empty');
      }
      final file = await configFile();
      if (!await file.exists()) {
        throw ConfigException('config file not found');
      }
      final raw = await file.readAsBytes();
      if (raw.length <= _ivLength) {
        throw ConfigException('config file corrupt or empty');
      }

      final iv = IV(Uint8List.sublistView(raw, 0, _ivLength));
      final cipher = Encrypted(Uint8List.sublistView(raw, _ivLength));
      final key = _keyFromPassphrase(passphrase);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decryptedBytes = encrypter.decryptBytes(cipher, iv: iv);
      final jsonString = utf8.decode(decryptedBytes);
      _unlocked = AppConfigData.fromJsonString(jsonString);
    } on FormatException catch (e, st) {
      throw ConfigException('invalid config JSON', cause: e, stackTrace: st);
    } catch (e, st) {
      if (e is ConfigException) rethrow;
      // Sai passphrase / dữ liệu hỏng thường ném từ encrypt engine.
      throw ConfigException('unlock failed (wrong passphrase or corrupt file): $e',
          cause: e, stackTrace: st);
    }
  }

  /// Xoá file + bộ nhớ (đăng xuất / reset).
  Future<void> clearConfigFile() async {
    try {
      _unlocked = null;
      final file = await configFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      throw ConfigException('clearConfigFile failed: $e', cause: e, stackTrace: st);
    }
  }

  void lockFromMemory() {
    _unlocked = null;
  }

  /// Đọc file từ đường dẫn tùy chỉnh (ví dụ bản sao ở storage công khai sau khi cấp quyền Android).
  /// Không ghi đè file trong documents; chỉ [unlockWithPassphrase] từ documents là luồng chính.
  Future<void> unlockFromFileAtPath(String passphrase, String absolutePath) async {
    try {
      final file = File(absolutePath);
      if (!await file.exists()) {
        throw ConfigException('import file not found');
      }
      final raw = await file.readAsBytes();
      if (raw.length <= _ivLength) {
        throw ConfigException('import file corrupt or empty');
      }
      final iv = IV(Uint8List.sublistView(raw, 0, _ivLength));
      final cipher = Encrypted(Uint8List.sublistView(raw, _ivLength));
      final key = _keyFromPassphrase(passphrase);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decryptedBytes = encrypter.decryptBytes(cipher, iv: iv);
      final jsonString = utf8.decode(decryptedBytes);
      _unlocked = AppConfigData.fromJsonString(jsonString);
    } catch (e, st) {
      if (e is ConfigException) rethrow;
      throw ConfigException('unlockFromFileAtPath failed: $e', cause: e, stackTrace: st);
    }
  }

  /// Sao chép file đã mã hoá hiện tại (trong documents) sang [targetAbsolutePath] — hữu ích backup thủ công.
  Future<void> exportEncryptedCopyTo(String targetAbsolutePath) async {
    try {
      final src = await configFile();
      if (!await src.exists()) {
        throw ConfigException('nothing to export');
      }
      final target = File(targetAbsolutePath);
      await target.parent.create(recursive: true);
      await src.copy(target.path);
    } catch (e, st) {
      if (e is ConfigException) rethrow;
      throw ConfigException('exportEncryptedCopyTo failed: $e', cause: e, stackTrace: st);
    }
  }

  /// Key 32 byte: UTF-8 passphrase, thiếu thì đệm 0, dư thì cắt (theo yêu cầu spec).
  static Key _keyFromPassphrase(String passphrase) {
    final bytes = utf8.encode(passphrase);
    final buf = Uint8List(32);
    final n = bytes.length < 32 ? bytes.length : 32;
    buf.setAll(0, bytes.sublist(0, n));
    return Key(buf);
  }
}

class ConfigException implements Exception {
  ConfigException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'ConfigException: $message';
}
