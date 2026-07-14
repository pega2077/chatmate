import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ocr_config.dart';

/// OCR 配置本地缓存
class OcrConfigStore {
  OcrConfigStore._();

  static const String _key = 'chatmate_ocr_config';

  static SharedPreferences? _prefs;

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  static SharedPreferences get prefs {
    final p = _prefs;
    if (p == null) {
      throw StateError('OcrConfigStore 尚未初始化');
    }
    return p;
  }

  static OcrConfig load() {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return OcrConfig.defaults();
    }
    try {
      return OcrConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return OcrConfig.defaults();
    }
  }

  static Future<void> save(OcrConfig config) async {
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  static Future<void> clear() async {
    await prefs.remove(_key);
  }
}
