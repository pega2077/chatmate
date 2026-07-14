import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants/prompt_templates.dart';
import '../models/api_config.dart';
import '../models/chat_context.dart';
import '../models/reply_option.dart';

class LlmService {
  LlmService({required ApiConfig config, Dio? dio})
    : _config = config,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.baseUrl,
              connectTimeout: config.connectTimeout,
              receiveTimeout: config.receiveTimeout,
              headers: {
                'Content-Type': 'application/json',
                if (config.hasApiKey)
                  'Authorization': 'Bearer ${config.apiKey}',
              },
            ),
          );

  final ApiConfig _config;
  final Dio _dio;

  Future<ReplyResult> generateReplies({
    required String personaInstruction,
    required String contextText,
  }) async {
    if (!_config.hasApiKey) {
      return _mockReplies(contextText);
    }

    final decoded = await _chatJson(
      system: PromptTemplates.buildSystemPrompt(personaInstruction),
      user: PromptTemplates.buildUserPrompt(contextText),
      temperature: 0.8,
    );
    return ReplyResult.fromJson(decoded);
  }

  /// 用 LLM 过滤、合并 OCR 噪音，整理为对话消息列表
  Future<List<ChatMessageSlice>> organizeOcrMessages({
    required List<ChatMessageSlice> rawSlices,
  }) async {
    final rawText = formatSlices(rawSlices);
    if (rawText.trim().isEmpty) return const [];

    if (!_config.hasApiKey) {
      return _mockOrganize(rawSlices);
    }

    final decoded = await _chatJson(
      system: PromptTemplates.buildOcrOrganizeSystemPrompt(),
      user: PromptTemplates.buildOcrOrganizeUserPrompt(rawText),
      temperature: 0.2,
    );

    final messages = decoded['messages'] as List<dynamic>? ?? [];
    final organized = <ChatMessageSlice>[];
    for (var i = 0; i < messages.length; i++) {
      final item = messages[i];
      if (item is! Map<String, dynamic>) continue;
      final slice = ChatMessageSlice.fromJson(item);
      if (slice.text.isEmpty) continue;
      organized.add(slice.copyWith(timestampY: i.toDouble()));
    }
    return organized.isNotEmpty ? organized : _mockOrganize(rawSlices);
  }

  Future<Map<String, dynamic>> _chatJson({
    required String system,
    required String user,
    double temperature = 0.7,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: {
        'model': _config.model,
        'temperature': temperature,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      },
    );

    final choices = response.data?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('LLM 返回为空');
    }

    final content =
        (choices.first as Map<String, dynamic>)['message']?['content']
            as String?;
    if (content == null || content.isEmpty) {
      throw StateError('LLM 内容为空');
    }

    final cleaned = _stripMarkdownFence(content);
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  /// 将 OCR 切片拼成可读上下文
  static String formatSlices(List<ChatMessageSlice> slices) {
    return slices
        .map((s) {
          final who = switch (s.sender) {
            MessageSender.peer => '对方',
            MessageSender.me => '我',
            MessageSender.unknown => '未知',
          };
          return '[$who] ${s.text}';
        })
        .join('\n');
  }

  /// 无 API Key 时简单合并相邻同发送者碎片
  List<ChatMessageSlice> _mockOrganize(List<ChatMessageSlice> raw) {
    if (raw.isEmpty) return const [];
    final merged = <ChatMessageSlice>[];
    for (final slice in raw) {
      final text = slice.text.trim();
      if (text.isEmpty) continue;
      if (merged.isNotEmpty &&
          merged.last.sender == slice.sender &&
          slice.sender != MessageSender.unknown) {
        final prev = merged.removeLast();
        merged.add(
          prev.copyWith(
            text: '${prev.text} $text',
            timestampY: prev.timestampY,
          ),
        );
      } else {
        merged.add(slice.copyWith(text: text));
      }
    }
    return merged;
  }

  String _stripMarkdownFence(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
    }
    return text.trim();
  }

  /// 无 API Key 时的本地演示数据，方便离线联调 UI
  ReplyResult _mockReplies(String contextText) {
    final snippet = contextText.length > 20
        ? '${contextText.substring(0, 20)}...'
        : contextText;
    return ReplyResult(
      options: [
        ReplyOption(label: '礼貌回应', text: '收到啦，我这边稍后再仔细看看～（关于：$snippet）'),
        ReplyOption(label: '幽默化解', text: '哈哈哈，这话题可以写进年度总结了，等我缓缓再回你！'),
        ReplyOption(label: '认真跟进', text: '明白你的意思了，我这就处理，有进展第一时间同步你。'),
      ],
    );
  }
}
