import '../../core/constants/app_constants.dart';

/// LLM API 运行时配置
class ApiConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final int connectTimeoutSeconds;
  final int receiveTimeoutSeconds;

  const ApiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.connectTimeoutSeconds = 15,
    this.receiveTimeoutSeconds = 15,
  });

  factory ApiConfig.defaults() {
    return const ApiConfig(
      baseUrl: AppConstants.dartDefineBaseUrl,
      apiKey: AppConstants.dartDefineApiKey,
      model: AppConstants.dartDefineModel,
      connectTimeoutSeconds: 15,
      receiveTimeoutSeconds: 15,
    );
  }

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  Duration get connectTimeout => Duration(seconds: connectTimeoutSeconds);

  Duration get receiveTimeout => Duration(seconds: receiveTimeoutSeconds);

  ApiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    int? connectTimeoutSeconds,
    int? receiveTimeoutSeconds,
  }) {
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      connectTimeoutSeconds:
          connectTimeoutSeconds ?? this.connectTimeoutSeconds,
      receiveTimeoutSeconds:
          receiveTimeoutSeconds ?? this.receiveTimeoutSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'connectTimeoutSeconds': connectTimeoutSeconds,
    'receiveTimeoutSeconds': receiveTimeoutSeconds,
  };

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      baseUrl: json['baseUrl'] as String? ?? AppConstants.defaultLlmBaseUrl,
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? AppConstants.defaultLlmModel,
      connectTimeoutSeconds: json['connectTimeoutSeconds'] as int? ?? 15,
      receiveTimeoutSeconds: json['receiveTimeoutSeconds'] as int? ?? 15,
    );
  }
}
