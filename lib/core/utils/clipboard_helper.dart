import 'package:flutter/services.dart';

class ClipboardHelper {
  static Future<String?> getLatestText() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      // 过滤掉空白字符或过长文本（大于500字通常非单句聊天记录）
      final cleanText = data.text!.trim();
      if (cleanText.isNotEmpty && cleanText.length < 500) {
        return cleanText;
      }
    }
    return null;
  }

  static Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
