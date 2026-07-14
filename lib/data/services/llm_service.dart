import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/prompt_templates.dart';
import '../models/chat_context.dart';
import '../models/reply_option.dart';

class LlmService {
  LlmService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.llmBaseUrl,
              connectTimeout: AppConstants.connectTimeout,
              receiveTimeout: AppConstants.receiveTimeout,
              headers: {
                'Content-Type': 'application/json',
                if (AppConstants.llmApiKey.isNotEmpty)
                  'Authorization': 'Bearer ${AppConstants.llmApiKey}',
              },
            ),
          );

  final Dio _dio;

  Future<ReplyResult> generateReplies({
    required String personaInstruction,
    required String contextText,
  }) async {
    if (AppConstants.llmApiKey.isEmpty) {
      return _mockReplies(contextText);
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: {
        'model': AppConstants.llmModel,
        'temperature': 0.8,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content': PromptTemplates.buildSystemPrompt(personaInstruction),
          },
          {
            'role': 'user',
            'content': PromptTemplates.buildUserPrompt(contextText),
          },
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
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
    return ReplyResult.fromJson(decoded);
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
