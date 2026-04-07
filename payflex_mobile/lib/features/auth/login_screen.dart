import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../main_navigation_screen.dart';
import 'role_selection_screen.dart';
import 'widgets/payflex_logo.dart';
import 'widgets/auth_wave_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // Forcer le scroll !
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50), // Marge supérieure augmentée pour descendre le logo
                // Header Logo (Même style que l'inscription)
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
                    color: AppColors.onSurfaceVariant.withOpacity(0.7),
                  ),
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 48),
                
                // Form Fields
                _buildField(
                  Icons.person_outline_rounded, 
                  'Identifiant', 
                  validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre identifiant' : null
                ),
                
                const SizedBox(height: 20),
                
                _buildPasswordField(
                  'Mot de passe', 
                  _isPasswordVisible, 
                  (v) => setState(() => _isPasswordVisible = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre mot de passe' : null
                ),
                
                const SizedBox(height: 12),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms),
                
                const SizedBox(height: 40),
                
                // Login Button
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                      );
                    }
                  },
                  child: const Text('SE CONNECTER'),
                ).animate().fadeIn(delay: 1.seconds).scale(),
                
                const SizedBox(height: 32),
                
                // Footer
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
                        text: 'Nouveau sur PayFlex ? ',
                        style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Créer un compte',
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
                
                const SizedBox(height: 120), // Space for waves
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(IconData icon, String hint, {String? Function(String?)? validator}) {
    return TextFormField(
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
    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05);
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
    ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.05);
  }
}
