import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/persona.dart';

/// 基于 [SharedPreferences] 的人设本地缓存
class PersonaLocalStore {
  PersonaLocalStore._();

  static const String _personasKey = 'chatmate_personas';
  static const String _nextIdKey = 'chatmate_persona_next_id';

  static SharedPreferences? _prefs;

  static SharedPreferences get prefs {
    final p = _prefs;
    if (p == null) {
      throw StateError('本地缓存尚未初始化，请先调用 PersonaLocalStore.init()');
    }
    return p;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _seedDefaultsIfEmpty();
  }

  static Future<List<Persona>> loadAll() async {
    final raw = prefs.getString(_personasKey);
    if (raw == null || raw.isEmpty) return const [];

    final list = jsonDecode(raw) as List<dynamic>;
    final personas = list
        .map((e) => Persona.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    personas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return personas;
  }

  static Future<void> saveAll(List<Persona> personas) async {
    final encoded = jsonEncode(personas.map((e) => e.toJson()).toList());
    await prefs.setString(_personasKey, encoded);
  }

  static Future<Persona> add({
    required String name,
    required String description,
    required String systemPrompt,
    List<String> tags = const [],
  }) async {
    final list = await loadAll();
    final id = prefs.getInt(_nextIdKey) ?? 1;
    final persona = Persona(
      id: id,
      name: name.trim(),
      description: description.trim(),
      systemPrompt: systemPrompt.trim(),
      tags: tags,
      createdAt: DateTime.now(),
    );
    list.insert(0, persona);
    await saveAll(list);
    await prefs.setInt(_nextIdKey, id + 1);
    return persona;
  }

  static Future<void> delete(int id) async {
    final list = await loadAll();
    list.removeWhere((p) => p.id == id);
    await saveAll(list);
  }

  static Future<void> _seedDefaultsIfEmpty() async {
    final existing = prefs.getString(_personasKey);
    if (existing != null && existing.isNotEmpty) return;

    final now = DateTime.now();
    final defaults = [
      Persona(
        id: 1,
        name: '职场太极大师',
        description: '温和委婉，擅长化解职场冲突，语气得体不卑不亢。',
        systemPrompt: '你是职场沟通高手，回复要专业、克制、留有余地，避免情绪化表达。',
        tags: const ['Work', 'Diplomacy'],
        createdAt: now,
      ),
      Persona(
        id: 2,
        name: '幽默损友',
        description: '轻松吐槽但不伤人，适合朋友间的日常闲聊。',
        systemPrompt: '你是用户的幽默损友，回复要俏皮有梗，但绝不过分冒犯对方。',
        tags: const ['Humor', 'Friends'],
        createdAt: now,
      ),
      Persona(
        id: 3,
        name: '温柔倾听者',
        description: '共情、安抚、给出温和建议，适合情感向对话。',
        systemPrompt: '你是温柔的倾听者，优先表达理解与关心，再给出轻柔建议。',
        tags: const ['Empathy', 'Care'],
        createdAt: now,
      ),
    ];

    await saveAll(defaults);
    await prefs.setInt(_nextIdKey, 4);
  }
}
