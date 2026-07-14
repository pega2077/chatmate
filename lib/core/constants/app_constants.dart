/// 默认常量；实际运行时以 SharedPreferences 中的 [ApiConfig] 为准。
class AppConstants {
  AppConstants._();

  static const String defaultLlmBaseUrl = 'https://api.openai.com/v1';
  static const String defaultLlmModel = 'gpt-4o-mini';

  /// 编译期注入可作为首次默认值
  static const String dartDefineBaseUrl = String.fromEnvironment(
    'LLM_BASE_URL',
    defaultValue: defaultLlmBaseUrl,
  );

  static const String dartDefineApiKey = String.fromEnvironment(
    'LLM_API_KEY',
    defaultValue: '',
  );

  static const String dartDefineModel = String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: defaultLlmModel,
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// 阿里云 OCR（RecognizeAdvanced）默认接入点
  static const String defaultAliyunOcrEndpoint =
      'ocr-api.cn-hangzhou.aliyuncs.com';

  static const String dartDefineAliyunAccessKeyId = String.fromEnvironment(
    'ALIYUN_ACCESS_KEY_ID',
    defaultValue: '',
  );

  static const String dartDefineAliyunAccessKeySecret = String.fromEnvironment(
    'ALIYUN_ACCESS_KEY_SECRET',
    defaultValue: '',
  );

  static const String dartDefineAliyunOcrEndpoint = String.fromEnvironment(
    'ALIYUN_OCR_ENDPOINT',
    defaultValue: defaultAliyunOcrEndpoint,
  );

  /// 常用预设（OpenAI 兼容接口）
  static const List<({String label, String baseUrl, String model})> presets = [
    (
      label: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
    ),
    (
      label: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      model: 'deepseek-chat',
    ),
    (
      label: '通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen-plus',
    ),
    (
      label: 'Moonshot',
      baseUrl: 'https://api.moonshot.cn/v1',
      model: 'moonshot-v1-8k',
    ),
  ];
}
