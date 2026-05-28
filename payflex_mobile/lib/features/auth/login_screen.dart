import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../main_navigation_screen.dart';
import 'role_selection_screen.dart';
import 'widgets/payflex_logo.dart';
import 'widgets/auth_wave_background.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_config.dart';
import '../../core/network/payflex_api_logger.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/user_visible_message.dart';
import '../../core/utils/phone_input_utils.dart';
import '../../core/widgets/payflex_phone_field.dart';
import '../agent/agent_main_navigation_screen.dart';
import '../../core/providers/navigation_provider.dart';
import 'forgot_password_verify_screen.dart';

enum _LoginMethod { phone, name, email }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.recoverySuccessMessage, this.registrationSuccessMessage});

  /// Affiché une fois au chargement après réinitialisation PIN / code secret.
  final String? recoverySuccessMessage;

  /// Affiché une fois après envoi réussi de la demande d'inscription.
  final String? registrationSuccessMessage;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pinController = TextEditingController();
  _LoginMethod _method = _LoginMethod.phone;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  TextStyle get _fieldStyle => GoogleFonts.inter(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500);

  @override
  void initState() {
    super.initState();
    final msg = widget.registrationSuccessMessage ?? widget.recoverySuccessMessage;
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String _loginModeParam() {
    switch (_method) {
      case _LoginMethod.phone:
        return 'phone';
      case _LoginMethod.name:
        return 'name';
      case _LoginMethod.email:
        return 'email';
    }
  }

  String _buildIdentifier() {
    switch (_method) {
      case _LoginMethod.phone:
        return _phoneCtrl.text.trim();
      case _LoginMethod.name:
        return _nameCtrl.text.trim();
      case _LoginMethod.email:
        return _emailCtrl.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                Center(
                  child: const PayFlexLogo(size: 96),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

                const SizedBox(height: 60),

                Text(
                  'Bienvenue',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ).animate().fadeIn(delay: 200.ms),

                Text(
                  'Connectez-vous pour gérer vos actifs.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                _buildMethodSelector(),
                const SizedBox(height: 20),
                _buildIdentifierField(),

                const SizedBox(height: 20),

                _buildPasswordField(
                  'Mot de passe ou code PIN',
                  _isPasswordVisible,
                  _pinController,
                  (v) => setState(() => _isPasswordVisible = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre mot de passe ou code PIN' : null,
                ),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const ForgotPasswordVerifyScreen()),
                      );
                    },
                    child: Text(
                      'Mot de passe ou PIN oublié ?',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms),

                const SizedBox(height: 40),

                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : ElevatedButton(
                        onPressed: _onLogin,
                        child: const Text('SE CONNECTER'),
                      ).animate().fadeIn(delay: 1.seconds).scale(),

                const SizedBox(height: 32),

                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Nouveau client sur PayFlex ? ',
                        style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'S’inscrire',
                            style: TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1.2.seconds),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return SegmentedButton<_LoginMethod>(
      segments: const [
        ButtonSegment(
          value: _LoginMethod.phone,
          label: Text('Téléphone'),
          icon: Icon(Icons.phone_outlined, size: 18),
        ),
        ButtonSegment(
          value: _LoginMethod.name,
          label: Text('Nom'),
          icon: Icon(Icons.person_outline_rounded, size: 18),
        ),
        ButtonSegment(
          value: _LoginMethod.email,
          label: Text('E-mail'),
          icon: Icon(Icons.email_outlined, size: 18),
        ),
      ],
      selected: {_method},
      onSelectionChanged: (selected) {
        setState(() => _method = selected.first);
      },
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.secondary;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.secondary;
          return Colors.white;
        }),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildIdentifierField() {
    switch (_method) {
      case _LoginMethod.phone:
        return PayflexPhoneField(
          completeNumberController: _phoneCtrl,
          hint: 'Ex. 90000000',
          textStyle: _fieldStyle,
          validator: (v) => PayflexPhoneValidator.validate(v),
        ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05);
      case _LoginMethod.name:
        return _buildField(
          Icons.badge_outlined,
          'Prénom, nom ou les deux',
          controller: _nameCtrl,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.length < 2) return 'Saisissez au moins 2 caractères';
            return null;
          },
        );
      case _LoginMethod.email:
        return _buildField(
          Icons.email_outlined,
          'Adresse e-mail',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'E-mail requis';
            if (!t.contains('@') || !t.contains('.')) return 'Adresse e-mail invalide';
            return null;
          },
        );
    }
  }

  Future<void> _onLogin() async {
    if (_formKey.currentState!.validate()) {
      final String identifier = _buildIdentifier();
      final String pin = _pinController.text.trim();
      final String mode = _loginModeParam();
      PayflexApiLogger.info(
        'Écran login → mode=$mode identifier=${PayflexApiLogger.maskPhone(identifier)} '
        'api=${ApiConfig.baseUrl}',
      );
      setState(() => _isLoading = true);
      try {
        final outcome = await ref.read(authProvider.notifier).login(identifier, pin, loginMode: mode);
        if (!context.mounted) return;
        if (outcome.success && ref.read(authProvider).isAuthenticated) {
          _navigateAfterLogin(context, ref);
        } else if (outcome.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion incomplète. Réessayez.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                UserVisibleMessage.apiOrFallback(
                  outcome.errorMessage,
                  'Connexion impossible. Réessayez.',
                ),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (context.mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _navigateAfterLogin(BuildContext context, WidgetRef ref) {
    final role = ref.read(authProvider).role;
    ref.read(navigationIndexProvider.notifier).setIndex(0);
    if (role == 'agent') {
      ref.read(agentNavigationIndexProvider.notifier).setIndex(0);
    }
    final Widget nextScreen = role == 'agent'
        ? const AgentMainNavigationScreen()
        : const MainNavigationScreen();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => nextScreen),
      (_) => false,
    );
  }

  Widget _buildField(
    IconData icon,
    String hint, {
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: false,
      style: _fieldStyle,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 15),
        prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        errorStyle: const TextStyle(fontSize: 10),
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05);
  }

  Widget _buildPasswordField(String hint, bool isVisible, TextEditingController controller, Function(bool) toggle, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      style: _fieldStyle,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 15),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          onPressed: () => toggle(!isVisible),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        errorStyle: const TextStyle(fontSize: 10),
      ),
    ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.05);
  }
}
