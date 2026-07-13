import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/registration_form_theme.dart';

/// Signalement multimédia (spec PDF module 11 / phase 3.1).
class ClientReportScreen extends ConsumerStatefulWidget {
  const ClientReportScreen({super.key});

  @override
  ConsumerState<ClientReportScreen> createState() => _ClientReportScreenState();
}

class _ClientReportScreenState extends ConsumerState<ClientReportScreen> {
  final _bodyCtrl = TextEditingController();
  String _category = 'autre';
  File? _photo;
  bool _sending = false;

  static const _categories = {
    'autre': 'Autre',
    'agent': 'Agent terrain',
    'cotisation': 'Cotisation',
    'produit': 'Produit / livraison',
    'fraude': 'Fraude / confiance',
  };

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x != null) setState(() => _photo = File(x.path));
  }

  Future<void> _send() async {
    final text = _bodyCtrl.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décrivez le problème (10 caractères minimum).')),
      );
      return;
    }
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    setState(() => _sending = true);
    final payload = StringBuffer()
      ..writeln('[Signalement — ${_categories[_category]}]')
      ..writeln(text);
    if (_photo != null) payload.writeln('\n(Pièce jointe photo envoyée séparément si support étendu.)');
    final ok = await MobileApiService().sendSupportChatMessage(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
      body: payload.toString(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Signalement transmis au centre PayFlex.' : 'Échec d\'envoi.')),
    );
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Signaler un problème',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.secondary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RegistrationFormTheme.infoBanner(
            'Décrivez votre problème : un gestionnaire PayFlex traitera votre signalement.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: RegistrationFormTheme.labeled('Catégorie'),
            dropdownColor: Colors.white,
            style: RegistrationFormTheme.fieldStyle(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.secondary),
            items: _categories.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'autre'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyCtrl,
            maxLines: 5,
            style: RegistrationFormTheme.fieldStyle(context),
            decoration: RegistrationFormTheme.labeled(
              'Description',
              hint: 'Texte, contexte, dates…',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            style: RegistrationFormTheme.secondaryOutlineButton(),
            icon: Icon(
              _photo == null ? Icons.photo_camera_outlined : Icons.check_circle_outline,
              color: _photo == null ? AppColors.primary : AppColors.success,
            ),
            label: Text(_photo == null ? 'Ajouter une photo' : 'Photo sélectionnée'),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_photo!, height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Audio et vidéo : utilisez la messagerie support pour envoyer un fichier volumineux.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 24),
          if (_sending)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else
            FilledButton(
              onPressed: _send,
              style: RegistrationFormTheme.primaryActionButton(),
              child: const Text('Envoyer le signalement'),
            ),
        ],
      ),
    );
  }
}
