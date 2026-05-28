import 'package:flutter/foundation.dart';

import '../logging/payflex_error_logger.dart';

/// Logs réseau — console (debug) + fichiers persistants (warn/error).
class PayflexApiLogger {
  PayflexApiLogger._();

  static const String _tag = '[PayFlex API]';

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('$_tag $message');
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      debugPrint('$_tag ⚠ $message');
    }
    PayflexErrorLogger.apiWarn(message);
  }

  static void error(String label, Object e, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_tag ✗ $label: $e');
      if (stackTrace != null) {
        debugPrint('$_tag   $stackTrace');
      }
    }
    PayflexErrorLogger.apiError(label, e, stackTrace);
  }

  static String maskPhone(String? phone) {
    final p = phone?.trim() ?? '';
    if (p.isEmpty) return '(vide)';
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return '****';
    return '***${digits.substring(digits.length - 4)}';
  }

  static String maskPin(String? pin) {
    final n = pin?.trim().length ?? 0;
    return n == 0 ? '(vide)' : '**** ($n chiffres)';
  }

  static void logConfig(String summary) {
    if (!kDebugMode) return;
    debugPrint('$_tag ─── Configuration ───');
    for (final line in summary.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) debugPrint('$_tag   $t');
    }
    debugPrint('$_tag ─────────────────────');
    PayflexErrorLogger.apiInfo('Config: ${summary.replaceAll('\n', ' | ')}');
  }

  static void request(
    String method,
    Uri uri, {
    Map<String, String>? fields,
    String? bodyPreview,
  }) {
    if (!kDebugMode) return;
    debugPrint('$_tag → $method $uri');
    if (fields != null && fields.isNotEmpty) {
      final safe = Map<String, String>.from(fields);
      if (safe.containsKey('pin')) safe['pin'] = maskPin(safe['pin']);
      if (safe.containsKey('secretCode')) safe['secretCode'] = maskPin(safe['secretCode']);
      if (safe.containsKey('accountPassword')) {
        safe['accountPassword'] = maskPin(safe['accountPassword']);
      }
      if (safe.containsKey('phone')) safe['phone'] = maskPhone(safe['phone']);
      debugPrint('$_tag   champs: $safe');
    }
    if (bodyPreview != null && bodyPreview.isNotEmpty) {
      debugPrint('$_tag   corps: ${_truncate(bodyPreview)}');
    }
  }

  static void response(
    String method,
    Uri uri,
    int? statusCode, {
    String? bodyPreview,
    Duration? elapsed,
  }) {
    final ms = elapsed != null ? ' (${elapsed.inMilliseconds} ms)' : '';
    final code = statusCode ?? '—';
    if (kDebugMode) {
      debugPrint('$_tag ← $method $uri → HTTP $code$ms');
      if (bodyPreview != null && bodyPreview.isNotEmpty) {
        debugPrint('$_tag   corps: ${_truncate(bodyPreview)}');
      }
    }
    if (statusCode != null && statusCode >= 400) {
      PayflexErrorLogger.apiWarn(
        '$method $uri → HTTP $code$ms${bodyPreview != null ? ' | ${_truncate(bodyPreview)}' : ''}',
      );
    }
  }

  static String _truncate(String s, [int max = 400]) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}
