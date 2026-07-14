import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/aliyun_acs3_signer.dart';
import '../models/chat_context.dart';
import '../models/ocr_config.dart';
import 'ocr_service.dart';

/// 阿里云 OCR：RecognizeAdvanced（全文识别高精版）
class AliyunOcrService extends OcrService {
  AliyunOcrService({required this.config});

  final OcrConfig config;

  static const String _action = 'RecognizeAdvanced';
  static const String _version = '2021-07-07';

  @override
  Future<List<ChatMessageSlice>> processChatScreenshot(
    Uint8List imageBytes,
  ) async {
    if (!config.hasAliyunCredentials) {
      throw StateError('请先在设置中填写阿里云 AccessKey ID / Secret');
    }

    final host = config.endpoint.trim().replaceAll(RegExp(r'^https?://'), '');
    final queryParams = <String, String>{
      // 从上到下、从左到右，更贴近聊天时间线
      'NeedSortPage': 'true',
    };

    final headers = AliyunAcs3Signer.signHeaders(
      accessKeyId: config.accessKeyId.trim(),
      accessKeySecret: config.accessKeySecret.trim(),
      host: host,
      action: _action,
      version: _version,
      httpMethod: 'POST',
      canonicalUri: '/',
      queryParams: queryParams,
      body: imageBytes,
      contentType: 'application/octet-stream',
    );

    final query = AliyunAcs3Signer.canonicalQueryString(queryParams);
    final url = query.isEmpty ? 'https://$host/' : 'https://$host/?$query';

    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
    );

    final response = await dio.post<dynamic>(
      url,
      data: imageBytes,
      options: Options(
        headers: {
          ...headers,
          Headers.contentLengthHeader: imageBytes.length,
        },
        contentType: 'application/octet-stream',
      ),
    );

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status < 200 || status >= 300) {
      final message = _extractErrorMessage(data) ?? 'HTTP $status';
      throw StateError('阿里云 OCR 请求失败：$message');
    }

    if (data is! Map) {
      throw StateError('阿里云 OCR 返回格式异常');
    }

    final map = Map<String, dynamic>.from(data);
    if (map['Code'] != null) {
      throw StateError(
        '阿里云 OCR 错误：${map['Code']} ${map['Message'] ?? ''}'.trim(),
      );
    }

    final rawData = map['Data'];
    if (rawData is! String || rawData.isEmpty) {
      throw StateError('阿里云 OCR 未返回识别数据');
    }

    final parsed = jsonDecode(rawData);
    if (parsed is! Map) {
      throw StateError('阿里云 OCR Data 解析失败');
    }

    return _slicesFromAliyunData(Map<String, dynamic>.from(parsed));
  }

  List<ChatMessageSlice> _slicesFromAliyunData(Map<String, dynamic> data) {
    final wordsInfo = data['prism_wordsInfo'];
    if (wordsInfo is! List || wordsInfo.isEmpty) {
      final content = data['content'] as String? ?? '';
      if (content.trim().isEmpty) return const [];
      return [
        ChatMessageSlice(
          text: content.trim(),
          sender: MessageSender.unknown,
          timestampY: 0,
        ),
      ];
    }

    final words = <({String text, double left, double top, double right})>[];
    for (final item in wordsInfo) {
      if (item is! Map) continue;
      final wordMap = Map<String, dynamic>.from(item);
      final text = (wordMap['word'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;

      final pos = wordMap['pos'];
      double left = 0;
      double top = 0;
      double right = 0;
      if (pos is List && pos.isNotEmpty) {
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = 0;
        for (final p in pos) {
          if (p is! Map) continue;
          final x = (p['x'] as num?)?.toDouble() ?? 0;
          final y = (p['y'] as num?)?.toDouble() ?? 0;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
        }
        if (minX != double.infinity) {
          left = minX;
          top = minY;
          right = maxX;
        }
      } else {
        left = (wordMap['x'] as num?)?.toDouble() ?? 0;
        top = (wordMap['y'] as num?)?.toDouble() ?? 0;
        right = left + ((wordMap['width'] as num?)?.toDouble() ?? 0);
      }

      words.add((text: text, left: left, top: top, right: right));
    }

    return buildSlicesFromWordBoxes(words);
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final code = data['Code'] ?? data['code'];
      final message = data['Message'] ?? data['message'];
      if (code != null || message != null) {
        return '${code ?? ''} ${message ?? ''}'.trim();
      }
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}
