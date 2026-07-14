import 'dart:typed_data';

import '../models/chat_context.dart';

/// OCR 服务抽象：将聊天截图识别为带左右归属的文本切片
abstract class OcrService {
  Future<List<ChatMessageSlice>> processChatScreenshot(Uint8List imageBytes);

  Future<void> dispose() async {}
}

/// 根据文字块左右位置推断对方 / 我，并按 Y 轴排序
List<ChatMessageSlice> buildSlicesFromWordBoxes(
  Iterable<({String text, double left, double top, double right})> words,
) {
  double imageWidth = 750;
  double maxRight = 0;
  for (final w in words) {
    if (w.right > maxRight) maxRight = w.right;
  }
  if (maxRight > 0) imageWidth = maxRight;

  final peerThreshold = imageWidth * 0.45;
  final slices = <ChatMessageSlice>[];

  for (final w in words) {
    if (w.text.trim().isEmpty) continue;
    slices.add(
      ChatMessageSlice(
        text: w.text,
        sender: w.left < peerThreshold ? MessageSender.peer : MessageSender.me,
        timestampY: w.top,
      ),
    );
  }

  slices.sort((a, b) => a.timestampY.compareTo(b.timestampY));
  return slices;
}
