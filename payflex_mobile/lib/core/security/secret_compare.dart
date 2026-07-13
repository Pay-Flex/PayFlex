/// Comparaison de secrets en temps constant (longueurs égales uniquement).
bool constantTimeSecretMatch(String stored, String submitted) {
  final a = stored.trim();
  final b = submitted.trim();
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
