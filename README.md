

# Flutter MVP 开发方案：智能聊天回复助手

## 1. 核心技术架构与技术栈

Agent 在生成代码时，必须严格基于以下技术栈及版本约束：

* **Flutter SDK**: `^3.22.0` (或当前 2026 年稳定版)
* **状态管理**: `flutter_riverpod` + `riverpod_annotation`（强类型、编译期安全）
* **本地数据库**: `isar`（高性能、支持异步/多线程，用于存储自定义人设与历史记录）
* **OCR 引擎**: `google_mlkit_text_recognition`（端侧低延迟文本识别）
* **网络请求**: `dio`（支持拦截器，用于对接大模型 API）


## 2. 核心数据模型声明 (Data Schemas)

Agent 须在 `lib/data/models/` 目录下生成以下符合 Isar 规范的 Dart 模型：

### 2.1 人设模型 (`persona.dart`)

```dart
import 'package:isar/isar.dart';

part 'persona.g.dart';

@collection
class Persona {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true)
  late String name;         // 人设名称，如“职场太极大师”
  late String description;  // 用户可见的人设描述
  late String systemPrompt; // 核心 Prompt 约束
  late List<String> tags;   // 标签，如 ['Work', 'Humor']
  late DateTime createdAt;
}

```

### 2.2 上下文消息切片模型 (`chat_context.dart`)

```dart
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

```



## 3. 标准目录结构 (Directory Topology)

请 Agent 按照以下规范初始化项目骨架：

```text
lib/
├── main.dart
├── core/
│   ├── constants/       # API 密钥配置及 Prompt 模板
│   ├── theme/           # 极简 UI 主题
│   └── utils/           # 剪贴板监听器、图片选择器封装
├── data/
│   ├── database/        # Isar 初始化及持久化
│   ├── models/          # 实体模型 (Persona)
│   └── services/        # LLM API 服务、Google ML Kit OCR 服务
├── providers/           # Riverpod 状态提供者 (PersonaNotifier, ChatNotifier)
└── ui/
    ├── home/            # 主界面（人设管理）
    ├── chat_assistant/  # 回复生成交互面板（支持输入文本或导入截图）
    └── widgets/         # 通用轻量组件（回复卡片、加载动画）

```



## 4. 核心管道与核心代码实现规约

### 管道 A：剪贴板监听与上下文捕获

Agent 需实现一个常驻的后台或生命周期内监听器。当应用前台唤醒或检测到剪贴板变动时，自动将内容填充至分析队列。

```dart
// lib/core/utils/clipboard_helper.dart
import 'package:flutter/services.dart';

class ClipboardHelper {
  static Future<String?> getLatestText() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      // 过滤掉空白字符或过长文本（大于500字通常非单句聊天记录）
      final cleanText = data.text!.trim();
      if (cleanText.isNotEmpty && cleanText.length < 500) {
        return cleanText;
      }
    }
    return null;
  }
}

```

### 管道 B：截图 OCR 区域自适应识别算法

在处理图片识别时，Agent **必须**通过 bounding box 的相对 $X$ 坐标，逻辑判定消息发送方（左侧为 `peer`，右侧为 `me`）。

```dart
// lib/data/services/ocr_service.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/chat_context.dart';

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  Future<List<ChatMessageSlice>> processChatScreenshot(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    
    List<ChatMessageSlice> slices = [];
    
    // 假设标准屏幕宽度（用于计算左右边界比例）
    // 实际生产中可结合图片元数据图片的 width 进行比例划分
    // 通常：X 轴起始点在左侧 0%~60% 区间且长度不超过一定比例的为对方；靠右侧的为自己。
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final double x = line.boundingBox.left;
        final double y = line.boundingBox.top;
        
        MessageSender sender = MessageSender.unknown;
        // 简易动态阈值算法：根据 X 轴坐标判定角色
        if (x < 300) { 
          sender = MessageSender.peer;
        } else {
          sender = MessageSender.me;
        }

        slices.add(ChatMessageSlice(
          text: line.text,
          sender: sender,
          timestampY: y,
        ));
      }
    }

    // 极其重要：基于 Y 轴从上到下严格排序，恢复聊天时间线
    slices.sort((a, b) => a.timestampY.compareTo(b.timestampY));
    return slices;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

```

### 管道 C：大模型提示词融合器 (Prompt Engineering)

Agent 必须内置以下通用模板，保证大模型能够稳定输出结构化的 3 种回复：

```dart
// lib/core/constants/prompt_templates.dart
class PromptTemplates {
  static String buildSystemPrompt(String personaInstruction) {
    return '''
你是一个智能聊天助手。你的核心任务是帮用户回复社交软件上的消息。
你当前扮演的角色设定如下：
$personaInstruction

请严格遵守以下规则：
1. 分析用户输入的聊天上下文（可能是单句话，也可能是按时间排序的多句对话）。
2. 基于你的角色设定，生成 3 个不同维度的回复选项。
3. 请严格按照给定的 JSON 格式输出，不要包含任何 markdown 标记（如 ```json）或任何额外的解释性文字。

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
}

```



## 5. UI 交互层实现指令 (UI Directives)

Agent 需要在 `lib/ui/` 下实现两个核心页面：

1. **HomeScreen (人设管理中心)**:
* 主列表采用 `ListView.builder` 渲染 Isar 数据库中读取的 `Persona` 列表。
* 提供全局浮动操作按钮（FAB）用于快速添加自定义 System Prompt。


2. **ChatAssistantScreen (回复生成面板)**:
* **顶部输入框**：默认自动读取并展示 `ClipboardHelper.getLatestText()` 的内容。
* **快捷按钮栏**：提供 `[导入截图识别]` 按钮，触发 `image_picker` 选择图片后，交由 `OcrService` 处理，处理后以列表形式在界面上预览被提取出的上下文。
* **底部结果区**：展示 AI 生成的 3 个选项卡片。**点击任意卡片，触发 `Clipboard.setData` 将文本写回剪贴板，并调用 `ScaffoldMessenger` 弹出 Toast 提示用户“已复制，快去粘贴吧！”**。





## 6. Agent 检查清单 (Agent Definition of Done)

在完成代码生成后，Agent 需自我运行以下断言：

1. [ ] 所有对文本处理的代码均无 bare `<` 或 `>` 符号，防止编译期布局解析错误。
2. [ ] 在 `OcrService` 结束时已正确解构并闭合 `TextRecognizer` 实例，无内存泄漏隐患。
3. [ ] 网络层 Dio 请求已配置 `connectTimeout` 与 `receiveTimeout`（推荐 15 秒限制）。
