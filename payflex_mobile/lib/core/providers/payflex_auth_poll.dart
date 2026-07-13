import 'auth_provider.dart';

bool payflexShouldPollMobile(AuthState auth) {
  if (!auth.isAuthenticated || auth.isLoading) return false;
  if (auth.userId == null || auth.phone == null || auth.pin == null) return false;
  return auth.role == 'client' || auth.role == 'agent';
}

bool payflexShouldPollAgent(AuthState auth) {
  return payflexShouldPollMobile(auth) && auth.role == 'agent';
}
