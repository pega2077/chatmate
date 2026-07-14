/// API 与应用配置
///
/// 将 [llmApiKey] 替换为你的真实密钥；也可通过 `--dart-define=LLM_API_KEY=xxx` 注入。
class AppConstants {
  AppConstants._();

  /// OpenAI 兼容接口 Base URL（可换成 DeepSeek / 通义等）
  static const String llmBaseUrl = String.fromEnvironment(
    'LLM_BASE_URL',
    defaultValue: 'https://api.openai.com/v1',
  );

  static const String llmApiKey = String.fromEnvironment(
    'LLM_API_KEY',
    defaultValue: '',
  );

  static const String llmModel = String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: 'gpt-4o-mini',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
