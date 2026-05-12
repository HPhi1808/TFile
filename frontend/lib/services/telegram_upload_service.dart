import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../core/config/config_service.dart';
import '../core/network/api_client_factory.dart';

// ---------------------------------------------------------------------------
// Kết quả & lỗi (UI có thể bắt [RetryableUploadException] để hiện "Vui lòng thử lại")
// ---------------------------------------------------------------------------

/// Metadata sau khi upload Telegram + lưu backend thành công.
class TelegramUploadResult {
  TelegramUploadResult({
    required this.telegramFileId,
    required this.telegramFileUniqueId,
    required this.telegramThumbId,
    required this.backendItemId,
    required this.name,
    required this.size,
    required this.isVideo,
  });

  final String telegramFileId;
  final String telegramFileUniqueId;
  final String telegramThumbId;
  final String backendItemId;
  final String name;
  final int size;
  final bool isVideo;
}

/// Lỗi logic (Telegram trả ok:false, thiếu file_id, v.v.).
class TelegramUploadException implements Exception {
  TelegramUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'TelegramUploadException: $message';
}

/// Mất mạng / timeout — UI nên hiển thị thông báo kiểu "Vui lòng thử lại".
class RetryableUploadException implements Exception {
  RetryableUploadException(this.userMessage, {this.cause});

  static const String defaultMessage = 'Vui lòng thử lại';

  final String userMessage;
  final Object? cause;

  @override
  String toString() => 'RetryableUploadException: $userMessage';
}

