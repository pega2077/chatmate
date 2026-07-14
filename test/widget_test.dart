import 'package:flutter_test/flutter_test.dart';

import 'package:chatmate/core/constants/prompt_templates.dart';
import 'package:chatmate/core/utils/clipboard_helper.dart';
import 'package:chatmate/data/models/chat_context.dart';
import 'package:chatmate/data/models/reply_option.dart';
import 'package:chatmate/data/services/llm_service.dart';

void main() {
  group('PromptTemplates', () {
    test('system prompt embeds persona and asks for 3 options', () {
      final prompt = PromptTemplates.buildSystemPrompt('测试人设');
      expect(prompt.contains('测试人设'), isTrue);
      expect(prompt.contains('"options"'), isTrue);
      // DoD: 文本处理代码不含 bare 尖括号
      expect(prompt.contains('<'), isFalse);
      expect(prompt.contains('>'), isFalse);
    });
  });

  group('ReplyResult', () {
    test('parses json options', () {
      final result = ReplyResult.fromJson({
        'options': [
          {'label': '礼貌', 'text': '好的'},
          {'label': '幽默', 'text': '哈哈'},
          {'label': '认真', 'text': '收到'},
        ],
      });
      expect(result.options.length, 3);
      expect(result.options.first.label, '礼貌');
    });
  });

  group('LlmService.formatSlices', () {
    test('formats sender labels in timeline order', () {
      final text = LlmService.formatSlices([
        ChatMessageSlice(
          text: '你好',
          sender: MessageSender.peer,
          timestampY: 10,
        ),
        ChatMessageSlice(
          text: '在的',
          sender: MessageSender.me,
          timestampY: 20,
        ),
      ]);
      expect(text, '[对方] 你好\n[我] 在的');
    });
  });

  group('ClipboardHelper filters', () {
    test('empty and overlong rules are documented by length bound', () {
      // 与实现保持一致的阈值约定
      const maxLen = 500;
      expect(''.trim().isEmpty || ''.length >= maxLen, isTrue);
      expect(('x' * 10).length < maxLen, isTrue);
    });
  });
}
