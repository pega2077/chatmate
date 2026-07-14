import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/clipboard_helper.dart';
import '../../data/models/chat_context.dart';
import '../../providers/chat_provider.dart';
import '../../providers/persona_provider.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/reply_card.dart';

class ChatAssistantScreen extends ConsumerStatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  ConsumerState<ChatAssistantScreen> createState() =>
      _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends ConsumerState<ChatAssistantScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatNotifierProvider.notifier).loadClipboard();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 前台唤醒时自动读取剪贴板，填充分析队列
    if (state == AppLifecycleState.resumed) {
      ref.read(chatNotifierProvider.notifier).loadClipboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatNotifierProvider);
    final personas = ref.watch(personaNotifierProvider).value ?? [];
    final selectedId = ref.watch(selectedPersonaIdProvider);
    String? selectedName;
    for (final p in personas) {
      if (p.id == selectedId) {
        selectedName = p.name;
        break;
      }
    }

    // 同步 controller，避免与 Riverpod state 脱节
    if (_inputController.text != chat.inputText) {
      _inputController.value = TextEditingValue(
        text: chat.inputText,
        selection: TextSelection.collapsed(offset: chat.inputText.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedName == null ? '回复助手' : '回复助手 · $selectedName'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextField(
                controller: _inputController,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '聊天上下文',
                  hintText: '粘贴对话，或点击下方导入截图识别',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) =>
                    ref.read(chatNotifierProvider.notifier).setInputText(v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: chat.isLoading
                        ? null
                        : () => ref
                              .read(chatNotifierProvider.notifier)
                              .importScreenshot(),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('导入截图识别'),
                  ),
                  OutlinedButton.icon(
                    onPressed: chat.isLoading
                        ? null
                        : () => ref
                              .read(chatNotifierProvider.notifier)
                              .loadClipboard(),
                    icon: const Icon(Icons.content_paste),
                    label: const Text('读取剪贴板'),
                  ),
                  FilledButton.icon(
                    onPressed: chat.isLoading
                        ? null
                        : () => ref
                              .read(chatNotifierProvider.notifier)
                              .generateReplies(),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('生成回复'),
                  ),
                ],
              ),
              if (chat.ocrSlices.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'OCR 识别预览',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...chat.ocrSlices.map((s) => _OcrSliceTile(slice: s)),
              ],
              if (chat.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  chat.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (chat.options.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'AI 回复选项',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...chat.options.map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReplyCard(
                      option: opt,
                      onTap: () async {
                        await ClipboardHelper.copyText(opt.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已复制，快去粘贴吧！'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (chat.isLoading)
            const ColoredBox(
              color: Color(0x66FFFFFF),
              child: LoadingIndicator(message: '正在处理…'),
            ),
        ],
      ),
    );
  }
}

class _OcrSliceTile extends StatelessWidget {
  const _OcrSliceTile({required this.slice});

  final ChatMessageSlice slice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (slice.sender) {
      MessageSender.peer => '对方',
      MessageSender.me => '我',
      MessageSender.unknown => '未知',
    };
    final align = slice.sender == MessageSender.me
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bg = slice.sender == MessageSender.me
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('[$label] ${slice.text}'),
      ),
    );
  }
}
