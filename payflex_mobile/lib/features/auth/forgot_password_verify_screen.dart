import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/utils/user_visible_message.dart';
import 'forgot_password_reset_screen.dart';
import '../../core/widgets/payflex_phone_field.dart';
import '../../core/utils/phone_input_utils.dart';
import 'widgets/auth_wave_background.dart';

/// Étape 1 — Vérification d’identité pour « mot de passe oublié ».
class ForgotPasswordVerifyScreen extends StatefulWidget {
  const ForgotPasswordVerifyScreen({super.key});

  @override
  State<ForgotPasswordVerifyScreen> createState() => _ForgotPasswordVerifyScreenState();
}

class _ForgotPasswordVerifyScreenState extends State<ForgotPasswordVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _fullName = TextEditingController();
  final _uniqueCode = TextEditingController();
  final _api = MobileApiService();
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _fullName.dispose();
    _uniqueCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Récupération du compte',
                  style: GoogleFonts.manrope(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Indiquez les mêmes informations que lors de votre inscription PayFlex. '
                  'Sélectionnez votre pays et saisissez votre numéro (Togo +228 par défaut).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 28),
                PayflexPhoneField(
                  completeNumberController: _phone,
                  hint: 'Numéro de téléphone',
                  validator: (v) => PayflexPhoneValidator.validate(v),
                ),
                const SizedBox(height: 16),
                _field(
                  Icons.badge_outlined,
                  'Nom et prénom (identique à l’inscription)',
                  _fullName,
                  (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                const SizedBox(height: 16),
                _field(
                  Icons.qr_code_2_rounded,
                  'Code unique PayFlex',
                  _uniqueCode,
                  (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                const SizedBox(height: 28),
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: AppColors.primary))
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text('Vérifier mes informations', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    IconData icon,
    String hint,
    TextEditingController c,
    String? Function(String?)? validator, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: c,
      validator: validator,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.black87, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final outcome = await _api.requestAccountRecovery(
      phone: _phone.text,
      fullName: _fullName.text,
      uniqueCode: _uniqueCode.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (outcome.ok && outcome.resetToken != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ForgotPasswordResetScreen(resetToken: outcome.resetToken!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UserVisibleMessage.apiOrFallback(outcome.message, 'Vérification impossible. Vérifiez vos informations.'),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
