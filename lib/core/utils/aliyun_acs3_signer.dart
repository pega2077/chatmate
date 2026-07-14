import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 阿里云 OpenAPI V3（ACS3-HMAC-SHA256）签名工具
class AliyunAcs3Signer {
  AliyunAcs3Signer._();

  static const String algorithm = 'ACS3-HMAC-SHA256';

  /// 为请求生成签名相关头（含 Authorization）
  static Map<String, String> signHeaders({
    required String accessKeyId,
    required String accessKeySecret,
    required String host,
    required String action,
    required String version,
    required String httpMethod,
    required String canonicalUri,
    required Map<String, String> queryParams,
    required Uint8List body,
    String? contentType,
  }) {
    final hashedPayload = sha256Hex(body);
    final date = _utcTimestamp();
    final nonce = _randomNonce();

    final headers = <String, String>{
      'host': host,
      'x-acs-action': action,
      'x-acs-version': version,
      'x-acs-date': date,
      'x-acs-signature-nonce': nonce,
      'x-acs-content-sha256': hashedPayload,
      if (contentType != null && contentType.isNotEmpty)
        'content-type': contentType,
    };

    final signedHeaderKeys = headers.keys.toList()..sort();
    final canonicalHeaders = StringBuffer();
    for (final key in signedHeaderKeys) {
      canonicalHeaders.writeln('$key:${headers[key]}');
    }
    final signedHeaders = signedHeaderKeys.join(';');

    final canonicalQuery = _canonicalQueryString(queryParams);
    final canonicalRequest = [
      httpMethod.toUpperCase(),
      canonicalUri,
      canonicalQuery,
      canonicalHeaders.toString(),
      signedHeaders,
      hashedPayload,
    ].join('\n');

    final stringToSign =
        '$algorithm\n${sha256Hex(utf8.encode(canonicalRequest))}';
    final signature = Hmac(
      sha256,
      utf8.encode(accessKeySecret),
    ).convert(utf8.encode(stringToSign)).bytes;
    final signatureHex = _toHex(signature);

    headers['Authorization'] =
        '$algorithm Credential=$accessKeyId,SignedHeaders=$signedHeaders,Signature=$signatureHex';

    return headers;
  }

  static String canonicalQueryString(Map<String, String> queryParams) =>
      _canonicalQueryString(queryParams);

  static String sha256Hex(List<int> data) => _toHex(sha256.convert(data).bytes);

  static String _canonicalQueryString(Map<String, String> queryParams) {
    if (queryParams.isEmpty) return '';
    final keys = queryParams.keys.toList()..sort();
    return keys
        .map((k) => '${_percentEncode(k)}=${_percentEncode(queryParams[k]!)}')
        .join('&');
  }

  /// 与阿里云示例一致的 percent encoding
  static String _percentEncode(String value) {
    return Uri.encodeQueryComponent(value)
        .replaceAll('+', '%20')
        .replaceAll('*', '%2A')
        .replaceAll('%7E', '~');
  }

  static String _utcTimestamp() {
    final now = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}'
        'T${two(now.hour)}:${two(now.minute)}:${two(now.second)}Z';
  }

  static String _randomNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return _toHex(bytes);
  }

  static String _toHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
