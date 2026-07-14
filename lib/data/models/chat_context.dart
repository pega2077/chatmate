enum MessageSender { peer, me, unknown }

class ChatMessageSlice {
  final String text;
  final MessageSender sender;
  final double timestampY; // 用于截图排序的 Y 轴坐标

  ChatMessageSlice({
    required this.text,
    required this.sender,
    this.timestampY = 0,
  });

  ChatMessageSlice copyWith({
    String? text,
    MessageSender? sender,
    double? timestampY,
  }) {
    return ChatMessageSlice(
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestampY: timestampY ?? this.timestampY,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'sender': sender.name,
    'timestampY': timestampY,
  };

  factory ChatMessageSlice.fromJson(Map<String, dynamic> json) {
    final senderRaw = (json['sender'] as String? ?? 'unknown').toLowerCase();
    final sender = switch (senderRaw) {
      'me' || '我' || 'self' || 'user' => MessageSender.me,
      'peer' || '对方' || 'other' || 'them' => MessageSender.peer,
      _ => MessageSender.unknown,
    };
    return ChatMessageSlice(
      text: (json['text'] as String? ?? '').trim(),
      sender: sender,
      timestampY: (json['timestampY'] as num?)?.toDouble() ?? 0,
    );
  }
}
