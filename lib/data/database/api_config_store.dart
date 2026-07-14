import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_config.dart';

/// API 配置本地缓存
class ApiConfigStore {
  ApiConfigStore._();

  static const String _key = 'chatmate_api_config';

  static SharedPreferences? _prefs;

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  static SharedPreferences get prefs {
    final p = _prefs;
    if (p == null) {
      throw StateError('ApiConfigStore 尚未初始化');
    }
    return p;
  }

  static ApiConfig load() {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return ApiConfig.defaults();
    }
    try {
      return ApiConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return ApiConfig.defaults();
    }
  }

  static Future<void> save(ApiConfig config) async {
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  static Future<void> clear() async {
    await prefs.remove(_key);
  }
}
