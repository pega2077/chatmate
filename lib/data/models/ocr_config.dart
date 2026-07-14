import '../../core/constants/app_constants.dart';

/// OCR 服务提供方
enum OcrProvider {
  /// 本地 Tesseract / flutter_ocr_native
  local,

  /// 阿里云全文识别高精版 RecognizeAdvanced
  aliyun,
}

extension OcrProviderX on OcrProvider {
  String get label => switch (this) {
    OcrProvider.local => '本地 OCR',
    OcrProvider.aliyun => '阿里云 OCR',
  };

  String get storageValue => name;

  static OcrProvider fromStorage(String? value) {
    return OcrProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OcrProvider.local,
    );
  }
}

/// OCR 运行时配置
class OcrConfig {
  final OcrProvider provider;
  final String accessKeyId;
  final String accessKeySecret;
  final String endpoint;

  const OcrConfig({
    required this.provider,
    this.accessKeyId = '',
    this.accessKeySecret = '',
    this.endpoint = AppConstants.defaultAliyunOcrEndpoint,
  });

  factory OcrConfig.defaults() {
    return const OcrConfig(
      provider: OcrProvider.local,
      accessKeyId: AppConstants.dartDefineAliyunAccessKeyId,
      accessKeySecret: AppConstants.dartDefineAliyunAccessKeySecret,
      endpoint: AppConstants.dartDefineAliyunOcrEndpoint,
    );
  }

  bool get hasAliyunCredentials =>
      accessKeyId.trim().isNotEmpty && accessKeySecret.trim().isNotEmpty;

  OcrConfig copyWith({
    OcrProvider? provider,
    String? accessKeyId,
    String? accessKeySecret,
    String? endpoint,
  }) {
    return OcrConfig(
      provider: provider ?? this.provider,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      accessKeySecret: accessKeySecret ?? this.accessKeySecret,
      endpoint: endpoint ?? this.endpoint,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.storageValue,
    'accessKeyId': accessKeyId,
    'accessKeySecret': accessKeySecret,
    'endpoint': endpoint,
  };

  factory OcrConfig.fromJson(Map<String, dynamic> json) {
    return OcrConfig(
      provider: OcrProviderX.fromStorage(json['provider'] as String?),
      accessKeyId: json['accessKeyId'] as String? ?? '',
      accessKeySecret: json['accessKeySecret'] as String? ?? '',
      endpoint:
          json['endpoint'] as String? ?? AppConstants.defaultAliyunOcrEndpoint,
    );
  }
}
