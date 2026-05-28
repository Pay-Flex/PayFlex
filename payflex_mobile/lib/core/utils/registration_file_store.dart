import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copie les pièces jointes dans un dossier persistant de l'app
/// (évite la perte des chemins cache entre les étapes PIN et l'envoi API).
class RegistrationFileStore {
  static Future<File?> persist(File source, String prefix) async {
    try {
      if (!await source.exists()) return null;
      final dir = await getApplicationDocumentsDirectory();
      final uploadsDir = Directory(p.join(dir.path, 'registration_uploads'));
      if (!await uploadsDir.exists()) {
        await uploadsDir.create(recursive: true);
      }
      var ext = p.extension(source.path);
      if (ext.isEmpty) ext = prefix == 'profile' ? '.jpg' : '.pdf';
      final dest = File(
        p.join(uploadsDir.path, '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext'),
      );
      return await source.copy(dest.path);
    } catch (_) {
      return null;
    }
  }
}

String registrationGenderCode(String? label) {
  final g = (label ?? '').trim().toLowerCase();
  if (g == 'homme' || g == 'm' || g == 'male') return 'M';
  if (g == 'femme' || g == 'f' || g == 'female') return 'F';
  if (g == 'autre') return 'Autre';
  return label?.trim() ?? '';
}
