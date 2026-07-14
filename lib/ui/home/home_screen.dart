import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/persona.dart';
import '../../providers/persona_provider.dart';
import '../chat_assistant/chat_assistant_screen.dart';
import '../widgets/loading_indicator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personasAsync = ref.watch(personaNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ChatMate · 人设管理')),
      body: personasAsync.when(
        loading: () => const LoadingIndicator(message: '加载人设…'),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (personas) {
          if (personas.isEmpty) {
            return const Center(child: Text('还没有人设，点右下角添加一个吧'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final persona = personas[index];
              return _PersonaTile(
                persona: persona,
                onTap: () {
                  ref
                      .read(selectedPersonaIdProvider.notifier)
                      .select(persona.id);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChatAssistantScreen(),
                    ),
                  );
                },
                onDelete: () => ref
                    .read(personaNotifierProvider.notifier)
                    .deletePersona(persona.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonaSheet(context, ref),
        tooltip: '添加人设',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddPersonaSheet(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final promptCtrl = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
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
              Text('新建人设', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：职场太极大师',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: '描述',
                  hintText: '用户可见的简短说明',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptCtrl,
                decoration: const InputDecoration(
                  labelText: 'System Prompt',
                  hintText: '核心角色约束，将注入大模型',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty ||
                      promptCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('名称与 System Prompt 不能为空')),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await ref.read(personaNotifierProvider.notifier).addPersona(
            name: nameCtrl.text,
            description: descCtrl.text,
            systemPrompt: promptCtrl.text,
          );
    }

    nameCtrl.dispose();
    descCtrl.dispose();
    promptCtrl.dispose();
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.persona,
    required this.onTap,
    required this.onDelete,
  });

  final Persona persona;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    persona.name.isNotEmpty ? persona.name.characters.first : '?',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        persona.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (persona.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: persona.tags
                              .map(
                                (t) => Chip(
                                  label: Text(t),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
