enum MessageSender { peer, me, unknown }

class ChatMessageSlice {
  final String text;
  final MessageSender sender;
  final double timestampY; // 用于截图排序的 Y 轴坐标

  ChatMessageSlice({
    required this.text,
    required this.sender,
    required this.timestampY,
  });
}
