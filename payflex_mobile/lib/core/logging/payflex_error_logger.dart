import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Journal fichier persistant (erreurs, avertissements, API).
/// Fichiers dans `<documents>/payflex_logs/` :
///   - payflex_errors.log  (ERROR + exceptions Flutter)
///   - payflex_api.log     (WARN/ERROR réseau + réponses HTTP anormales)
class PayflexErrorLogger {
  PayflexErrorLogger._();

  static const String _errorsFileName = 'payflex_errors.log';
  static const String _apiFileName = 'payflex_api.log';
  static const int _maxBytesPerFile = 1024 * 1024; // 1 Mo

  static Directory? _logDir;
  static final List<String> _buffer = [];
  static bool _flushScheduled = false;
  static bool _initialized = false;

  static String? get logDirectoryPath => _logDir?.path;

  static String get errorsLogPath =>
      _logDir != null ? p.join(_logDir!.path, _errorsFileName) : _errorsFileName;

  static String get apiLogPath =>
      _logDir != null ? p.join(_logDir!.path, _apiFileName) : _apiFileName;

  /// À appeler au démarrage ([main]) avant [runApp].
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final base = await getApplicationDocumentsDirectory();
      _logDir = Directory(p.join(base.path, 'payflex_logs'));
      await _logDir!.create(recursive: true);
      _initialized = true;

      final prev = FlutterError.onError;
      FlutterError.onError = (details) {
        logError(
          'Flutter',
          details.exception,
          details.stack ?? StackTrace.current,
          context: details.context?.toString(),
        );
        prev?.call(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        logError('Platform', error, stack);
        return false;
      };

      await _write(
        _errorsFileName,
        'INFO',
        'App',
        'PayflexErrorLogger initialisé — ${DateTime.now().toIso8601String()}',
      );
      if (kDebugMode) {
        debugPrint('[PayFlex Logs] Dossier: ${_logDir!.path}');
      }
    } catch (e, st) {
      debugPrint('[PayFlex Logs] Init impossible: $e\n$st');
    }
  }

  static void info(String tag, String message) {
    _enqueue(_errorsFileName, 'INFO', tag, message);
  }

  static void warn(String tag, String message) {
    _enqueue(_errorsFileName, 'WARN', tag, message);
    if (kDebugMode) debugPrint('[PayFlex] ⚠ [$tag] $message');
  }

  static void error(String tag, String message, [StackTrace? stack]) {
    _enqueue(_errorsFileName, 'ERROR', tag, message);
    if (stack != null) {
      _enqueue(_errorsFileName, 'ERROR', tag, stack.toString());
    }
    if (kDebugMode) debugPrint('[PayFlex] ✗ [$tag] $message');
  }

  static void logError(
    String tag,
    Object err,
    StackTrace stack, {
    String? context,
  }) {
    final ctx = context != null ? ' ($context)' : '';
    error(tag, '$err$ctx', stack);
  }

  /// Journal API (réseau, auth, réponses HTTP).
  static void apiWarn(String message) => _enqueue(_apiFileName, 'WARN', 'API', message);

  static void apiError(String label, Object e, [StackTrace? stackTrace]) {
    _enqueue(_apiFileName, 'ERROR', 'API', '$label: $e');
    if (stackTrace != null) {
      _enqueue(_apiFileName, 'ERROR', 'API', stackTrace.toString());
    }
  }

  static void apiInfo(String message) => _enqueue(_apiFileName, 'INFO', 'API', message);

  /// Résumé texte pour affichage debug / partage.
  static Future<String> exportSummary({int tailLines = 80}) async {
    if (_logDir == null) return 'Logs non initialisés.';
    final buf = StringBuffer('PayFlex logs — ${DateTime.now().toIso8601String()}\n');
    buf.writeln('Dossier: ${_logDir!.path}\n');
    for (final name in [_errorsFileName, _apiFileName]) {
      buf.writeln('── $name ──');
      buf.writeln(await _readTail(name, tailLines));
      buf.writeln();
    }
    return buf.toString();
  }

  static void _enqueue(String fileName, String level, String tag, String message) {
    if (!_initialized) {
      if (kDebugMode) debugPrint('[PayFlex Logs] (non init) [$level][$tag] $message');
      return;
    }
    final line = _formatLine(level, tag, message);
    _buffer.add('$fileName|$line');
    _scheduleFlush();
  }

  static String _formatLine(String level, String tag, String message) {
    final ts = DateTime.now().toIso8601String();
    return '$ts | $level | $tag | ${message.replaceAll('\n', ' ')}';
  }

  static void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(() async {
      _flushScheduled = false;
      if (_buffer.isEmpty || _logDir == null) return;
      final batch = List<String>.from(_buffer);
      _buffer.clear();
      final byFile = <String, List<String>>{};
      for (final entry in batch) {
        final i = entry.indexOf('|');
        if (i < 0) continue;
        final file = entry.substring(0, i);
        final line = entry.substring(i + 1);
        byFile.putIfAbsent(file, () => []).add(line);
      }
      for (final e in byFile.entries) {
        await _appendLines(e.key, e.value);
      }
    });
  }

  static Future<void> _write(String fileName, String level, String tag, String message) async {
    if (_logDir == null) return;
    await _appendLines(fileName, [_formatLine(level, tag, message)]);
  }

  static Future<void> _appendLines(String fileName, List<String> lines) async {
    if (_logDir == null || lines.isEmpty) return;
    try {
      final file = File(p.join(_logDir!.path, fileName));
      await _rotateIfNeeded(file);
      await file.writeAsString('${lines.join('\n')}\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('[PayFlex Logs] Écriture échouée: $e');
    }
  }

  static Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    final len = await file.length();
    if (len < _maxBytesPerFile) return;
    final rotated = File('${file.path}.1');
    if (await rotated.exists()) await rotated.delete();
    await file.rename(rotated.path);
  }

  static Future<String> _readTail(String fileName, int maxLines) async {
    final file = File(p.join(_logDir!.path, fileName));
    if (!await file.exists()) return '(fichier vide ou absent)';
    final lines = await file.readAsLines();
    if (lines.length <= maxLines) return lines.join('\n');
    return lines.sublist(lines.length - maxLines).join('\n');
  }
}
