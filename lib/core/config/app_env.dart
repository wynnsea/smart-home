import 'package:flutter/services.dart';

const String _defineApiKey = String.fromEnvironment('OPENROUTER_API_KEY');
const String _defineGatewayUrl = String.fromEnvironment('AI_GATEWAY_URL');

/// Lightweight zero-dependency `.env` loader bundled as a local asset.
/// Values loaded from `.env` at app startup are used automatically without
/// needing `--dart-define` flags when running `flutter run`.
abstract final class AppEnv {
  static Map<String, String> _values = const {};

  /// Parses standard `KEY=VALUE` lines, ignoring blank lines and `#` comments,
  /// and stripping optional surrounding single or double quotes.
  static Map<String, String> parse(String raw) {
    final result = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx <= 0) continue;

      final key = trimmed.substring(0, eqIdx).trim();
      var value = trimmed.substring(eqIdx + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }

  /// Loads `.env` from [bundle] (defaults to [rootBundle]). Silently falls back
  /// to empty values if the file is absent (e.g. in unit tests).
  static Future<void> load({
    AssetBundle? bundle,
    String path = '.env',
  }) async {
    try {
      final content = await (bundle ?? rootBundle).loadString(path);
      _values = parse(content);
    } catch (_) {
      _values = const {};
    }
  }

  static String get(String key, {String fallback = ''}) {
    final val = _values[key]?.trim();
    if (val != null && val.isNotEmpty) return val;
    return fallback;
  }

  static String get openRouterApiKey {
    if (_defineApiKey.trim().isNotEmpty) return _defineApiKey.trim();
    return get('OPENROUTER_API_KEY');
  }

  static String get aiGatewayUrl {
    if (_defineGatewayUrl.trim().isNotEmpty) return _defineGatewayUrl.trim();
    return get('AI_GATEWAY_URL', fallback: 'https://openrouter.ai/api/v1');
  }
}
