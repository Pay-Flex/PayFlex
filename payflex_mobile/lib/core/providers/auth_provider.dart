import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final int? userId;
  final String? name;
  final String? role;
  final String? pin;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.userId,
    this.name,
    this.role,
    this.pin,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    int? userId,
    String? name,
    String? role,
    String? pin,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      name: name ?? this.name,
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
    final userId = await _dbService.getCurrentUserId();
    if (userId != null) {
      final user = await _dbService.getUserById(userId);
      if (user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userId: user['id'] as int?,
          name: user['name'] as String?,
          role: user['role'] as String?,
          pin: user['pin'] as String?,
        );
        return;
      }
    }
    state = state.copyWith(isLoading: false, isAuthenticated: false);
  }

  Future<bool> login(String phone, String pin) async {
    state = state.copyWith(isLoading: true);
    final user = await _dbService.login(phone, pin);
    if (user != null) {
      await _dbService.setCurrentUserId(user['id'] as int);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userId: user['id'] as int?,
        name: user['name'] as String?,
        role: user['role'] as String?,
        pin: user['pin'] as String?,
      );
      return true;
    }
    state = state.copyWith(isLoading: false, isAuthenticated: false);
    return false;
  }

  Future<void> saveUserAndPin(String role, String pin) async {
    state = state.copyWith(isLoading: true);
    await _dbService.saveUser(role, pin);
    // On ne définit pas setCurrentUserId ici car c'est une inscription partielle, 
    // l'utilisateur devra se connecter.
    state = state.copyWith(isLoading: false);
  }
  
  Future<void> logout() async {
    await _dbService.setCurrentUserId(null);
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
