import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/auth_wave_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_config.dart';
import '../../core/network/payflex_api_logger.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/user_visible_message.dart';
import '../../core/widgets/payflex_sweet_alert.dart';
import '../agent/agent_main_navigation_screen.dart';
import '../main_navigation_screen.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/services/notification_permission_flow.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _submitting = false;
  bool _pinVisible = false;
  Map<String, dynamic>? _cachedRegistrationData;

  static const Duration _submitTimeout = Duration(seconds: 35);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cacheRegistrationData());
  }

  void _cacheRegistrationData() {
    final fromProvider = ref.read(tempRegistrationDataProvider);
    if (fromProvider.isNotEmpty) {
      setState(() => _cachedRegistrationData = Map<String, dynamic>.from(fromProvider));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _pin => _controllers.map((c) => c.text).join();

  Map<String, dynamic> _registrationData() {
    if (_cachedRegistrationData != null && _cachedRegistrationData!.isNotEmpty) {
      return _cachedRegistrationData!;
    }
    final fromProvider = ref.read(tempRegistrationDataProvider);
    if (fromProvider.isNotEmpty) {
      _cachedRegistrationData = Map<String, dynamic>.from(fromProvider);
      return _cachedRegistrationData!;
    }
    return const {};
  }

  Future<void> _goToClientHome({bool showSuccessDialog = true}) async {
    ref.read(navigationIndexProvider.notifier).setIndex(0);
    const home = MainNavigationScreen();
    if (!mounted) return;
    if (showSuccessDialog) {
      await PayflexSweetAlert.showSuccess(
        context: context,
        title: 'Inscription réussie',
      text:
          'Votre compte PayFlex est actif.\n\n'
          'Finalisez votre adhésion (250 FCFA) pour activer les cotisations et les paiements : '
          'mobile money dans l’app ou espèces auprès de votre agent parrain.',
        confirmText: 'Découvrir l’application',
      );
      if (!mounted) return;
    }
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => home),
      (_) => false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPayflexNotificationsIfNeeded();
    });
    ref.read(tempRegistrationDataProvider.notifier).clear();
    ref.read(tempRoleProvider.notifier).setRole(null);
    ref.read(tempClientProfileProvider.notifier).setProfile(null);
    _cachedRegistrationData = null;
  }

  Future<void> _finishRegistrationSuccess({
    required String role,
    required String pin,
    required Map<String, dynamic> data,
    int? registrationId,
  }) async {
    final phone = (data['phone'] ?? '').toString().trim();
    PayflexApiLogger.info(
      'PIN terminé → login auto phone=${PayflexApiLogger.maskPhone(phone)} '
      'registrationId=$registrationId api=${ApiConfig.baseUrl}',
    );
    final loginOutcome = await ref.read(authProvider.notifier).login(phone, pin, loginMode: 'phone');
    if (!loginOutcome.success) {
      PayflexApiLogger.warn(
        'Login post-inscription échoué: ${loginOutcome.errorMessage} — session pending locale',
      );
      await ref.read(authProvider.notifier).establishPendingRegistrationSession(
            role: role,
            pin: pin,
            data: data,
            registrationId: registrationId,
          );
    } else {
      PayflexApiLogger.info('Login post-inscription OK');
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (role == 'agent') {
      ref.read(agentNavigationIndexProvider.notifier).setIndex(0);
      if (!mounted) return;
      await PayflexSweetAlert.showSuccess(
        context: context,
        title: 'Inscription réussie',
        text: 'Vos informations ont bien été enregistrées.',
        confirmText: 'Continuer',
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AgentMainNavigationScreen()),
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestPayflexNotificationsIfNeeded();
      });
      ref.read(tempRegistrationDataProvider.notifier).clear();
      ref.read(tempRoleProvider.notifier).setRole(null);
      _cachedRegistrationData = null;
      return;
    }

    await _goToClientHome();
  }

  Future<bool> _tryRecoverAfterFailedSubmit({
    required String role,
    required String pin,
    required Map<String, dynamic> data,
    String? serverMessage,
  }) async {
    final phone = (data['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return false;

    final recoveredId = await ref.read(authProvider.notifier).findPendingRegistrationIdForPhone(phone);
    if (recoveredId != null) {
      await _finishRegistrationSuccess(
        role: role,
        pin: pin,
        data: data,
        registrationId: recoveredId,
      );
      return true;
    }

    final loginOutcome = await ref.read(authProvider.notifier).login(phone, pin, loginMode: 'phone');
    if (loginOutcome.success) {
      await _finishRegistrationSuccess(role: role, pin: pin, data: data);
      return true;
    }

    final msg = (serverMessage ?? '').toLowerCase();
    if (msg.contains('déjà utilisé') || msg.contains('deja utilise')) {
      await ref.read(authProvider.notifier).establishPendingRegistrationSession(
            role: role,
            pin: pin,
            data: data,
          );
      await _goToClientHome();
      return true;
    }

    return false;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _pin;
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer 4 chiffres')),
      );
      return;
    }

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && auth.role == 'client') {
      await _goToClientHome(showSuccessDialog: false);
      return;
    }

    const role = 'client';
    final data = _registrationData();
    if (data.isEmpty) {
      if (auth.isAuthenticated) {
        await _goToClientHome(showSuccessDialog: false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Données d’inscription manquantes. Si vous venez de vous inscrire, connectez-vous avec votre numéro et votre code PIN.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    _showBlockingLoader();

    try {
      final result = await ref
          .read(authProvider.notifier)
          .submitPendingRegistration(role: role, pin: pin, data: data)
          .timeout(_submitTimeout);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!result.success) {
        final recovered = await _tryRecoverAfterFailedSubmit(
          role: role,
          pin: pin,
          data: data,
          serverMessage: result.message,
        );
        if (recovered) return;
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UserVisibleMessage.apiOrFallback(
                result.message,
                'Impossible de finaliser l’inscription. Vérifiez votre connexion ou contactez le support.',
              ),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      await _finishRegistrationSuccess(role: role, pin: pin, data: data, registrationId: result.registrationId);
    } on TimeoutException {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      final recovered = await _tryRecoverAfterFailedSubmit(role: role, pin: pin, data: data);
      if (recovered) return;

      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion lente : réessayez. Évitez d’appuyer plusieurs fois sur le bouton.'),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      final recovered = await _tryRecoverAfterFailedSubmit(
        role: role,
        pin: pin,
        data: data,
        serverMessage: UserVisibleMessage.forException(e),
      );
      if (recovered) return;

      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UserVisibleMessage.forException(e))),
      );
    }
  }

  void _showBlockingLoader() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enregistrement en cours…',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ne fermez pas l’application',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    if (_submitting) return;
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && auth.role == 'client') {
      unawaited(_goToClientHome(showSuccessDialog: false));
      return;
    }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _submitting) return;
        _handleBack();
      },
      child: AuthWaveBackground(
        child: SafeArea(
          child: AbsorbPointer(
            absorbing: _submitting,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: _submitting ? null : _handleBack,
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Créer votre code PIN',
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Entrez un code à 4 chiffres',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 48),
                  Center(
                    child: Container(
                      width: 100,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.lock_rounded, color: AppColors.secondary, size: 50),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).scale(),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Ce code PIN vous sera demandé pour :',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),
                  _buildFeatureTile(Icons.calendar_today_rounded, 'Valider vos cotisations'),
                  const SizedBox(height: 12),
                  _buildFeatureTile(Icons.people_alt_rounded, 'Valider vos opérations\navec un agent'),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, _buildPinBox),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: _submitting ? null : () => setState(() => _pinVisible = !_pinVisible),
                      icon: Icon(
                        _pinVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.secondary,
                      ),
                      label: Text(
                        _pinVisible ? 'Masquer le code' : 'Afficher le code saisi',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Text(
                      'Terminer l\'inscription',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                  ).animate().fadeIn(delay: 800.ms).scale(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05);
  }

  Widget _buildPinBox(int index) {
    final focused = _focusNodes[index].hasFocus;

    return SizedBox(
      width: 60,
      height: 70,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isNotEmpty) {
              _controllers[index].clear();
              setState(() {});
              return KeyEventResult.handled;
            }
            if (index > 0) {
              _controllers[index - 1].clear();
              _focusNodes[index - 1].requestFocus();
              setState(() {});
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          obscureText: !_pinVisible,
          obscuringCharacter: '•',
          enabled: !_submitting,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            height: 1.1,
          ),
          cursorColor: AppColors.secondary,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: focused ? AppColors.primary : Colors.grey.withValues(alpha: 0.28),
                width: focused ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: focused ? AppColors.primary : Colors.grey.withValues(alpha: 0.28),
                width: focused ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: (value) {
            final digits = value.replaceAll(RegExp(r'\D'), '');
            if (digits.length > 1) {
              _controllers[index].text = digits.substring(digits.length - 1);
              _controllers[index].selection = const TextSelection.collapsed(offset: 1);
            }
            if (_controllers[index].text.isNotEmpty && index < 3) {
              _focusNodes[index + 1].requestFocus();
            }
            setState(() {});
          },
        ),
      ),
    );
  }
}
