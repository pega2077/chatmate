import 'dart:typed_data';

import 'package:flutter_ocr_native/flutter_ocr_native.dart';

import '../models/chat_context.dart';

class OcrService {
  OcrService() : _reader = OcrReader(validateDocument: false, maskAadhaar: false);

  final OcrReader _reader;
  bool _languageReady = false;

  Future<void> _ensureChineseLanguage() async {
    if (_languageReady) return;
    await _reader.setLanguage(OcrLanguage.chineseSimplified);
    _languageReady = true;
  }

  /// Web 必须走 [readFromBytes]；移动端同样可用字节流。
  Future<List<ChatMessageSlice>> processChatScreenshot(
    Uint8List imageBytes,
  ) async {
    await _ensureChineseLanguage();

    final OcrResult result = await _reader.readFromBytes(imageBytes);

    // 结合识别结果估算图片宽度，用于左右边界比例划分
    double imageWidth = 750;
    double maxRight = 0;
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final right = line.boundingBox.right;
        if (right > maxRight) maxRight = right;
      }
    }
    if (maxRight > 0) imageWidth = maxRight;

    final double peerThreshold = imageWidth * 0.45;
    final List<ChatMessageSlice> slices = [];

    // 通常：X 轴起始点偏左为对方；靠右为自己。
    for (final TextBlock block in result.blocks) {
      for (final TextLine line in block.lines) {
        final double x = line.boundingBox.left;
        final double y = line.boundingBox.top;

        final MessageSender sender;
        if (x < peerThreshold) {
          sender = MessageSender.peer;
        } else {
          sender = MessageSender.me;
        }

        slices.add(
          ChatMessageSlice(text: line.text, sender: sender, timestampY: y),
        );
      }
    }

    // 基于 Y 轴从上到下严格排序，恢复聊天时间线
    slices.sort((a, b) => a.timestampY.compareTo(b.timestampY));
    return slices;
  }

  Future<void> dispose() => _reader.dispose();
}
