class PromptTemplates {
  static String buildSystemPrompt(String personaInstruction) {
    return '''
你是一个智能聊天助手。你的核心任务是帮用户回复社交软件上的消息。
你当前扮演的角色设定如下：
$personaInstruction

请严格遵守以下规则：
1. 分析用户输入的聊天上下文（可能是单句话，也可能是按时间排序的多句对话）。
2. 基于你的角色设定，生成 3 个不同维度的回复选项。
3. 请严格按照给定的 JSON 格式输出，不要包含任何 markdown 标记（如 json 代码块）或任何额外的解释性文字。

期望的输出格式（JSON）：
{
  "options": [
    {"label": "选项一简短意图描述", "text": "具体回复的文字内容"},
    {"label": "选项二简短意图描述", "text": "具体回复的文字内容"},
    {"label": "选项三简短意图描述", "text": "具体回复的文字内容"}
  ]
}
''';
  }

  static String buildUserPrompt(String context) {
    return '以下是需要回复的聊天上下文：\n$context\n\n请生成 3 个回复选项。';
  }

  /// 将 OCR 原始结果整理为干净的对话消息
  static String buildOcrOrganizeSystemPrompt() {
    return '''
你是聊天截图 OCR 结果整理助手。用户会提供从社交软件截图识别出的原始文本（可能含噪音、碎片、错位）。

请完成：
1. 过滤无关内容：状态栏、时间、电量、导航栏、按钮文案（如发送/相册）、重复昵称标题、纯装饰符号等。
2. 合并同一气泡被拆碎的多行文字，还原为完整消息。
3. 修正明显的 OCR 错别字（仅在非常确定时），不要臆造原图没有的内容。
4. 按对话时间顺序输出；sender 只能是 "peer"（对方）或 "me"（我）。
5. 若无法判断归属，根据上下文合理推断；实在无法判断时用 "peer"。
6. 只输出 JSON，不要 markdown 代码块或额外说明。

期望输出格式：
{
  "messages": [
    {"sender": "peer", "text": "对方说的话"},
    {"sender": "me", "text": "我说的话"}
  ]
}
''';
  }

  static String buildOcrOrganizeUserPrompt(String rawOcrText) {
    return '以下是 OCR 原始识别结果，请过滤并整理成对话：\n\n$rawOcrText';
  }
}
