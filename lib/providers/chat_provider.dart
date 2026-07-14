import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/clipboard_helper.dart';
import '../core/utils/image_picker_helper.dart';
import '../data/models/chat_context.dart';
import '../data/models/persona.dart';
import '../data/models/reply_option.dart';
import '../data/services/llm_service.dart';
import 'api_config_provider.dart';
import 'ocr_config_provider.dart';
import 'persona_provider.dart';

final chatNotifierProvider =
    NotifierProvider<ChatNotifier, ChatAssistantState>(ChatNotifier.new);

class ChatAssistantState {
  final String inputText;
  final List<ChatMessageSlice> messages;
  final List<ReplyOption> options;
  final bool isLoading;
  final String? loadingMessage;
  final String? error;

  const ChatAssistantState({
    this.inputText = '',
    this.messages = const [],
    this.options = const [],
    this.isLoading = false,
    this.loadingMessage,
    this.error,
  });

  ChatAssistantState copyWith({
    String? inputText,
    List<ChatMessageSlice>? messages,
    List<ReplyOption>? options,
    bool? isLoading,
    String? loadingMessage,
    String? error,
    bool clearError = false,
    bool clearLoadingMessage = false,
  }) {
    return ChatAssistantState(
      inputText: inputText ?? this.inputText,
      messages: messages ?? this.messages,
      options: options ?? this.options,
      isLoading: isLoading ?? this.isLoading,
      loadingMessage: clearLoadingMessage
          ? null
          : (loadingMessage ?? this.loadingMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatNotifier extends Notifier<ChatAssistantState> {
  @override
  ChatAssistantState build() => const ChatAssistantState();

  Future<void> loadClipboard() async {
    final text = await ClipboardHelper.getLatestText();
    if (text == null || text.trim().isEmpty) return;
    state = state.copyWith(
      inputText: text,
      messages: [
        ChatMessageSlice(text: text.trim(), sender: MessageSender.peer),
      ],
      clearError: true,
    );
  }

  void setInputText(String text) {
    state = state.copyWith(inputText: text, clearError: true);
  }

  void updateMessageText(int index, String text) {
    if (index < 0 || index >= state.messages.length) return;
    final next = [...state.messages];
    next[index] = next[index].copyWith(text: text);
    state = state.copyWith(
      messages: next,
      inputText: LlmService.formatSlices(next),
      clearError: true,
    );
  }

  void updateMessageSender(int index, MessageSender sender) {
    if (index < 0 || index >= state.messages.length) return;
    final next = [...state.messages];
    next[index] = next[index].copyWith(sender: sender);
    state = state.copyWith(
      messages: next,
      inputText: LlmService.formatSlices(next),
      clearError: true,
    );
  }

  void removeMessage(int index) {
    if (index < 0 || index >= state.messages.length) return;
    final next = [...state.messages]..removeAt(index);
    state = state.copyWith(
      messages: next,
      inputText: LlmService.formatSlices(next),
      clearError: true,
    );
  }

  void addMessage({
    MessageSender sender = MessageSender.peer,
    String text = '',
  }) {
    final next = [...state.messages, ChatMessageSlice(text: text, sender: sender)];
    state = state.copyWith(
      messages: next,
      inputText: LlmService.formatSlices(next),
      clearError: true,
    );
  }

  Future<void> importScreenshot() async {
    final bytes = await ImagePickerHelper.pickImageBytes();
    if (bytes == null) return;

    state = state.copyWith(
      isLoading: true,
      loadingMessage: '正在识别截图…',
      clearError: true,
    );
    try {
      final rawSlices = await ref
          .read(ocrServiceProvider)
          .processChatScreenshot(bytes);

      state = state.copyWith(loadingMessage: '正在整理对话…');
      final organized = await ref
          .read(llmServiceProvider)
          .organizeOcrMessages(rawSlices: rawSlices);

      final formatted = LlmService.formatSlices(organized);
      state = state.copyWith(
        messages: organized,
        inputText: formatted.isNotEmpty ? formatted : state.inputText,
        isLoading: false,
        clearLoadingMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        error: '识别/整理失败：$e',
      );
    }
  }

  Future<void> generateReplies() async {
    final context = state.messages.isNotEmpty
        ? LlmService.formatSlices(state.messages)
        : state.inputText.trim();
    if (context.isEmpty) {
      state = state.copyWith(error: '请先输入或导入聊天上下文');
      return;
    }

    final personasAsync = ref.read(personaNotifierProvider);
    final personas = personasAsync.value ?? const <Persona>[];
    final selectedId = ref.read(selectedPersonaIdProvider);

    final Persona persona;
    if (personas.isEmpty) {
      persona = Persona(
        id: 0,
        name: '默认',
        description: '',
        systemPrompt: '你是一个友好的聊天助手。',
        tags: const [],
        createdAt: DateTime.now(),
      );
    } else {
      persona = personas.firstWhere(
        (p) => p.id == selectedId,
        orElse: () => personas.first,
      );
    }

    state = state.copyWith(
      isLoading: true,
      loadingMessage: '正在生成回复…',
      clearError: true,
      options: [],
      inputText: context,
    );
    try {
      final result = await ref.read(llmServiceProvider).generateReplies(
        personaInstruction: persona.systemPrompt,
        contextText: context,
      );
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        options: result.options,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearLoadingMessage: true,
        error: '生成失败：$e',
      );
    }
  }
}
