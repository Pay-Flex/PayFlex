import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/providers/chat_provider.dart';

class CustomRequestScreen extends StatefulWidget {
  const CustomRequestScreen({super.key});

  @override
  State<CustomRequestScreen> createState() => _CustomRequestScreenState();
}

class _CustomRequestScreenState extends State<CustomRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSending = false;

  Future<void> _submitRequest(WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    
    try {
      final db = DatabaseService();
      await db.saveCustomRequest(
        _nameController.text.trim(),
        _descController.text.trim(),
        _phoneController.text.trim(),
      );

      // On attend un court instant pour l'effet "Elite"
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Rafraîchir le chat pour voir le message système
        ref.read(chatProvider.notifier).loadMessages();
        _showSuccessDialog();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFF0FFF4), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF38A169), size: 60),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Demande reçue !',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.secondary)),
            const SizedBox(height: 12),
            Text('Un administrateur PayFlex analysera votre demande et vous contactera sous 24h.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Ferme le dialog
                  Navigator.pop(context); // Retourne au chat
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Compris !', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Demande Spéciale',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18)),
        centerTitle: true,
      ),
      body: Consumer(
        builder: (context, ref, child) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Vous cherchez un produit spécifique ? Décrivez-le nous et nous l\'ajouterons pour vous.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.secondary.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 32),

                // Champs de saisie
                _buildFieldLabel('Quel produit souhaitez-vous ?'),
                _buildTextField(
                  controller: _nameController,
                  hint: 'Ex: Panneaux Solaires 200W, Moulin...',
                  icon: Icons.shopping_bag_outlined,
                  validator: (v) => v!.isEmpty ? 'Veuillez saisir le nom du produit' : null,
                ),

                const SizedBox(height: 24),

                _buildFieldLabel('Décrivez brièvement (marque, puissance, etc.)'),
                _buildTextField(
                  controller: _descController,
                  hint: 'Détails supplémentaires...',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                  validator: (v) => v!.isEmpty ? 'Veuillez ajouter une description' : null,
                ),

                const SizedBox(height: 24),

                _buildFieldLabel('Votre numéro personnel (pour le rappel)'),
                _buildTextField(
                  controller: _phoneController,
                  hint: 'Ex: 77 000 00 00',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Le numéro est obligatoire' : null,
                ),

                const SizedBox(height: 48),

                // Bouton validation
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : () => _submitRequest(ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('ENVOYER MA DEMANDE ',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.secondary)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
