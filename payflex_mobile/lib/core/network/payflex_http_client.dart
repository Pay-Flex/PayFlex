import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Client HTTP qui contourne la page de vérification LocalTunnel (`loca.lt`).
///
/// Le suivi d'inactivité repose sur les gestes et la navigation — pas sur les appels API automatiques.
class PayflexHttpClient extends http.BaseClient {
  PayflexHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    for (final entry in ApiConfig.localTunnelHeaders.entries) {
      request.headers.putIfAbsent(entry.key, () => entry.value);
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
