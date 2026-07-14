import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/api_config.dart';
import '../../providers/api_config_provider.dart';

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

  bool _obscureKey = true;
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
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _connectTimeoutCtrl.dispose();
    _receiveTimeoutCtrl.dispose();
    super.dispose();
  }

  ApiConfig _buildFromFields() {
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

  Future<void> _save() async {
    final config = _buildFromFields();
    if (config.baseUrl.isEmpty || config.model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base URL 与模型名称不能为空')),
      );
      return;
    }
    await ref.read(apiConfigProvider.notifier).save(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API 配置已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reset() async {
    await ref.read(apiConfigProvider.notifier).reset();
    final config = ref.read(apiConfigProvider);
    setState(() {
      _baseUrlCtrl.text = config.baseUrl;
      _apiKeyCtrl.text = config.apiKey;
      _modelCtrl.text = config.model;
      _connectTimeoutCtrl.text = '${config.connectTimeoutSeconds}';
      _receiveTimeoutCtrl.text = '${config.receiveTimeoutSeconds}';
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
    final config = _buildFromFields();
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
      // OpenAI 兼容接口：优先打 /models，失败再试轻量 chat
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
        title: const Text('API 设置'),
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
                  _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
          const SizedBox(height: 24),
          Text(
            '说明',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '配置保存在本地 SharedPreferences。未填写 API Key 时，生成回复会使用内置演示数据。也可通过编译期 --dart-define 注入初始默认值。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
