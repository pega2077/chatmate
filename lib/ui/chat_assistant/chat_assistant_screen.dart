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

class _ChatAssistantScreenState extends ConsumerState<ChatAssistantScreen> {
  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatNotifierProvider);
    final personas = ref.watch(personaNotifierProvider).value ?? [];
    final selectedId = ref.watch(selectedPersonaIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('回复助手'),
        actions: [
          if (personas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: personas.any((p) => p.id == selectedId)
                      ? selectedId
                      : personas.first.id,
                  hint: const Text('选择人设'),
                  items: personas
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: chat.isLoading
                      ? null
                      : (id) =>
                            ref.read(selectedPersonaIdProvider.notifier).select(id),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                '聊天上下文',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '导入截图后会自动 OCR，并用 AI 过滤整理成对话。可点气泡修改内容或切换身份。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                  OutlinedButton.icon(
                    onPressed: chat.isLoading
                        ? null
                        : () => ref
                              .read(chatNotifierProvider.notifier)
                              .addMessage(),
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('添加消息'),
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
              const SizedBox(height: 16),
              if (chat.messages.isEmpty)
                _EmptyConversationHint(
                  onPaste: chat.isLoading
                      ? null
                      : () => ref
                            .read(chatNotifierProvider.notifier)
                            .loadClipboard(),
                )
              else
                ...List.generate(chat.messages.length, (index) {
                  return _ConversationBubble(
                    index: index,
                    slice: chat.messages[index],
                    enabled: !chat.isLoading,
                    onEdit: () => _editMessage(context, index, chat.messages[index]),
                    onToggleSender: () {
                      final current = chat.messages[index].sender;
                      final next = current == MessageSender.me
                          ? MessageSender.peer
                          : MessageSender.me;
                      ref
                          .read(chatNotifierProvider.notifier)
                          .updateMessageSender(index, next);
                    },
                    onDelete: () => ref
                        .read(chatNotifierProvider.notifier)
                        .removeMessage(index),
                  );
                }),
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
            ColoredBox(
              color: const Color(0x66FFFFFF),
              child: LoadingIndicator(
                message: chat.loadingMessage ?? '正在处理…',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editMessage(
    BuildContext context,
    int index,
    ChatMessageSlice slice,
  ) async {
    final controller = TextEditingController(text: slice.text);
    MessageSender sender = slice.sender == MessageSender.unknown
        ? MessageSender.peer
        : slice.sender;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('编辑消息', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SegmentedButton<MessageSender>(
                    segments: const [
                      ButtonSegment(
                        value: MessageSender.peer,
                        label: Text('对方'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment(
                        value: MessageSender.me,
                        label: Text('我'),
                        icon: Icon(Icons.face_outlined),
                      ),
                    ],
                    selected: {sender},
                    onSelectionChanged: (set) {
                      setModalState(() => sender = set.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: '消息内容',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      final notifier = ref.read(chatNotifierProvider.notifier);
      notifier.updateMessageText(index, controller.text.trim());
      notifier.updateMessageSender(index, sender);
    }
    controller.dispose();
  }
}

class _EmptyConversationHint extends StatelessWidget {
  const _EmptyConversationHint({this.onPaste});

  final VoidCallback? onPaste;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '还没有对话',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '导入聊天截图，或从剪贴板粘贴一段上下文',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (onPaste != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.content_paste),
              label: const Text('读取剪贴板'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({
    required this.index,
    required this.slice,
    required this.enabled,
    required this.onEdit,
    required this.onToggleSender,
    required this.onDelete,
  });

  final int index;
  final ChatMessageSlice slice;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onToggleSender;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMe = slice.sender == MessageSender.me;
    final label = switch (slice.sender) {
      MessageSender.peer => '对方',
      MessageSender.me => '我',
      MessageSender.unknown => '未知',
    };
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isMe ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = isMe ? scheme.onPrimaryContainer : scheme.onSurface;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: bg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: enabled ? onEdit : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          isMe ? Icons.face_outlined : Icons.person_outline,
                          size: 16,
                        ),
                        label: Text(label),
                        onPressed: enabled ? onToggleSender : null,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '编辑',
                        onPressed: enabled ? onEdit : null,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: enabled ? onDelete : null,
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    child: Text(
                      slice.text.isEmpty ? '（空消息，点此编辑）' : slice.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: slice.text.isEmpty
                            ? scheme.onSurfaceVariant
                            : fg,
                        fontStyle: slice.text.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
