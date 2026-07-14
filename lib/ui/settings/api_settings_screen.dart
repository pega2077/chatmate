import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/api_config.dart';
import '../../data/models/ocr_config.dart';
import '../../providers/api_config_provider.dart';
import '../../providers/ocr_config_provider.dart';

class ApiSettingsScreen extends ConsumerStatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  ConsumerState<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends ConsumerState<ApiSettingsScreen> {
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _connectTimeoutCtrl;
  late final TextEditingController _receiveTimeoutCtrl;

  late final TextEditingController _akIdCtrl;
  late final TextEditingController _akSecretCtrl;
  late final TextEditingController _ocrEndpointCtrl;

  late OcrProvider _ocrProvider;
  bool _obscureKey = true;
  bool _obscureAkSecret = true;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(apiConfigProvider);
    _baseUrlCtrl = TextEditingController(text: config.baseUrl);
    _apiKeyCtrl = TextEditingController(text: config.apiKey);
    _modelCtrl = TextEditingController(text: config.model);
    _connectTimeoutCtrl = TextEditingController(
      text: '${config.connectTimeoutSeconds}',
    );
    _receiveTimeoutCtrl = TextEditingController(
      text: '${config.receiveTimeoutSeconds}',
    );

    final ocr = ref.read(ocrConfigProvider);
    _ocrProvider = ocr.provider;
    _akIdCtrl = TextEditingController(text: ocr.accessKeyId);
    _akSecretCtrl = TextEditingController(text: ocr.accessKeySecret);
    _ocrEndpointCtrl = TextEditingController(text: ocr.endpoint);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _connectTimeoutCtrl.dispose();
    _receiveTimeoutCtrl.dispose();
    _akIdCtrl.dispose();
    _akSecretCtrl.dispose();
    _ocrEndpointCtrl.dispose();
    super.dispose();
  }

  ApiConfig _buildApiFromFields() {
    return ApiConfig(
      baseUrl: _baseUrlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      connectTimeoutSeconds:
          int.tryParse(_connectTimeoutCtrl.text.trim()) ?? 15,
      receiveTimeoutSeconds:
          int.tryParse(_receiveTimeoutCtrl.text.trim()) ?? 15,
    );
  }

  OcrConfig _buildOcrFromFields() {
    return OcrConfig(
      provider: _ocrProvider,
      accessKeyId: _akIdCtrl.text.trim(),
      accessKeySecret: _akSecretCtrl.text.trim(),
      endpoint: _ocrEndpointCtrl.text.trim().isEmpty
          ? AppConstants.defaultAliyunOcrEndpoint
          : _ocrEndpointCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    final config = _buildApiFromFields();
    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base URL 与模型名称不能为空')),
      );
      return;
    }

    final ocr = _buildOcrFromFields();
    if (ocr.provider == OcrProvider.aliyun && !ocr.hasAliyunCredentials) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('使用阿里云 OCR 时请填写 AccessKey ID 与 Secret')),
      );
      return;
    }

    await ref.read(apiConfigProvider.notifier).save(config);
    await ref.read(ocrConfigProvider.notifier).save(ocr);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reset() async {
    await ref.read(apiConfigProvider.notifier).reset();
    await ref.read(ocrConfigProvider.notifier).reset();
    final config = ref.read(apiConfigProvider);
    final ocr = ref.read(ocrConfigProvider);
    setState(() {
      _baseUrlCtrl.text = config.baseUrl;
      _apiKeyCtrl.text = config.apiKey;
      _modelCtrl.text = config.model;
      _connectTimeoutCtrl.text = '${config.connectTimeoutSeconds}';
      _receiveTimeoutCtrl.text = '${config.receiveTimeoutSeconds}';
      _ocrProvider = ocr.provider;
      _akIdCtrl.text = ocr.accessKeyId;
      _akSecretCtrl.text = ocr.accessKeySecret;
      _ocrEndpointCtrl.text = ocr.endpoint;
      _testMessage = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已恢复默认配置'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testConnection() async {
    final config = _buildApiFromFields();
    if (config.baseUrl.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = '请先填写 Base URL';
      });
      return;
    }

    setState(() {
      _testing = true;
      _testMessage = null;
    });

    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl.replaceAll(RegExp(r'/+$'), ''),
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          if (config.hasApiKey) 'Authorization': 'Bearer ${config.apiKey}',
        },
      ),
    );

    try {
      try {
        await dio.get('/models');
      } on DioException catch (_) {
        await dio.post(
          '/chat/completions',
          data: {
            'model': config.model.isEmpty
                ? AppConstants.defaultLlmModel
                : config.model,
            'messages': [
              {'role': 'user', 'content': 'ping'},
            ],
            'max_tokens': 1,
          },
        );
      }
      setState(() {
        _testOk = true;
        _testMessage = '连接成功';
      });
    } on DioException catch (e) {
      setState(() {
        _testOk = false;
        _testMessage = '连接失败：${e.message ?? e.type.name}';
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testMessage = '连接失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  void _applyPreset(({String label, String baseUrl, String model}) preset) {
    setState(() {
      _baseUrlCtrl.text = preset.baseUrl;
      _modelCtrl.text = preset.model;
      _testMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(onPressed: _reset, child: const Text('重置')),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('大模型 API', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('服务商预设', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.presets
                .map(
                  (p) => ActionChip(
                    label: Text(p.label),
                    onPressed: () => _applyPreset(p),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _baseUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.openai.com/v1',
              helperText: '需兼容 OpenAI Chat Completions 接口',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              suffixIcon: IconButton(
                tooltip: _obscureKey ? '显示' : '隐藏',
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-4o-mini',
            ),
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _connectTimeoutCtrl,
                  decoration: const InputDecoration(
                    labelText: '连接超时（秒）',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _receiveTimeoutCtrl,
                  decoration: const InputDecoration(
                    labelText: '读取超时（秒）',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_testing ? '测试中…' : '测试连接'),
          ),
          if (_testMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _testMessage!,
              style: TextStyle(
                color: _testOk ? scheme.primary : scheme.error,
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text('OCR 服务', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '用于「导入截图识别」。本地 OCR 免配置；阿里云 OCR 使用全文识别高精版（RecognizeAdvanced），'
            '需开通文字识别并填写 AccessKey。浏览器端可能因跨域无法调用，建议在 App / 桌面端使用。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<OcrProvider>(
            segments: [
              for (final p in OcrProvider.values)
                ButtonSegment(
                  value: p,
                  label: Text(p.label),
                  icon: Icon(
                    p == OcrProvider.local
                        ? Icons.phone_android_outlined
                        : Icons.cloud_outlined,
                  ),
                ),
            ],
            selected: {_ocrProvider},
            onSelectionChanged: (set) {
              setState(() => _ocrProvider = set.first);
            },
          ),
          if (_ocrProvider == OcrProvider.aliyun) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _akIdCtrl,
              decoration: const InputDecoration(
                labelText: 'AccessKey ID',
                hintText: 'LTAI...',
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _akSecretCtrl,
              obscureText: _obscureAkSecret,
              decoration: InputDecoration(
                labelText: 'AccessKey Secret',
                suffixIcon: IconButton(
                  tooltip: _obscureAkSecret ? '显示' : '隐藏',
                  onPressed: () =>
                      setState(() => _obscureAkSecret = !_obscureAkSecret),
                  icon: Icon(
                    _obscureAkSecret
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ocrEndpointCtrl,
              decoration: const InputDecoration(
                labelText: 'Endpoint',
                hintText: AppConstants.defaultAliyunOcrEndpoint,
                helperText: '默认杭州公网：ocr-api.cn-hangzhou.aliyuncs.com',
              ),
              autocorrect: false,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            '说明',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '配置保存在本地 SharedPreferences。未填写 LLM API Key 时，生成回复会使用内置演示数据。'
            '也可通过编译期 --dart-define 注入初始默认值（含 ALIYUN_ACCESS_KEY_ID / SECRET）。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
