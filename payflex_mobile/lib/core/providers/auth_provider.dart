import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_config.dart';
import '../network/payflex_api_logger.dart';
import '../database/database_service.dart';
import '../network/mobile_api_service.dart';
import '../network/registration_submit_result.dart';
import '../utils/registration_file_store.dart';
import '../utils/user_visible_message.dart';

/// Résultat de [AuthNotifier.login] pour l’UI (message d’erreur explicite).
class LoginOutcome {
  final bool success;
  final String? errorMessage;
  const LoginOutcome.ok() : success = true, errorMessage = null;
  const LoginOutcome.fail(this.errorMessage) : success = false;
}

String _deriveUniqueCode(Map<String, dynamic> data) {
  final explicit = (data['uniqueCode'] as String?)?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final phone = (data['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
  if (phone.isNotEmpty) return 'PF-$phone';
  return 'PF-${DateTime.now().millisecondsSinceEpoch}';
}

int? parseServerUserId(Map<String, dynamic> m) {
  final raw = m['id'];
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

AuthState authStateFromServerProfile(
  Map<String, dynamic> m, {
  required String pin,
  bool isLoading = false,
}) {
  final id = parseServerUserId(m);
  final rawAgentId = m['assigned_agent_user_id'];
  int? agentUid;
  if (rawAgentId is num) agentUid = rawAgentId.toInt();
  final status = (m['status'] as String?)?.toLowerCase().trim() ?? '';
  final awaitingApproval = status == 'pending';
  return AuthState(
    isLoading: isLoading,
    isAuthenticated: true,
    awaitingAdminApproval: awaitingApproval,
    userId: id,
    name: (m['full_name'] ?? m['name']) as String?,
    phone: m['phone'] as String?,
    role: m['role'] as String?,
    pin: pin,
    city: m['city'] as String?,
    profession: m['profession'] as String?,
    gender: m['gender'] as String?,
    accountStatus: m['status'] as String?,
    uniqueCode: m['unique_code'] as String?,
    assignedAgentUserId: agentUid,
    assignedAgentName: m['assigned_agent_name'] as String?,
    assignedAgentPhone: m['assigned_agent_phone'] as String?,
    adhesionFeePaid: m['adhesion_fee_paid'] == true,
    isAdherent: m['is_adherent'] == true || (m['status'] as String?) == 'adhere',
    adhesionFeeFcfa: (m['adhesion_fee_fcfa'] as num?)?.toInt() ?? 250,
    canReportAdhesionDispute: m['can_report_adhesion_dispute'] == true,
    assiduityBadge: m['assiduity_badge'] as String?,
    profilePhotoUrl: _profilePhotoUrlFromMap(m),
  );
}

String? _profilePhotoUrlFromMap(Map<String, dynamic> m) {
  final url = (m['profile_photo_url'] as String?)?.trim();
  if (url != null && url.isNotEmpty) return url;
  final path = (m['profile_photo_path'] as String?)?.trim();
  if (path != null && path.isNotEmpty) return path;
  return null;
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final int? userId;
  final String? name;
  final String? phone;
  final String? role;
  final String? pin;
  final String? city;
  final String? profession;
  final String? gender;
  final String? accountStatus;
  final String? uniqueCode;
  final int? assignedAgentUserId;
  final String? assignedAgentName;
  final String? assignedAgentPhone;
  final bool adhesionFeePaid;
  final bool isAdherent;
  final int adhesionFeeFcfa;
  final bool canReportAdhesionDispute;
  final String? assiduityBadge;
  /// Compte créé côté app mais pas encore approuvé par admin/gestionnaire.
  final bool awaitingAdminApproval;
  final int? pendingRegistrationId;
  /// Photo de profil (inscription), chemin relatif ou URL — résolu via [ApiConfig.resolveMediaUrl].
  final String? profilePhotoUrl;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.userId,
    this.name,
    this.phone,
    this.role,
    this.pin,
    this.city,
    this.profession,
    this.gender,
    this.accountStatus,
    this.uniqueCode,
    this.assignedAgentUserId,
    this.assignedAgentName,
    this.assignedAgentPhone,
    this.adhesionFeePaid = false,
    this.isAdherent = false,
    this.adhesionFeeFcfa = 250,
    this.canReportAdhesionDispute = false,
    this.assiduityBadge,
    this.awaitingAdminApproval = false,
    this.pendingRegistrationId,
    this.profilePhotoUrl,
  });

  bool get needsAdhesionPayment =>
      role == 'client' && !awaitingAdminApproval && !isAdherent && !adhesionFeePaid;

  bool get canUseAppFeatures => isAuthenticated && !awaitingAdminApproval;

  String get greetingFirstName {
    final n = name?.trim();
    if (n == null || n.isEmpty) return 'PayFlex';
    return n.split(RegExp(r'\s+')).first;
  }

  String get avatarLetter {
    final n = name?.trim();
    if (n == null || n.isEmpty) return 'P';
    return n.substring(0, 1).toUpperCase();
  }

  String statusLabelFr() {
    final s = accountStatus?.toLowerCase().trim() ?? '';
    return switch (s) {
      'adhere' => 'Adhérent PayFlex',
      'valide' => 'En attente adhésion (250 FCFA)',
      'pending' => 'En attente de validation',
      'registration_pending' => 'Inscription en cours de validation',
      'bloque' => 'Compte bloqué',
      _ => s.isEmpty ? '—' : accountStatus ?? '—',
    };
  }

  String roleLabelFr() {
    return switch (role) {
      'client' => 'Client',
      'agent' => 'Agent terrain',
      'admin' => 'Administrateur',
      _ => role ?? '—',
    };
  }

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    int? userId,
    String? name,
    String? phone,
    String? role,
    String? pin,
    String? city,
    String? profession,
    String? gender,
    String? accountStatus,
    String? uniqueCode,
    int? assignedAgentUserId,
    String? assignedAgentName,
    String? assignedAgentPhone,
    bool? adhesionFeePaid,
    bool? isAdherent,
    int? adhesionFeeFcfa,
    bool? canReportAdhesionDispute,
    String? assiduityBadge,
    bool? awaitingAdminApproval,
    int? pendingRegistrationId,
    String? profilePhotoUrl,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      city: city ?? this.city,
      profession: profession ?? this.profession,
      gender: gender ?? this.gender,
      accountStatus: accountStatus ?? this.accountStatus,
      uniqueCode: uniqueCode ?? this.uniqueCode,
      assignedAgentUserId: assignedAgentUserId ?? this.assignedAgentUserId,
      assignedAgentName: assignedAgentName ?? this.assignedAgentName,
      assignedAgentPhone: assignedAgentPhone ?? this.assignedAgentPhone,
      adhesionFeePaid: adhesionFeePaid ?? this.adhesionFeePaid,
      isAdherent: isAdherent ?? this.isAdherent,
      adhesionFeeFcfa: adhesionFeeFcfa ?? this.adhesionFeeFcfa,
      canReportAdhesionDispute: canReportAdhesionDispute ?? this.canReportAdhesionDispute,
      assiduityBadge: assiduityBadge ?? this.assiduityBadge,
      awaitingAdminApproval: awaitingAdminApproval ?? this.awaitingAdminApproval,
      pendingRegistrationId: pendingRegistrationId ?? this.pendingRegistrationId,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final DatabaseService _dbService = DatabaseService();
  final MobileApiService _api = MobileApiService();

  @override
  AuthState build() {
    _loadUser();
    return AuthState(isLoading: true);
  }

  Future<void> _loadUser() async {
    final remote = await _dbService.loadRemoteSession();
    if (remote != null) {
      final profile = Map<String, dynamic>.from(remote['profile'] as Map);
      state = authStateFromServerProfile(profile, pin: remote['pin'] as String);
      final uid = parseServerUserId(profile);
      if (uid != null && uid > 0) {
        await _dbService.upsertLocalUserProjection(
          userId: uid,
          name: state.name,
          phone: state.phone,
          role: state.role,
          pin: state.pin,
        );
      }
      Future.microtask(() => refreshProfile());
      return;
    }

    final pending = await _dbService.loadPendingRegistrationSession();
    if (pending != null) {
      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        awaitingAdminApproval: true,
        name: pending['fullName'] as String?,
        phone: pending['phone'] as String?,
        pin: pending['pin'] as String?,
        role: pending['role'] as String? ?? 'client',
        accountStatus: 'registration_pending',
        pendingRegistrationId: pending['registrationId'] as int?,
        assignedAgentUserId: pending['assignedAgentUserId'] as int?,
      );
      return;
    }

    final userId = await _dbService.getCurrentUserId();
    if (userId != null) {
      final user = await _dbService.getUserById(userId);
      if (user != null) {
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          userId: user['id'] as int?,
          name: user['name'] as String?,
          phone: user['phone'] as String?,
          role: user['role'] as String?,
          pin: user['pin'] as String?,
        );
        return;
      }
      await _dbService.setCurrentUserId(null);
    }
    state = AuthState(isLoading: false);
  }

  /// Met à jour le profil depuis le serveur (statut, agent assigné, etc.).
  Future<bool> refreshProfile() async {
    final uid = state.userId;
    final ph = state.phone;
    final p = state.pin;
    if (uid == null || ph == null || p == null || ph.isEmpty || p.isEmpty) return false;
    try {
      final m = await _api.fetchProfile(userId: uid, phone: ph, pin: p);
      if (m == null) return false;
      await _dbService.saveRemoteSession(userId: uid, phone: ph, pin: p, profile: m);
      final next = authStateFromServerProfile(m, pin: p);
      state = next;
      await _dbService.upsertLocalUserProjection(
        userId: uid,
        name: next.name,
        phone: next.phone,
        role: next.role,
        pin: next.pin,
      );
      if (!next.awaitingAdminApproval) {
        await _dbService.clearPendingRegistrationSession();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Connexion : API en priorité (messages d’erreur serveur), puis SQLite si le serveur est injoignable.
  Future<LoginOutcome> login(String identifier, String pin, {String? loginMode}) async {
    final p = identifier.trim();
    final pinTrim = pin.trim();
    if (p.isEmpty || pinTrim.isEmpty) {
      return const LoginOutcome.fail('Indiquez votre identifiant et votre mot de passe ou code PIN.');
    }

    PayflexApiLogger.info(
      'AuthNotifier.login mode=$loginMode identifier=${PayflexApiLogger.maskPhone(p)} pin=${PayflexApiLogger.maskPin(pinTrim)} '
      '→ ${ApiConfig.baseUrl}',
    );

    state = state.copyWith(isLoading: true);

    try {
      final api = await _api.login(p, pinTrim, loginMode: loginMode);

      if (api.success && api.profile != null) {
        final user = api.profile!;
        final remoteId = parseServerUserId(user);
        if (remoteId == null || remoteId <= 0) {
          PayflexApiLogger.warn('Login API OK mais userId absent');
          state = state.copyWith(isLoading: false);
          return const LoginOutcome.fail(
            'Réponse incomplète du serveur. Reconnectez-vous ou contactez le support.',
          );
        }
        try {
          final sessionPhone = (user['phone'] as String?)?.trim();
          final phoneForSession = (sessionPhone != null && sessionPhone.isNotEmpty) ? sessionPhone : p;
          await _dbService.saveRemoteSession(userId: remoteId, phone: phoneForSession, pin: pinTrim, profile: user);
          state = authStateFromServerProfile(user, pin: pinTrim);
          await _dbService.upsertLocalUserProjection(
            userId: remoteId,
            name: state.name,
            phone: state.phone,
            role: state.role,
            pin: state.pin,
          );
          PayflexApiLogger.info(
            'Session enregistrée userId=$remoteId status=${user['status']} role=${user['role']}',
          );
          return const LoginOutcome.ok();
        } catch (e, st) {
          PayflexApiLogger.error('Échec saveRemoteSession', e, st);
          state = state.copyWith(isLoading: false);
          return const LoginOutcome.fail(
            'Impossible d’enregistrer la session. Réessayez.',
          );
        }
      }

      if (api.isAmbiguousIdentity) {
        PayflexApiLogger.warn('Login ambigu: ${api.message}');
        state = state.copyWith(isLoading: false);
        return LoginOutcome.fail(
          UserVisibleMessage.apiOrFallback(
            api.message,
            'Plusieurs comptes correspondent. Contactez le support PayFlex.',
          ),
        );
      }

      if (api.isInvalidIdentifier) {
        PayflexApiLogger.warn('Login identifiant invalide: ${api.message} code=${api.errorCode}');
        state = state.copyWith(isLoading: false);
        return LoginOutcome.fail(
          UserVisibleMessage.apiOrFallback(
            api.message,
            'Numéro ou e-mail incorrect. Le prénom ou le nom seul ne suffit pas.',
          ),
        );
      }

      if (api.isInvalidSecret) {
        PayflexApiLogger.warn('Login PIN incorrect: ${api.message}');
        state = state.copyWith(isLoading: false);
        return LoginOutcome.fail(
          UserVisibleMessage.apiOrFallback(
            api.message,
            'Mot de passe ou code PIN incorrect.',
          ),
        );
      }

      // Refus explicite du serveur (mauvais identifiants, champs manquants)
      if (api.isInvalidCredentials) {
        PayflexApiLogger.warn(
          'Login refusé HTTP ${api.httpStatus} code=${api.errorCode} msg=${api.message}',
        );
        state = state.copyWith(isLoading: false);
        return LoginOutcome.fail(
          UserVisibleMessage.apiOrFallback(
            api.message,
            'Nom, numéro ou mot de passe / code PIN incorrect.',
          ),
        );
      }

      // Erreur serveur 5xx avec message : ne pas confondre avec « mauvais PIN »
      if (api.httpStatus != null && api.httpStatus! >= 500) {
        state = state.copyWith(isLoading: false);
        return LoginOutcome.fail(
          UserVisibleMessage.apiOrFallback(api.message, UserVisibleMessage.serverUnavailable),
        );
      }

      // Réseau / timeout : mode dégradé SQLite (inscription locale hors ligne)
      if (api.shouldTryLocalFallback) {
        PayflexApiLogger.warn(
          'Serveur injoignable (${ApiConfig.connectionMode}) — tentative SQLite locale',
        );
        final local = await _dbService.login(p, pinTrim);
        if (local != null) {
          PayflexApiLogger.info('Connexion SQLite locale userId=${local['id']}');
          await _dbService.clearRemoteSession();
          await _dbService.setCurrentUserId(local['id'] as int);
          state = AuthState(
            isLoading: false,
            isAuthenticated: true,
            userId: local['id'] as int?,
            name: local['name'] as String?,
            phone: local['phone'] as String?,
            role: local['role'] as String?,
            pin: local['pin'] as String?,
          );
          return const LoginOutcome.ok();
        }
      }

      PayflexApiLogger.warn('Login échec final: ${api.message} http=${api.httpStatus}');
      state = state.copyWith(isLoading: false);
      return LoginOutcome.fail(
        UserVisibleMessage.apiOrFallback(api.message, 'Connexion impossible. Réessayez.'),
      );
    } catch (e, st) {
      PayflexApiLogger.error('AuthNotifier.login exception', e, st);
      state = state.copyWith(isLoading: false);
      return LoginOutcome.fail(UserVisibleMessage.forException(e));
    }
  }

  /// Ouvre l'interface client après envoi de la demande (fonctions limitées jusqu'à validation admin).
  Future<void> establishPendingRegistrationSession({
    required String role,
    required String pin,
    required Map<String, dynamic> data,
    int? registrationId,
  }) async {
    final phone = (data['phone'] ?? '').toString();
    final fullName = (data['fullName'] ?? '').toString();
    final agentId = data['assignedAgentUserId'] is int
        ? data['assignedAgentUserId'] as int
        : (data['assignedAgentUserId'] as num?)?.toInt();

    await _dbService.savePendingRegistrationSession(
      phone: phone,
      pin: pin,
      fullName: fullName,
      role: role,
      registrationId: registrationId,
      assignedAgentUserId: agentId,
    );

    PayflexApiLogger.info(
      'Session pending locale phone=${PayflexApiLogger.maskPhone(phone)} registrationId=$registrationId',
    );

    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      awaitingAdminApproval: false,
      name: fullName,
      phone: phone,
      pin: pin,
      role: role,
      city: data['city']?.toString(),
      profession: data['profession']?.toString(),
      gender: data['gender']?.toString(),
      accountStatus: 'valide',
      pendingRegistrationId: registrationId,
      assignedAgentUserId: agentId,
    );
  }

  /// Tente la connexion serveur lorsque l'admin a validé l'inscription.
  Future<bool> tryActivateApprovedAccount() async {
    final phone = state.phone?.trim();
    final pin = state.pin?.trim();
    if (phone == null || phone.isEmpty || pin == null || pin.isEmpty) return false;

    state = state.copyWith(isLoading: true);
    final outcome = await login(phone, pin);
    if (outcome.success && !state.awaitingAdminApproval) {
      await _dbService.clearPendingRegistrationSession();
      state = state.copyWith(isLoading: false, pendingRegistrationId: null);
      return true;
    }
    if (outcome.success && state.awaitingAdminApproval) {
      state = state.copyWith(isLoading: false);
      return false;
    }
    state = state.copyWith(isLoading: false);
    return false;
  }

  /// Si l’envoi a expiré côté app mais la demande existe déjà sur le serveur.
  Future<int?> findPendingRegistrationIdForPhone(String phone) async {
    return _api.findPendingRegistrationId(phone.trim());
  }

  Future<RegistrationSubmitResult> submitPendingRegistration({
    required String role,
    required String pin,
    required Map<String, dynamic> data,
  }) async {
    PayflexApiLogger.info(
      'submitPendingRegistration role=$role phone=${PayflexApiLogger.maskPhone(data['phone']?.toString())} '
      '→ ${ApiConfig.baseUrl}',
    );
    state = state.copyWith(isLoading: true);
    try {
      final apiRole = role == 'client' || role == 'agent' ? role : 'client';
      final clientProfile = (data['clientProfile'] ?? '').toString().trim();
      final profession = (data['profession'] ?? '').toString();
      final professionForApi = profession.isNotEmpty
          ? profession
          : (clientProfile.isNotEmpty ? clientProfile : '');

      final emailRaw = (data['email'] ?? '').toString().trim();
      final passwordRaw = (data['accountPassword'] ?? '').toString().trim();
      if (passwordRaw.length < 6) {
        state = state.copyWith(isLoading: false);
        return RegistrationSubmitResult.failure(
          null,
          'Mot de passe requis (minimum 6 caractères). Revenez à l’étape documents.',
        );
      }
      final result = await _api.submitRegistration(
        fullName: (data['fullName'] ?? '').toString(),
        phone: (data['phone'] ?? '').toString(),
        email: emailRaw.isNotEmpty ? emailRaw : null,
        city: (data['city'] ?? '').toString(),
        profession: professionForApi,
        gender: registrationGenderCode((data['gender'] ?? '').toString()),
        pin: pin,
        secretCode: pin,
        accountPassword: passwordRaw.isNotEmpty ? passwordRaw : null,
        uniqueCode: _deriveUniqueCode(data),
        submittedBy: (data['submittedBy'] ?? 'self').toString(),
        requestedRole: apiRole,
        clientProfile: clientProfile.isNotEmpty ? clientProfile : null,
        workplaceName: data['workplaceName']?.toString(),
        workplaceAddress: data['workplaceAddress']?.toString(),
        bossName: data['bossName']?.toString(),
        bossPhone: data['bossPhone']?.toString(),
        assignedAgentUserId: data['assignedAgentUserId'] is int
            ? data['assignedAgentUserId'] as int
            : (data['assignedAgentUserId'] as num?)?.toInt(),
        profilePhoto: data['profilePhoto'] is File ? data['profilePhoto'] as File : null,
        idDocument: data['idDocument'] is File ? data['idDocument'] as File : null,
        idDocumentWaived: data['idDocumentWaived'] == true,
      );
      state = state.copyWith(isLoading: false);
      if (!result.success) {
        PayflexApiLogger.warn('submitPendingRegistration échec: ${result.message}');
      }
      return result;
    } catch (e, st) {
      PayflexApiLogger.error('submitPendingRegistration exception', e, st);
      state = state.copyWith(isLoading: false);
      return RegistrationSubmitResult.failure(null, UserVisibleMessage.forException(e));
    }
  }
  
  Future<void> logout() async {
    await _dbService.clearRemoteSession();
    await _dbService.clearPendingRegistrationSession();
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// Provider temporaire pour stocker le rôle choisi lors de l'inscription
/// avant la confirmation finale avec le Code PIN.
class TempRoleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setRole(String? role) {
    state = role;
  }
}

final tempRoleProvider = NotifierProvider<TempRoleNotifier, String?>(() {
  return TempRoleNotifier();
});

/// Segment métier choisi à l’écran « Quel est votre profil ? » (apprenti, artisan_fin…).
/// Distinct du rôle compte (`client`), toujours envoyé comme `requestedRole: client` à l’API.
class TempClientProfileNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setProfile(String? profile) {
    state = profile;
  }
}

final tempClientProfileProvider = NotifierProvider<TempClientProfileNotifier, String?>(() {
  return TempClientProfileNotifier();
});

class TempRegistrationDataNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() => {};

  void setData(Map<String, dynamic> data) {
    state = data;
  }

  void clear() {
    state = {};
  }
}

final tempRegistrationDataProvider = NotifierProvider<TempRegistrationDataNotifier, Map<String, dynamic>>(() {
  return TempRegistrationDataNotifier();
});
