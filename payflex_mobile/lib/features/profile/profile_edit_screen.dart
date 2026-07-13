import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';

/// Modification du profil client (atelier, patron, quartier — spec PDF 1.4).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _professionCtrl;
  late final TextEditingController _workplaceCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _bossNameCtrl;
  late final TextEditingController _bossPhoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _cityCtrl = TextEditingController(text: auth.city ?? '');
    _professionCtrl = TextEditingController(text: auth.profession ?? '');
    _workplaceCtrl = TextEditingController(text: auth.workplaceName ?? '');
    _addressCtrl = TextEditingController(text: auth.workplaceAddress ?? '');
    _bossNameCtrl = TextEditingController(text: auth.bossName ?? '');
    _bossPhoneCtrl = TextEditingController(text: auth.bossPhone ?? '');
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _professionCtrl.dispose();
    _workplaceCtrl.dispose();
    _addressCtrl.dispose();
    _bossNameCtrl.dispose();
    _bossPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    setState(() => _saving = true);
    final err = await MobileApiService().updateClientProfile(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
      city: _cityCtrl.text.trim(),
      profession: _professionCtrl.text.trim(),
      workplaceName: _workplaceCtrl.text.trim(),
      workplaceAddress: _addressCtrl.text.trim(),
      bossName: _bossNameCtrl.text.trim(),
      bossPhone: _bossPhoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await ref.read(authProvider.notifier).refreshProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Modifier le profil', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field('Ville', _cityCtrl),
          _field('Métier', _professionCtrl),
          _field('Atelier / lieu de travail', _workplaceCtrl),
          _field('Quartier / adresse', _addressCtrl),
          _field('Nom du patron', _bossNameCtrl),
          _field('Téléphone patron', _bossPhoneCtrl, keyboard: TextInputType.phone),
          const SizedBox(height: 24),
          if (_saving)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text('Enregistrer', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