/// Upload file lên Telegram [sendDocument] rồi đồng bộ metadata lên backend TFile.
///
/// Phụ thuộc: [ConfigService.instance] đã unlock (có [AppConfigData] trong RAM).
class TelegramUploadService {
  TelegramUploadService({
    ConfigService? config,
    Dio? telegramDio,
  })  : _config = config ?? ConfigService.instance,
        _telegramDio = telegramDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 45),
                sendTimeout: const Duration(minutes: 30),
                receiveTimeout: const Duration(minutes: 10),
                validateStatus: (s) => s != null && s < 600,
              ),
            );

  final ConfigService _config;
  final Dio _telegramDio;

  static const int _thumbMaxSide = 320;
  static const int _thumbMaxBytes = 50 * 1024; // < 50 KB (Telegram max 320px; dung lượng an toàn)

  // -------------------------------------------------------------------------
  // 1) Thumbnail cục bộ
  // -------------------------------------------------------------------------

  /// Tạo file JPEG tạm trong thư mục cache.
  ///
  /// - **Ảnh:** [flutter_image_compress] — giữ tỷ lệ, cạnh dài tối đa 320px, nén chất lượng
  ///   giảm dần cho tới khi file ~< 50KB (nếu vẫn hơi lớn vẫn trả file cuối cùng đã nén tối đa).
  /// - **Video:** [video_thumbnail] — frame đầu, sau đó cùng pipeline nén JPEG như ảnh.
  Future<File> generateThumbnail(File file, bool isVideo) async {
    final tmpDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;

    if (isVideo) {
      // Frame đầu tiên (time = 0). Cần quyền đọc file video trên thiết bị (manifest / runtime).
      final extracted = await VideoThumbnail.thumbnailFile(
        video: file.absolute.path,
        thumbnailPath: tmpDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: _thumbMaxSide,
        quality: 85,
      );
      if (extracted == null) {
        throw TelegramUploadException(
          'Không tạo được thumbnail từ video (thumbnailFile trả null).',
        );
      }
      final frameFile = File(extracted);
      final out = File(p.join(tmpDir.path, 'tfile_thumb_vid_$stamp.jpg'));
      await _shrinkJpegUnderMaxBytes(frameFile, out);
      if (await frameFile.exists() && frameFile.path != out.path) {
        await frameFile.delete();
      }
      return out;
    }

    // Ảnh: nén trực tiếp ra JPEG tạm.
    final out = File(p.join(tmpDir.path, 'tfile_thumb_img_$stamp.jpg'));
    await _shrinkJpegUnderMaxBytes(file, out);
    return out;
  }

  /// Nén ảnh (hoặc JPEG vừa trích từ video) xuống cạnh tối đa [_thumbMaxSide] và dung lượng mục tiêu [_thumbMaxBytes].
  Future<void> _shrinkJpegUnderMaxBytes(File source, File target) async {
    var quality = 76;
    var side = _thumbMaxSide;
    const minQ = 12;

    while (quality >= minQ) {
      final xfile = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        target.absolute.path,
        quality: quality,
        minWidth: side,
        minHeight: side,
        format: CompressFormat.jpeg,
      );
      if (xfile == null || !await File(xfile.path).exists()) {
        quality -= 8;
        continue;
      }
      final written = File(xfile.path);
      if (written.path != target.path) {
        await target.parent.create(recursive: true);
        await written.copy(target.path);
        await written.delete();
      }
      final len = await target.length();
      if (len <= _thumbMaxBytes) {
        return;
      }
      quality -= 10;
      side = (side * 0.86).round().clamp(140, _thumbMaxSide);
    }

    if (await target.exists()) {
      final len = await target.length();
      if (len <= _thumbMaxBytes + 8192) {
        return;
      }
    }
    throw TelegramUploadException(
      'Không thể nén thumbnail xuống dung lượng chấp nhận được (mục tiêu < 50KB).',
    );
  }

  // -------------------------------------------------------------------------
  // 2) Upload Telegram sendDocument + tiến trình
  // -------------------------------------------------------------------------

  /// Gửi [document] + [thumbnail] tới Bot API (multipart). [onSendProgress] nhận (đã gửi, tổng) — [total] có thể -1 trên một số nền tảng.
  Future<Map<String, dynamic>> sendDocumentWithThumbnail({
    required File document,
    required File thumbnail,
    required void Function(int sent, int total) onSendProgress,
  }) async {
    final cfg = _config.memoryConfig;
    if (cfg == null) {
      throw TelegramUploadException('Chưa mở khoá cấu hình (ConfigService).');
    }

    final token = cfg.botToken.trim();
    final chatId = cfg.channelId.trim();
    if (token.isEmpty || chatId.isEmpty) {
      throw TelegramUploadException('botToken hoặc channelId trống.');
    }

    final url = 'https://api.telegram.org/bot$token/sendDocument';
    final docName = p.basename(document.path);
    final thumbName = p.basename(thumbnail.path);

    final form = FormData.fromMap({
      'chat_id': chatId,
      'document': await MultipartFile.fromFile(
        document.path,
        filename: docName.isEmpty ? 'file.bin' : docName,
      ),
      // Trường "thumbnail" bắt buộc để Telegram gắn preview nhỏ cho document (đặc biệt file lớn).
      'thumbnail': await MultipartFile.fromFile(
        thumbnail.path,
        filename: thumbName.endsWith('.jpg') || thumbName.endsWith('.jpeg')
            ? thumbName
            : '$thumbName.jpg',
      ),
    });

    try {
      final res = await _telegramDio.post<Map<String, dynamic>>(
        url,
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': 'application/json'},
        ),
        onSendProgress: onSendProgress,
      );

      final data = res.data;
      if (data == null) {
        throw TelegramUploadException('Telegram trả body rỗng.');
      }
      if (data['ok'] != true) {
        final desc = data['description']?.toString() ?? 'Unknown error';
        throw TelegramUploadException('Telegram API: $desc');
      }
      return Map<String, dynamic>.from(data['result'] as Map);
    } on DioException catch (e, st) {
      _mapDioToRetryable(e, st);
    }
  }

  // -------------------------------------------------------------------------
  // 3) Parse Telegram + POST backend /api/items
  // -------------------------------------------------------------------------

  /// Luồng đầy đủ: thumbnail → Telegram → lưu DB backend (Dio đã gắn HMAC).
  ///
  /// [onUploadProgress]: tiến trình **upload lên Telegram** (0.0–1.0 khi [total] > 0).
  Future<TelegramUploadResult> uploadAndPersistItem({
    required File file,
    required bool isVideo,
    required String displayName,
    String? folderId,
    bool favorite = false,
    void Function(double progress01)? onUploadProgress,
  }) async {
    if (!_config.isUnlocked) {
      throw TelegramUploadException('Cấu hình chưa được mở khoá.');
    }

    File? thumb;
    try {
      thumb = await generateThumbnail(file, isVideo);

      void wrappedProgress(int sent, int total) {
        if (onUploadProgress == null) return;
        if (total <= 0) {
          onUploadProgress(0);
        } else {
          onUploadProgress(sent / total);
        }
      }

      final tgResult = await sendDocumentWithThumbnail(
        document: file,
        thumbnail: thumb,
        onSendProgress: wrappedProgress,
      );

      final ids = _parseTelegramDocumentIds(tgResult);
      final size = await file.length();

      final api = createAuthenticatedDio(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      );

      final body = <String, dynamic>{
        'name': displayName,
        'size': size,
        'type': isVideo ? 'VIDEO' : 'IMAGE',
        'telegramFileId': ids.fileId,
        'telegramThumbId': ids.thumbFileId,
        'favorite': favorite,
        if (folderId != null && folderId.isNotEmpty) 'folderId': folderId,
      };

      final persist = await api.post<Map<String, dynamic>>(
        '/api/items',
        data: body,
      );

      final item = persist.data;
      if (item == null) {
        throw TelegramUploadException('Backend trả body rỗng sau khi tạo item.');
      }
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        throw TelegramUploadException('Backend không trả id item.');
      }

      return TelegramUploadResult(
        telegramFileId: ids.fileId,
        telegramFileUniqueId: ids.fileUniqueId,
        telegramThumbId: ids.thumbFileId,
        backendItemId: id,
        name: displayName,
        size: size,
        isVideo: isVideo,
      );
    } on DioException catch (e, st) {
      _mapDioToRetryable(e, st);
    } finally {
      if (thumb != null) {
        try {
          if (await thumb.exists()) await thumb.delete();
        } catch (_) {
          // best-effort xoá cache
        }
      }
    }
  }

  /// Trích `file_id`, `file_unique_id` của document và `file_id` của thumbnail (PhotoSize).
  ({String fileId, String fileUniqueId, String thumbFileId}) _parseTelegramDocumentIds(
    Map<String, dynamic> result,
  ) {
    // sendDocument trả về object [Message] trực tiếp trong "result" — có trường top-level "document".
    final doc = result['document'];
    if (doc is! Map<String, dynamic>) {
      throw TelegramUploadException('Telegram result thiếu document (Message không chứa document?).');
    }
    final fileId = doc['file_id']?.toString();
    final unique = doc['file_unique_id']?.toString() ?? '';
    if (fileId == null || fileId.isEmpty) {
      throw TelegramUploadException('Telegram document thiếu file_id.');
    }

    String thumbId = '';
    final thumb = doc['thumbnail'];
    if (thumb is Map<String, dynamic>) {
      thumbId = thumb['file_id']?.toString() ?? '';
    }
    if (thumbId.isEmpty) {
      // Backend bắt buộc telegramThumbId — nếu Telegram không trả thumb, không thể đồng bộ DB.
      throw TelegramUploadException(
        'Telegram không trả thumbnail.file_id. Thử giảm kích thước file thumb hoặc định dạng JPEG chuẩn.',
      );
    }

    return (fileId: fileId, fileUniqueId: unique, thumbFileId: thumbId);
  }

  Never _mapDioToRetryable(DioException e, StackTrace st) {
    final t = e.type;
    if (t == DioExceptionType.connectionTimeout ||
        t == DioExceptionType.sendTimeout ||
        t == DioExceptionType.receiveTimeout ||
        t == DioExceptionType.connectionError) {
      Error.throwWithStackTrace(
        RetryableUploadException(RetryableUploadException.defaultMessage, cause: e),
        st,
      );
    }
    if (e.error is SocketException) {
      Error.throwWithStackTrace(
        RetryableUploadException(RetryableUploadException.defaultMessage, cause: e),
        st,
      );
    }
    Error.throwWithStackTrace(
      TelegramUploadException('Lỗi mạng / máy chủ: ${e.message}', cause: e),
      st,
    );
  }
}
