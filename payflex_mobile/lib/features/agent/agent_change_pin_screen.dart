import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/biometric_auth_service.dart';
import '../../core/utils/user_visible_message.dart';
import '../../core/widgets/registration_form_theme.dart';

class AgentChangePinScreen extends ConsumerStatefulWidget {
  const AgentChangePinScreen({super.key});

  @override
  ConsumerState<AgentChangePinScreen> createState() => _AgentChangePinScreenState();
}

class _AgentChangePinScreenState extends ConsumerState<AgentChangePinScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _api = MobileApiService();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPin = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.length < 4 || newPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le code PIN doit contenir au moins 4 chiffres.')),
      );
      return;
    }
    if (newPin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La confirmation ne correspond pas.')),
      );
      return;
    }
    if (!RegExp(r'^\d{4,12}$').hasMatch(newPin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le PIN doit contenir uniquement des chiffres (4 à 12).')),
      );
      return;
    }

    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.phone == null) return;

    setState(() => _saving = true);
    try {
      final res = await _api.changeAgentPin(
        userId: auth.userId!,
        phone: auth.phone!,
        pin: auth.pin ?? '',
        currentPin: current,
        newPin: newPin,
      );
      if (!mounted) return;
      if (res == null || res['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message']?.toString() ?? 'Échec de la mise à jour.')),
        );
        return;
      }
      await ref.read(authProvider.notifier).updateSessionPin(newPin);
      await BiometricAuthService.updateStoredPin(newPin);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code PIN agent mis à jour.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserVisibleMessage.forException(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Modifier mon PIN', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RegistrationFormTheme.infoBanner(
            'Choisissez un nouveau code PIN à 4 chiffres minimum. Il servira pour vos connexions et validations terrain.',
          ),
          const SizedBox(height: 20),
          _pinField(_currentCtrl, 'PIN actuel', _showCurrent, () => setState(() => _showCurrent = !_showCurrent)),
          const SizedBox(height: 14),
          _pinField(_newCtrl, 'Nouveau PIN', _showNew, () => setState(() => _showNew = !_showNew)),
          const SizedBox(height: 14),
          _pinField(_confirmCtrl, 'Confirmer le nouveau PIN', _showConfirm, () => setState(() => _showConfirm = !_showConfirm)),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: RegistrationFormTheme.primaryActionButton(),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer le nouveau PIN'),
          ),
        ],
      ),
    );
  }

  Widget _pinField(TextEditingController ctrl, String label, bool visible, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !visible,
      keyboardType: TextInputType.number,
      style: RegistrationFormTheme.fieldStyle(context),
      decoration: RegistrationFormTheme.labeled(label).copyWith(
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: toggle,
        ),
      ),
    );
  }
}
