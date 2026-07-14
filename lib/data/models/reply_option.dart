/// AI 回复选项
class ReplyOption {
  final String label;
  final String text;

  const ReplyOption({required this.label, required this.text});

  factory ReplyOption.fromJson(Map<String, dynamic> json) {
    return ReplyOption(
      label: json['label'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

/// LLM 返回的结构化回复
class ReplyResult {
  final List<ReplyOption> options;

  const ReplyResult({required this.options});

  factory ReplyResult.fromJson(Map<String, dynamic> json) {
    final raw = json['options'] as List<dynamic>? ?? [];
    return ReplyResult(
      options: raw
          .map((e) => ReplyOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
