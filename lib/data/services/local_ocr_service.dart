import 'dart:typed_data';

import 'package:flutter_ocr_native/flutter_ocr_native.dart';

import '../models/chat_context.dart';
import 'ocr_service.dart';

/// 本地 OCR（flutter_ocr_native / Web Tesseract.js）
class LocalOcrService extends OcrService {
  LocalOcrService()
    : _reader = OcrReader(validateDocument: false, maskAadhaar: false);

  final OcrReader _reader;
  bool _languageReady = false;

  Future<void> _ensureChineseLanguage() async {
    if (_languageReady) return;
    await _reader.setLanguage(OcrLanguage.chineseSimplified);
    _languageReady = true;
  }

  @override
  Future<List<ChatMessageSlice>> processChatScreenshot(
    Uint8List imageBytes,
  ) async {
    await _ensureChineseLanguage();

    final OcrResult result = await _reader.readFromBytes(imageBytes);

    final words = <({String text, double left, double top, double right})>[];
    for (final TextBlock block in result.blocks) {
      for (final TextLine line in block.lines) {
        words.add((
          text: line.text,
          left: line.boundingBox.left,
          top: line.boundingBox.top,
          right: line.boundingBox.right,
        ));
      }
    }

    return buildSlicesFromWordBoxes(words);
  }

  @override
  Future<void> dispose() => _reader.dispose();
}
