import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/auth_wave_background.dart';
import 'widgets/payflex_logo.dart';
import 'pin_setup_screen.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30), // Marge supérieure pour descendre le logo
                // Header Logo
                Center(
                  child: Column(
                    children: [
                      const PayFlexLogo(size: 80),
                      const SizedBox(height: 8),
                      Text(
                        'PayFlex',
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
                
                const SizedBox(height: 40),
                
                Text(
                  'Inscription',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                
                Text(
                  'Créez votre compte PayFlex',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant.withOpacity(0.7),
                  ),
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 32),
                
                // Form Fields
                _buildField(Icons.person_outline_rounded, 'Nom', validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre nom' : null),
                const SizedBox(height: 16),
                _buildField(Icons.person_outline_rounded, 'Prénom', validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre prénom' : null),
                const SizedBox(height: 16),
                _buildField(Icons.phone_outlined, 'Téléphone', keyboardType: TextInputType.phone, 
                    validator: (v) => (v == null || v.length < 8) ? 'Numéro de téléphone invalide' : null),
                const SizedBox(height: 16),
                _buildField(Icons.location_on_outlined, 'Ville', validator: (v) => (v == null || v.isEmpty) ? 'Veuillez spécifier votre ville' : null),
                const SizedBox(height: 16),
                _buildPasswordField('Mot de passe', _isPasswordVisible, (v) => setState(() => _isPasswordVisible = v),
                    validator: (v) => (v == null || v.length < 6) ? 'Le mot de passe doit faire 6 caractères min' : null),
                const SizedBox(height: 16),
                _buildPasswordField('Confirmation mot de passe', _isConfirmVisible, (v) => setState(() => _isConfirmVisible = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Veuillez confirmer votre mot de passe' : null),
                
                const SizedBox(height: 48),
                
                // Submit Button
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PinSetupScreen()),
                      );
                    }
                  },
                  child: const Text('Créer mon compte'),
                ).animate().fadeIn(delay: 800.ms).scale(),
                
                const SizedBox(height: 24),
                
                // Footer
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Vous avez déjà un compte ? ',
                        style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Se connecter',
                            style: TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1.seconds),
                
                const SizedBox(height: 120), // Space for waves
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(IconData icon, String hint, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        errorStyle: const TextStyle(fontSize: 10),
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05);
  }

  Widget _buildPasswordField(String hint, bool isVisible, Function(bool) toggle, {String? Function(String?)? validator}) {
    return TextFormField(
      obscureText: !isVisible,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.onSurfaceVariant.withOpacity(0.5),
          ),
          onPressed: () => toggle(!isVisible),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        errorStyle: const TextStyle(fontSize: 10),
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05);
  }
}
