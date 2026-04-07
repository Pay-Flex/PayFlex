import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? role;
  final String? pin;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.role,
    this.pin,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? role,
    String? pin,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      pin: pin ?? this.pin,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final DatabaseService _dbService = DatabaseService();

  @override
  AuthState build() {
    _loadUser();
    return AuthState(isLoading: true);
  }

  Future<void> _loadUser() async {
    final user = await _dbService.getUser();
    if (user != null) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        role: user['role'] as String?,
        pin: user['pin'] as String?,
      );
    } else {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<void> saveUserAndPin(String role, String pin) async {
    state = state.copyWith(isLoading: true);
    await _dbService.saveUser(role, pin);
    await _loadUser();
  }
  
  Future<void> logout() async {
    await _dbService.clearDatabase();
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

/// Provider temporaire pour stocker le rôle choisi lors de l'inscription
/// avant la confirmation finale avec le Code PIN.
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
