import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/ocr_config_store.dart';
import '../data/models/ocr_config.dart';
import '../data/services/aliyun_ocr_service.dart';
import '../data/services/local_ocr_service.dart';
import '../data/services/ocr_service.dart';

final ocrConfigProvider =
    NotifierProvider<OcrConfigNotifier, OcrConfig>(OcrConfigNotifier.new);

class OcrConfigNotifier extends Notifier<OcrConfig> {
  @override
  OcrConfig build() => OcrConfigStore.load();

  Future<void> save(OcrConfig config) async {
    final normalized = config.copyWith(
      accessKeyId: config.accessKeyId.trim(),
      accessKeySecret: config.accessKeySecret.trim(),
      endpoint: config.endpoint
          .trim()
          .replaceAll(RegExp(r'^https?://'), '')
          .replaceAll(RegExp(r'/+$'), ''),
    );
    await OcrConfigStore.save(normalized);
    state = normalized;
  }

  Future<void> reset() async {
    await OcrConfigStore.clear();
    state = OcrConfig.defaults();
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) {
  final config = ref.watch(ocrConfigProvider);
  switch (config.provider) {
    case OcrProvider.local:
      final service = LocalOcrService();
      ref.onDispose(() {
        service.dispose();
      });
      return service;
    case OcrProvider.aliyun:
      return AliyunOcrService(config: config);
  }
});
