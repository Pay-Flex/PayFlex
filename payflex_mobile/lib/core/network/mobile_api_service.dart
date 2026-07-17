import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import '../utils/user_visible_message.dart';
import 'agent_choices_result.dart';
import 'api_config.dart';
import 'payflex_api_logger.dart';
import 'payflex_http_client.dart';
import 'mobile_login_result.dart';
import 'mobile_recovery_outcome.dart';
import 'registration_submit_result.dart';

class MobileApiService {
  final http.Client _client;
  MobileApiService({http.Client? client})
      : _client = client ?? PayflexHttpClient();

  static const Duration _registrationTimeout = Duration(seconds: 25);
  static const Duration _loginTimeout = Duration(seconds: 22);
  static const Duration _recoveryTimeout = Duration(seconds: 25);

  static bool _hasUserId(Map<String, dynamic> map) {
    final id = map['id'];
    if (id == null) return false;
    if (id is num) return id > 0;
    return int.tryParse(id.toString()) != null;
  }

  /// Vérifie que le téléphone atteint le backend (à lancer au démarrage en debug).
  Future<bool> checkHealth() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/health');
    final sw = Stopwatch()..start();
    PayflexApiLogger.request('GET', uri);
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      PayflexApiLogger.response(
        'GET',
        uri,
        res.statusCode,
        bodyPreview: res.body,
        elapsed: sw.elapsed,
      );
      return res.statusCode == 200;
    } on TimeoutException catch (e, st) {
      PayflexApiLogger.error('Health timeout (${ApiConfig.baseUrl})', e, st);
      return false;
    } on SocketException catch (e, st) {
      PayflexApiLogger.error(
        'Health réseau (${ApiConfig.connectionMode})',
        e,
        st,
      );
      return false;
    } catch (e, st) {
      PayflexApiLogger.error('Health échec', e, st);
      return false;
    }
  }

  Future<MobileLoginResult> login(
    String identifier,
    String pin, {
    String? loginMode,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/auth/login');
    final payload = <String, String>{
      'identifier': identifier,
      'phone': identifier,
      'pin': pin,
    };
    if (loginMode != null && loginMode.isNotEmpty) {
      payload['loginMode'] = loginMode;
    }
    final body = jsonEncode(payload);
    final sw = Stopwatch()..start();
    PayflexApiLogger.request(
      'POST',
      uri,
      bodyPreview:
          '{"identifier":"${PayflexApiLogger.maskPhone(identifier)}","pin":"${PayflexApiLogger.maskPin(pin)}"}',
    );
    try {
      final res = await _client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_loginTimeout);
      PayflexApiLogger.response(
        'POST',
        uri,
        res.statusCode,
        bodyPreview: res.body,
        elapsed: sw.elapsed,
      );
      if (res.statusCode == 200) {
        final contentType = res.headers['content-type'] ?? '';
        if (!contentType.contains('json') &&
            res.body.trimLeft().startsWith('<')) {
          PayflexApiLogger.warn(
            'Login 200 mais réponse HTML (souvent redirection admin)',
          );
          return MobileLoginResult.networkError(
            'Le serveur a renvoyé une page web au lieu de l’API. Redémarrez le backend PayFlex puis réessayez.',
          );
        }
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is! Map) {
          PayflexApiLogger.warn('Login 200 mais corps non-JSON objet');
          return MobileLoginResult.networkError('Réponse serveur invalide.');
        }
        final map = Map<String, dynamic>.from(decoded);
        if (_hasUserId(map)) {
          PayflexApiLogger.info(
            'Login OK userId=${map['id']} role=${map['role']} status=${map['status']} '
            'phone=${PayflexApiLogger.maskPhone(map['phone']?.toString())}',
          );
          return MobileLoginResult.ok(map);
        }
        final msg = map['message']?.toString();
        if (msg != null && msg.isNotEmpty) {
          PayflexApiLogger.warn('Login 200 sans id: $msg');
          return MobileLoginResult.httpError(401, res.body);
        }
        PayflexApiLogger.warn('Login 200 sans id ni message');
        return MobileLoginResult.networkError(
          'Réponse serveur invalide (profil manquant).',
        );
      }
      PayflexApiLogger.warn('Login refusé HTTP ${res.statusCode}');
      return MobileLoginResult.httpError(res.statusCode, res.body);
    } on TimeoutException catch (e, st) {
      PayflexApiLogger.error('Login timeout → ${ApiConfig.baseUrl}', e, st);
      return MobileLoginResult.networkError(UserVisibleMessage.timeout);
    } on SocketException catch (e, st) {
      PayflexApiLogger.error(
        'Login SocketException (${ApiConfig.connectionMode})',
        e,
        st,
      );
      return MobileLoginResult.networkError(UserVisibleMessage.forNetworkError());
    } on http.ClientException catch (e, st) {
      PayflexApiLogger.error('Login ClientException', e, st);
      return MobileLoginResult.networkError(UserVisibleMessage.forNetworkError());
    } catch (e, st) {
      PayflexApiLogger.error('Login erreur inattendue', e, st);
      return MobileLoginResult.networkError(UserVisibleMessage.forException(e));
    }
  }

  /// Étape 1 — Vérification identité avant nouveau PIN / code secret.
  Future<RecoveryRequestOutcome> requestAccountRecovery({
    required String phone,
    required String fullName,
    required String uniqueCode,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/auth/recovery/request',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone.trim(),
              'fullName': fullName.trim(),
              'uniqueCode': uniqueCode.trim(),
            }),
          )
          .timeout(_recoveryTimeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final token = decoded['resetToken']?.toString();
          if (token != null && token.isNotEmpty) {
            return RecoveryRequestOutcome.ok(token);
          }
        }
        return RecoveryRequestOutcome.fail('Réponse serveur invalide.');
      }
      String msg = 'Les informations ne correspondent pas.';
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['message'] != null) {
          msg = UserVisibleMessage.apiOrFallback(d['message'].toString(), msg);
        }
      } catch (_) {}
      return RecoveryRequestOutcome.fail(msg);
    } on TimeoutException {
      return RecoveryRequestOutcome.fail(UserVisibleMessage.timeout);
    } on SocketException {
      return RecoveryRequestOutcome.fail(UserVisibleMessage.forNetworkError());
    } catch (e) {
      return RecoveryRequestOutcome.fail(UserVisibleMessage.forException(e));
    }
  }

  /// Oubli complet — demande un rappel PayFlex (sans code unique).
  Future<String?> requestRecoveryCallback({
    required String phone,
    String fullName = '',
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/auth/recovery/callback-request',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone.trim(),
              'fullName': fullName.trim(),
            }),
          )
          .timeout(_recoveryTimeout);
      if (res.statusCode == 200) return null;
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['message'] != null) {
          return UserVisibleMessage.apiOrFallback(
            d['message'].toString(),
            UserVisibleMessage.serverUnavailable,
          );
        }
      } catch (_) {}
      return UserVisibleMessage.serverUnavailable;
    } on TimeoutException {
      return UserVisibleMessage.timeout;
    } on SocketException {
      return UserVisibleMessage.forNetworkError();
    } catch (e) {
      return UserVisibleMessage.forException(e);
    }
  }

  /// Étape 2 — Enregistre le nouveau PIN et le code secret cotisation. [null] = succès.
  Future<String?> resetAccountCredentials({
    required String resetToken,
    required String newPin,
    required String newSecretCode,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/auth/recovery/reset',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'resetToken': resetToken.trim(),
              'newPin': newPin.trim(),
              'newSecretCode': newSecretCode.trim(),
            }),
          )
          .timeout(_recoveryTimeout);
      if (res.statusCode == 200) return null;
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['message'] != null) {
          return UserVisibleMessage.apiOrFallback(
            d['message'].toString(),
            UserVisibleMessage.serverUnavailable,
          );
        }
      } catch (_) {}
      return UserVisibleMessage.serverUnavailable;
    } on TimeoutException {
      return UserVisibleMessage.timeout;
    } on SocketException {
      return UserVisibleMessage.forNetworkError();
    } catch (e) {
      return UserVisibleMessage.forException(e);
    }
  }

  Future<String?> updateClientProfile({
    required int userId,
    required String phone,
    required String pin,
    String? city,
    String? profession,
    String? workplaceName,
    String? workplaceAddress,
    String? bossName,
    String? bossPhone,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/profile/update');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              if (city != null) 'city': city,
              if (profession != null) 'profession': profession,
              if (workplaceName != null) 'workplaceName': workplaceName,
              if (workplaceAddress != null) 'workplaceAddress': workplaceAddress,
              if (bossName != null) 'bossName': bossName,
              if (bossPhone != null) 'bossPhone': bossPhone,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['message'] != null) return d['message'].toString();
      } catch (_) {}
      return 'Mise à jour impossible.';
    } catch (e) {
      return UserVisibleMessage.forException(e);
    }
  }

  Future<Map<String, dynamic>?> fetchProfile({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/profile');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchProductCategories() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/product-categories');
    final res = await _client.get(uri);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/products');
    final res = await _client.get(uri);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Met à jour le snapshot « jours de rattrapage » côté serveur (alertes admin).
  Future<void> postCatchupSnapshot({
    required int userId,
    required String phone,
    required String pin,
    required int orangeDays,
    required String yearMonth,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/calendar-stats');
    try {
      await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              'orangeDays': orangeDays,
              'yearMonth': yearMonth,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> sendContribution({
    required int userId,
    required double amount,
    String paymentMode = 'mobile_money',
    int? productId,
    int? agentId,
    int? catchupYear,
    int? catchupMonth,
    int? catchupDay,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/contributions');
    final body = <String, dynamic>{
      'userId': userId,
      'amount': amount,
      'paymentMode': paymentMode,
    };
    if (productId != null) body['productId'] = productId;
    if (agentId != null) body['agentId'] = agentId;
    if (catchupYear != null) body['catchupYear'] = catchupYear;
    if (catchupMonth != null) body['catchupMonth'] = catchupMonth;
    if (catchupDay != null) body['catchupDay'] = catchupDay;
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 18));
      final map = _decodeJsonMap(res.body);
      if (res.statusCode == 200) {
        if (map != null) return map;
        return null;
      }
      final msg = map?['message']?.toString();
      return {
        'error': UserVisibleMessage.apiOrFallback(
          msg,
          UserVisibleMessage.serverUnavailable,
        ),
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'error': UserVisibleMessage.timeout};
    } on SocketException {
      return {'error': UserVisibleMessage.forNetworkError()};
    } on http.ClientException catch (e) {
      return {'error': UserVisibleMessage.forException(e)};
    } catch (e) {
      return {'error': UserVisibleMessage.forException(e)};
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingContributionsForAgent({
    required int validatorUserId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/contributions/pending',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'validatorUserId': validatorUserId,
              'phone': phone,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 18));
      if (res.statusCode != 200) return [];
      final map = jsonDecode(res.body);
      if (map is! Map) return [];
      final items = map['items'];
      if (items is! List) return [];
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> validateContributionOnServer({
    required int validatorUserId,
    required String phone,
    required String pin,
    required int contributionId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/contributions/validate',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'validatorUserId': validatorUserId,
              'phone': phone,
              'pin': pin,
              'contributionId': contributionId,
            }),
          )
          .timeout(const Duration(seconds: 18));
      if (res.statusCode == 200) return null;
      final map = jsonDecode(res.body);
      if (map is Map && map['message'] != null)
        return map['message'].toString();
    } catch (_) {
      return 'Connexion au serveur impossible.';
    }
    return 'Validation refusée.';
  }

  Future<String?> rejectContributionOnServer({
    required int validatorUserId,
    required String phone,
    required String pin,
    required int contributionId,
    required String reason,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/contributions/reject',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'validatorUserId': validatorUserId,
              'phone': phone,
              'pin': pin,
              'contributionId': contributionId,
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 18));
      if (res.statusCode == 200) return null;
      final map = jsonDecode(res.body);
      if (map is Map && map['message'] != null)
        return map['message'].toString();
    } catch (_) {
      return 'Connexion au serveur impossible.';
    }
    return 'Refus impossible.';
  }

  Future<({int unreadCount, List<Map<String, dynamic>> items})>
  fetchClientNotifications({
    required int userId,
    required String phone,
    required String pin,
    bool unreadOnly = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/notifications');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              'unreadOnly': unreadOnly,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200)
        return (unreadCount: 0, items: <Map<String, dynamic>>[]);
      final map = jsonDecode(res.body);
      if (map is! Map) return (unreadCount: 0, items: <Map<String, dynamic>>[]);
      final unread = (map['unreadCount'] as num?)?.toInt() ?? 0;
      final raw = map['items'];
      final items = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      return (unreadCount: unread, items: items);
    } catch (_) {
      return (unreadCount: 0, items: <Map<String, dynamic>>[]);
    }
  }

  Future<void> markClientNotificationsRead({
    required int userId,
    required String phone,
    required String pin,
    List<int>? notificationIds,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/notifications/read');
    try {
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'phone': phone,
          'pin': pin,
          if (notificationIds != null) 'notificationIds': notificationIds,
        }),
      );
    } catch (_) {}
  }

  Future<bool> markClientNotificationsUnread({
    required int userId,
    required String phone,
    required String pin,
    required List<int> notificationIds,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/notifications/unread',
    );
    try {
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'phone': phone,
          'pin': pin,
          'notificationIds': notificationIds,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteClientNotification({
    required int userId,
    required String phone,
    required String pin,
    required int notificationId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/notifications/delete',
    );
    try {
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'phone': phone,
          'pin': pin,
          'notificationId': notificationId,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setClientNotificationPinned({
    required int userId,
    required String phone,
    required String pin,
    required int notificationId,
    required bool pinned,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/notifications/pin');
    try {
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'phone': phone,
          'pin': pin,
          'notificationId': notificationId,
          'pinned': pinned,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Passerelle de paiement mobile money activée côté backend (repli gracieux).
  /// Renvoie {paydunyaEnabled}. En cas d'échec réseau, on suppose le mobile money
  /// indisponible → l'app retombe sur la déclaration classique / espèces.
  Future<({bool paydunyaEnabled})> fetchPaymentProviders() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/payments/providers');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        if (map is Map) {
          return (paydunyaEnabled: map['paydunyaEnabled'] == true);
        }
      }
    } catch (_) {}
    return (paydunyaEnabled: false);
  }

  /// Initie une cotisation mobile money via PayDunya (Flooz Moov, T-Money / Mixx by Yas, cartes).
  Future<Map<String, dynamic>?> initPaydunyaContribution({
    required int userId,
    required double amount,
    int? productId,
    int? agentId,
    int? catchupYear,
    int? catchupMonth,
    int? catchupDay,
    String? payerPhone,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/contributions/paydunya/init',
    );
    final body = <String, dynamic>{'userId': userId, 'amount': amount};
    if (productId != null) body['productId'] = productId;
    if (agentId != null) body['agentId'] = agentId;
    if (catchupYear != null) body['catchupYear'] = catchupYear;
    if (catchupMonth != null) body['catchupMonth'] = catchupMonth;
    if (catchupDay != null) body['catchupDay'] = catchupDay;
    if (payerPhone != null && payerPhone.trim().isNotEmpty) {
      body['payerPhone'] = payerPhone.trim();
    }
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      final map = _decodeJsonMap(res.body);
      if (res.statusCode == 200) {
        if (map != null) return map;
        return null;
      }
      final msg = map?['message']?.toString();
      return {
        'error': UserVisibleMessage.apiOrFallback(
          msg,
          UserVisibleMessage.serverUnavailable,
        ),
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'error': UserVisibleMessage.timeout};
    } on SocketException {
      return {'error': UserVisibleMessage.forNetworkError()};
    } catch (e) {
      return {'error': UserVisibleMessage.forException(e)};
    }
  }

  Future<Map<String, dynamic>?> paydunyaContributionStatus({
    required int userId,
    required int contributionId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/contributions/paydunya/status',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'contributionId': contributionId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        if (map is Map<String, dynamic>) return map;
        if (map is Map) return Map<String, dynamic>.from(map);
      }
    } catch (_) {}
    return null;
  }

  /// Initie le paiement de l'adhésion (250 FCFA) par mobile money via PayDunya.
  Future<Map<String, dynamic>?> initPaydunyaAdhesion({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/adhesion/paydunya/init',
    );
    PayflexApiLogger.request('POST', uri);
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 25));
      PayflexApiLogger.response(
        'POST',
        uri,
        res.statusCode,
        bodyPreview: res.body,
      );
      final map = _decodeJsonMap(res.body);
      if (res.statusCode == 200 && map != null) {
        return map;
      }
      if (map != null && map['message'] != null) {
        return {'paydunyaEnabled': false, 'message': map['message'].toString()};
      }
    } on TimeoutException catch (e, st) {
      PayflexApiLogger.error('initPaydunyaAdhesion timeout', e, st);
      return {'paydunyaEnabled': false, 'message': UserVisibleMessage.timeout};
    } on SocketException catch (e, st) {
      PayflexApiLogger.error('initPaydunyaAdhesion réseau', e, st);
      return {'paydunyaEnabled': false, 'message': UserVisibleMessage.forNetworkError()};
    } catch (e, st) {
      PayflexApiLogger.error('initPaydunyaAdhesion', e, st);
    }
    return null;
  }

  static Map<String, dynamic>? _decodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> paydunyaAdhesionStatus({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/adhesion/paydunya/status',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        if (map is Map<String, dynamic>) return map;
        if (map is Map) return Map<String, dynamic>.from(map);
      }
    } catch (_) {}
    return null;
  }

  /// Collecte espèces agent : confirmée immédiatement côté serveur si auto-validation active.
  Future<Map<String, dynamic>?> sendAgentCashContribution({
    String? clientPhone,
    int? clientUserId,
    required String clientPin,
    required double amount,
    required String referenceCode,
    required int collectorUserId,
    required String collectorPhone,
    required String collectorPin,
    int? productId,
    int? catchupYear,
    int? catchupMonth,
    int? catchupDay,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/contributions');
    final body = <String, dynamic>{
      'userId': clientUserId ?? 0,
      'amount': amount,
      'paymentMode': 'cash',
      'collectorPhone': collectorPhone,
      'collectorPin': collectorPin,
      'collectorUserId': collectorUserId,
      'clientPin': clientPin,
      'referenceCode': referenceCode,
    };
    if (clientPhone != null && clientPhone.trim().isNotEmpty) {
      body['clientPhone'] = clientPhone.trim();
    }
    if (productId != null) body['productId'] = productId;
    if (catchupYear != null) body['catchupYear'] = catchupYear;
    if (catchupMonth != null) body['catchupMonth'] = catchupMonth;
    if (catchupDay != null) body['catchupDay'] = catchupDay;
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 18));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return <String, dynamic>{'status': 'pending'};
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSupportChatHistory({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/support-chat/history',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchBonusSavings({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/client/bonus-savings');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchContributionHistory({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/contributions/history',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return [];
      final items = decoded['items'];
      if (items is! List) return [];
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Détail d'une répartition automatique (paiement scindé entre plusieurs produits),
  /// utilisé par l'historique client quand une ligne porte un `allocation_group_id`.
  Future<Map<String, dynamic>?> fetchAllocationGroup({
    required int userId,
    required String phone,
    required String pin,
    required int groupId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/contributions/allocation-group',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              'groupId': groupId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<
    ({
      int chatUnread,
      int notificationsUnread,
      String? bannerTitle,
      String? bannerBody,
      String? bannerType,
    })
  >
  fetchInboxSummary({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/support-chat/inbox');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        return (
          chatUnread: 0,
          notificationsUnread: 0,
          bannerTitle: null,
          bannerBody: null,
          bannerType: null,
        );
      }
      final map = jsonDecode(res.body);
      if (map is! Map) {
        return (
          chatUnread: 0,
          notificationsUnread: 0,
          bannerTitle: null,
          bannerBody: null,
          bannerType: null,
        );
      }
      return (
        chatUnread: (map['chatUnread'] as num?)?.toInt() ?? 0,
        notificationsUnread: (map['notificationsUnread'] as num?)?.toInt() ?? 0,
        bannerTitle: map['bannerTitle']?.toString(),
        bannerBody: map['bannerBody']?.toString(),
        bannerType: map['bannerType']?.toString(),
      );
    } catch (_) {
      return (
        chatUnread: 0,
        notificationsUnread: 0,
        bannerTitle: null,
        bannerBody: null,
        bannerType: null,
      );
    }
  }

  Future<void> markSupportChatRead({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/support-chat/mark-read',
    );
    try {
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
      );
    } catch (_) {}
  }

  /// Sync push sans Firebase (nouvelles lignes `client_notifications` + chat).
  Future<PushPollResult?> pollPushInbox({
    required int userId,
    required String phone,
    required String pin,
    required int afterNotificationId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/push/poll');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              'afterNotificationId': afterNotificationId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body);
      if (map is! Map) return null;
      final raw = map['newNotifications'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      return PushPollResult(
        latestNotificationId: (map['latestNotificationId'] as num?)?.toInt() ?? afterNotificationId,
        newNotifications: items,
        chatUnread: (map['chatUnread'] as num?)?.toInt() ?? 0,
        latestChatTitle: map['latestChatTitle']?.toString(),
        latestChatPreview: map['latestChatPreview']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Enregistre le jeton FCM de cet appareil pour l'utilisateur (push réel).
  Future<void> registerFcmToken({
    required int userId,
    required String phone,
    required String pin,
    required String fcmToken,
    String platform = 'android',
    String role = '',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/devices/register-token');
    try {
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'phone': phone,
          'pin': pin,
          'token': fcmToken,
          'platform': platform,
          'role': role,
        }),
      );
    } catch (_) {}
  }

  /// Retire le jeton FCM de cet appareil (déconnexion).
  Future<void> unregisterFcmToken({required String fcmToken}) async {
    if (fcmToken.isEmpty) return;
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/devices/unregister-token');
    try {
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': fcmToken}),
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _agentPost(
    String path, {
    required int userId,
    required String phone,
    required String pin,
    Map<String, dynamic>? extra,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final body = <String, dynamic>{
      'userId': userId,
      'phone': phone,
      'pin': pin,
      if (extra != null) ...extra,
    };
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) return d;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchAgentDashboard({
    required int userId,
    required String phone,
    required String pin,
  }) =>
      _agentPost('/api/mobile/agent/dashboard', userId: userId, phone: phone, pin: pin);

  Future<Map<String, dynamic>?> fetchAgentProfile({
    required int userId,
    required String phone,
    required String pin,
  }) =>
      _agentPost('/api/mobile/agent/profile', userId: userId, phone: phone, pin: pin);

  Future<Map<String, dynamic>?> fetchAgentZoneTour({
    required int userId,
    required String phone,
    required String pin,
  }) =>
      _agentPost('/api/mobile/agent/zone-tour', userId: userId, phone: phone, pin: pin);

  Future<Map<String, dynamic>?> updateAgentWeeklySchedule({
    required int userId,
    required String phone,
    required String pin,
    required Map<String, String> weeklySchedule,
  }) =>
      _agentPost(
        '/api/mobile/agent/profile/schedule',
        userId: userId,
        phone: phone,
        pin: pin,
        extra: {'weeklySchedule': weeklySchedule},
      );

  Future<Map<String, dynamic>?> changeAgentPin({
    required int userId,
    required String phone,
    required String pin,
    required String currentPin,
    required String newPin,
  }) =>
      _agentPost(
        '/api/mobile/agent/profile/pin',
        userId: userId,
        phone: phone,
        pin: pin,
        extra: {'currentPin': currentPin, 'newPin': newPin},
      );

  Future<Map<String, dynamic>?> fetchAgentContributionRegistry({
    required int userId,
    required String phone,
    required String pin,
  }) =>
      _agentPost('/api/mobile/agent/contributions/registry', userId: userId, phone: phone, pin: pin);

  Future<Map<String, dynamic>?> fetchAgentClientDetail({
    required int userId,
    required String phone,
    required String pin,
    required int clientUserId,
  }) =>
      _agentPost(
        '/api/mobile/agent/client-detail',
        userId: userId,
        phone: phone,
        pin: pin,
        extra: {'clientUserId': clientUserId},
      );

  Future<Map<String, dynamic>?> addAgentClientProducts({
    required int userId,
    required String phone,
    required String pin,
    required int clientUserId,
    required List<Map<String, dynamic>> productSelections,
    required double dailyContribution,
  }) =>
      _agentPost(
        '/api/mobile/agent/client/products',
        userId: userId,
        phone: phone,
        pin: pin,
        extra: {
          'clientUserId': clientUserId,
          'productSelections': productSelections,
          'dailyContribution': dailyContribution,
        },
      );

  Future<bool> verifyClientPin({
    required int agentUserId,
    required String phone,
    required String pin,
    required int clientUserId,
    required String clientPin,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/agent/verify-client-pin');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': agentUserId,
              'phone': phone,
              'pin': pin,
              'clientUserId': clientUserId,
              'clientPin': clientPin,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        return d is Map && d['ok'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>?> fetchAgentClients({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/agent/clients');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) return d;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> markClientAdhesionPaid({
    required int agentUserId,
    required String phone,
    required String pin,
    required int clientUserId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/agent/adhesion/paid',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': agentUserId,
              'phone': phone,
              'pin': pin,
              'clientUserId': clientUserId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['message'] != null) {
          return UserVisibleMessage.apiOrFallback(
            d['message'].toString(),
            'Action impossible.',
          );
        }
      } catch (_) {}
      return 'Action impossible.';
    } catch (e) {
      return UserVisibleMessage.forException(e);
    }
  }

  Future<String?> reportAdhesionDispute({
    required int userId,
    required String phone,
    required String pin,
    String note = '',
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/client/adhesion/dispute',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              'note': note,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['message'] != null) {
          return UserVisibleMessage.apiOrFallback(
            d['message'].toString(),
            'Signalement impossible.',
          );
        }
      } catch (_) {}
      return 'Signalement impossible.';
    } catch (e) {
      return UserVisibleMessage.forException(e);
    }
  }

  Future<bool> sendSupportChatAttachment({
    required int userId,
    required String phone,
    required String pin,
    required File file,
    String? caption,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/support-chat/send-attachment');
    try {
      final req = http.MultipartRequest('POST', uri)
        ..fields['userId'] = userId.toString()
        ..fields['phone'] = phone
        ..fields['pin'] = pin;
      if (caption != null && caption.trim().isNotEmpty) {
        req.fields['caption'] = caption.trim();
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return false;
      final filename = p.basename(file.path);
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename.isNotEmpty ? filename : 'attachment.bin',
        ),
      );
      final streamed = await _client.send(req).timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 60));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendSupportChatMessage({
    required int userId,
    required String phone,
    required String pin,
    required String body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/support-chat/send');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              'body': body,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSupportChatMessage({
    required int userId,
    required String phone,
    required String pin,
    required int messageId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/support-chat/delete-message',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phone': phone,
              'pin': pin,
              'messageId': messageId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSupportChatThread({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/support-chat/delete-thread',
    );
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchJobOffers() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/job-offers');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['offers'] is! List) return [];
      return (decoded['offers'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchJobOfferDetail(int id) async {
    if (id <= 0) return null;
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/job-offers/$id');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLegalDocuments() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/legal/documents');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['documents'] is! List) return [];
      return (decoded['documents'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<AgentChoicesResult> fetchRegistrationAgentChoices() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/agents/choices');
    final sw = Stopwatch()..start();
    PayflexApiLogger.request('GET', uri);
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      PayflexApiLogger.response(
        'GET',
        uri,
        res.statusCode,
        bodyPreview: res.body,
        elapsed: sw.elapsed,
      );
      if (res.statusCode != 200) {
        PayflexApiLogger.warn(
          'Agents/choices HTTP ${res.statusCode} (${ApiConfig.connectionMode})',
        );
        return AgentChoicesResult.failure(
          UserVisibleMessage.forHttpStatus(
            res.statusCode,
            fallback: 'Impossible de charger la liste des agents. Réessayez.',
          ),
          isNetworkError: res.statusCode >= 502,
        );
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['agents'] is! List) {
        PayflexApiLogger.warn('Agents/choices : réponse JSON inattendue');
        return const AgentChoicesResult.failure('Réponse serveur invalide.');
      }
      final agents = (decoded['agents'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return AgentChoicesResult.success(agents);
    } on TimeoutException catch (e, st) {
      PayflexApiLogger.error('Agents/choices timeout (${ApiConfig.baseUrl})', e, st);
      return AgentChoicesResult.failure(UserVisibleMessage.timeout, isNetworkError: true);
    } on SocketException catch (e, st) {
      PayflexApiLogger.error(
        'Agents/choices SocketException (${ApiConfig.connectionMode})',
        e,
        st,
      );
      return AgentChoicesResult.failure(
        UserVisibleMessage.forNetworkError(),
        isNetworkError: true,
      );
    } on http.ClientException catch (e, st) {
      PayflexApiLogger.error('Agents/choices ClientException', e, st);
      return AgentChoicesResult.failure(
        UserVisibleMessage.forNetworkError(),
        isNetworkError: true,
      );
    } catch (e, st) {
      PayflexApiLogger.error('Agents/choices erreur', e, st);
      return AgentChoicesResult.failure(UserVisibleMessage.forException(e));
    }
  }

  /// Demande déjà en attente pour ce téléphone (reprise après timeout / double envoi).
  Future<int?> findPendingRegistrationId(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/mobile/registrations/pending',
    ).replace(queryParameters: {'phone': trimmed});
    final sw = Stopwatch()..start();
    PayflexApiLogger.request('GET', uri);
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      PayflexApiLogger.response(
        'GET',
        uri,
        res.statusCode,
        bodyPreview: res.body,
        elapsed: sw.elapsed,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['id'] is num) {
          final id = (decoded['id'] as num).toInt();
          PayflexApiLogger.info(
            'Demande pending trouvée id=$id phone=${PayflexApiLogger.maskPhone(trimmed)}',
          );
          return id;
        }
      }
      if (res.statusCode == 404) {
        PayflexApiLogger.info(
          'Aucune demande pending pour ${PayflexApiLogger.maskPhone(trimmed)}',
        );
      }
    } catch (e, st) {
      PayflexApiLogger.error('findPendingRegistrationId', e, st);
    }
    return null;
  }

  Future<RegistrationSubmitResult> submitRegistration({
    required String fullName,
    String? phone,
    String? email,
    required String city,
    required String profession,
    required String gender,
    required String pin,
    required String secretCode,
    String? accountPassword,
    required String uniqueCode,
    String submittedBy = 'self',
    String requestedRole = 'client',
    String? clientProfile,
    int? submittedByAgentUserId,
    int? assignedAgentUserId,
    String? workplaceName,
    String? workplaceAddress,
    String? bossName,
    String? bossPhone,
    File? profilePhoto,
    File? idDocument,
    bool idDocumentWaived = false,
    List<Map<String, dynamic>>? productSelections,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/mobile/registrations');
    final req = http.MultipartRequest('POST', uri)
      ..fields['fullName'] = fullName
      ..fields['phone'] = phone?.trim() ?? ''
      ..fields['city'] = city
      ..fields['profession'] = profession
      ..fields['gender'] = gender
      ..fields['pin'] = pin
      ..fields['secretCode'] = secretCode
      ..fields['uniqueCode'] = uniqueCode
      ..fields['submittedBy'] = submittedBy
      ..fields['requestedRole'] = requestedRole;
    if (accountPassword != null && accountPassword.trim().isNotEmpty) {
      req.fields['accountPassword'] = accountPassword.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      req.fields['email'] = email.trim();
    }
    if (clientProfile != null && clientProfile.isNotEmpty) {
      req.fields['clientProfile'] = clientProfile;
    }

    if (submittedByAgentUserId != null) {
      req.fields['submittedByAgentUserId'] = submittedByAgentUserId.toString();
    }
    if (assignedAgentUserId != null) {
      req.fields['assignedAgentUserId'] = assignedAgentUserId.toString();
    }
    if (workplaceName != null && workplaceName.isNotEmpty)
      req.fields['workplaceName'] = workplaceName;
    if (workplaceAddress != null && workplaceAddress.isNotEmpty)
      req.fields['workplaceAddress'] = workplaceAddress;
    if (bossName != null && bossName.isNotEmpty)
      req.fields['bossName'] = bossName;
    if (bossPhone != null && bossPhone.isNotEmpty)
      req.fields['bossPhone'] = bossPhone;
    if (idDocumentWaived) req.fields['idDocumentWaived'] = 'true';
    if (productSelections != null && productSelections.isNotEmpty) {
      req.fields['productSelections'] = jsonEncode(productSelections);
    }

    await _attachRegistrationFile(req, 'profilePhoto', profilePhoto);
    await _attachRegistrationFile(req, 'idDocument', idDocument);

    final safeFields = Map<String, String>.from(req.fields);
    if (safeFields.containsKey('pin'))
      safeFields['pin'] = PayflexApiLogger.maskPin(safeFields['pin']);
    if (safeFields.containsKey('secretCode')) {
      safeFields['secretCode'] = PayflexApiLogger.maskPin(
        safeFields['secretCode'],
      );
    }
    if (safeFields.containsKey('phone'))
      safeFields['phone'] = PayflexApiLogger.maskPhone(safeFields['phone']);

    final sw = Stopwatch()..start();
    PayflexApiLogger.request('POST', uri, fields: safeFields);

    try {
      final streamed = await _client.send(req).timeout(_registrationTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_registrationTimeout);
      PayflexApiLogger.response(
        'POST',
        uri,
        response.statusCode,
        bodyPreview: response.body,
        elapsed: sw.elapsed,
      );
      if (response.statusCode == 200) {
        int? regId;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['id'] is num) {
            regId = (decoded['id'] as num).toInt();
          }
        } catch (_) {}
        PayflexApiLogger.info(
          'Inscription OK registrationId=$regId phone=${PayflexApiLogger.maskPhone(phone)}',
        );
        return RegistrationSubmitResult.success(registrationId: regId);
      }
      String? msg;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          msg = decoded['message'].toString();
        }
      } catch (_) {}
      PayflexApiLogger.warn(
        'Inscription refusée HTTP ${response.statusCode}: ${msg ?? response.body}',
      );
      return RegistrationSubmitResult.failure(
        response.statusCode,
        UserVisibleMessage.apiOrFallback(
          msg,
          UserVisibleMessage.registrationFailed,
        ),
      );
    } on TimeoutException catch (e, st) {
      PayflexApiLogger.error('Inscription timeout', e, st);
      return RegistrationSubmitResult.failure(null, UserVisibleMessage.timeout);
    } on SocketException catch (e, st) {
      PayflexApiLogger.error(
        'Inscription SocketException (${ApiConfig.connectionMode})',
        e,
        st,
      );
      return RegistrationSubmitResult.failure(null, UserVisibleMessage.forNetworkError());
    } on HttpException catch (e, st) {
      PayflexApiLogger.error('Inscription HttpException', e, st);
      return RegistrationSubmitResult.failure(null, UserVisibleMessage.forNetworkError());
    } catch (e, st) {
      PayflexApiLogger.error('Inscription erreur', e, st);
      return RegistrationSubmitResult.failure(
        null,
        UserVisibleMessage.forException(e),
      );
    }
  }

  static Future<void> _attachRegistrationFile(
    http.MultipartRequest req,
    String field,
    File? file,
  ) async {
    if (file == null || !await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;
    final filename = p.basename(file.path);
    req.files.add(
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename.isNotEmpty ? filename : '$field.bin',
      ),
    );
  }
}

class PushPollResult {
  final int latestNotificationId;
  final List<Map<String, dynamic>> newNotifications;
  final int chatUnread;
  final String? latestChatTitle;
  final String? latestChatPreview;

  const PushPollResult({
    required this.latestNotificationId,
    required this.newNotifications,
    required this.chatUnread,
    this.latestChatTitle,
    this.latestChatPreview,
  });
}
