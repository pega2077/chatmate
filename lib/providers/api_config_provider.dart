import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/api_config_store.dart';
import '../data/models/api_config.dart';
import '../data/services/llm_service.dart';

final apiConfigProvider =
    NotifierProvider<ApiConfigNotifier, ApiConfig>(ApiConfigNotifier.new);

class ApiConfigNotifier extends Notifier<ApiConfig> {
  @override
  ApiConfig build() => ApiConfigStore.load();

  Future<void> save(ApiConfig config) async {
    final normalized = config.copyWith(
      baseUrl: config.baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      apiKey: config.apiKey.trim(),
      model: config.model.trim(),
    );
    await ApiConfigStore.save(normalized);
    state = normalized;
  }

  Future<void> reset() async {
    await ApiConfigStore.clear();
    state = ApiConfig.defaults();
  }
}

final llmServiceProvider = Provider<LlmService>((ref) {
  final config = ref.watch(apiConfigProvider);
  return LlmService(config: config);
});
