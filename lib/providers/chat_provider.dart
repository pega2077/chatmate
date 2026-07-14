import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/clipboard_helper.dart';
import '../core/utils/image_picker_helper.dart';
import '../data/models/chat_context.dart';
import '../data/models/persona.dart';
import '../data/models/reply_option.dart';
import '../data/services/llm_service.dart';
import '../data/services/ocr_service.dart';
import 'persona_provider.dart';

final chatNotifierProvider =
    NotifierProvider<ChatNotifier, ChatAssistantState>(ChatNotifier.new);

class ChatAssistantState {
  final String inputText;
  final List<ChatMessageSlice> ocrSlices;
  final List<ReplyOption> options;
  final bool isLoading;
  final String? error;

  const ChatAssistantState({
    this.inputText = '',
    this.ocrSlices = const [],
    this.options = const [],
    this.isLoading = false,
    this.error,
  });

  ChatAssistantState copyWith({
    String? inputText,
    List<ChatMessageSlice>? ocrSlices,
    List<ReplyOption>? options,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatAssistantState(
      inputText: inputText ?? this.inputText,
      ocrSlices: ocrSlices ?? this.ocrSlices,
      options: options ?? this.options,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatNotifier extends Notifier<ChatAssistantState> {
  final LlmService _llm = LlmService();
  final OcrService _ocr = OcrService();

  @override
  ChatAssistantState build() {
    ref.onDispose(() {
      _ocr.dispose();
    });
    return const ChatAssistantState();
  }

  Future<void> loadClipboard() async {
    final text = await ClipboardHelper.getLatestText();
    if (text != null) {
      state = state.copyWith(inputText: text, clearError: true);
    }
  }

  void setInputText(String text) {
    state = state.copyWith(inputText: text, clearError: true);
  }

  Future<void> importScreenshot() async {
    final bytes = await ImagePickerHelper.pickImageBytes();
    if (bytes == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final slices = await _ocr.processChatScreenshot(bytes);
      final formatted = LlmService.formatSlices(slices);
      state = state.copyWith(
        ocrSlices: slices,
        inputText: formatted.isNotEmpty ? formatted : state.inputText,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'OCR 识别失败：$e');
    }
  }

  Future<void> generateReplies() async {
    final context = state.inputText.trim();
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

    state = state.copyWith(isLoading: true, clearError: true, options: []);
    try {
      final result = await _llm.generateReplies(
        personaInstruction: persona.systemPrompt,
        contextText: context,
      );
      state = state.copyWith(isLoading: false, options: result.options);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '生成失败：$e');
    }
  }
}
