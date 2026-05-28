import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/utils/registration_file_store.dart';
import '../../core/widgets/payflex_phone_field.dart';
import '../../core/utils/phone_input_utils.dart';
import 'widgets/auth_wave_background.dart';
import 'widgets/payflex_logo.dart';
import 'pin_setup_screen.dart';
import 'login_screen.dart';
import 'package:image_picker/image_picker.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  TextStyle get _fieldStyle => GoogleFonts.inter(color: Colors.black, fontSize: 15);

  final _formStep1 = GlobalKey<FormState>();
  final _formStep2 = GlobalKey<FormState>();
  final _formStep3 = GlobalKey<FormState>();

  int _step = 0;

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _metierCtrl = TextEditingController();
  final _lieuTravailQuartierCtrl = TextEditingController();

  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _bossNameCtrl = TextEditingController();
  final _bossPhoneCtrl = TextEditingController();

  String _gender = 'Homme';
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  File? _profilePhoto;
  File? _idDocument;
  bool _noIdDocument = false;

  final _api = MobileApiService();
  List<Map<String, dynamic>> _agentChoices = [];
  bool _agentsLoading = true;
  int? _selectedAgentUserId;
  bool _noAgentSelected = false;
  bool _navigatingToPin = false;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final list = await _api.fetchRegistrationAgentChoices();
    if (!mounted) return;
    setState(() {
      _agentChoices = list;
      _agentsLoading = false;
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _metierCtrl.dispose();
    _lieuTravailQuartierCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _bossNameCtrl.dispose();
    _bossPhoneCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    final keys = [_formStep1, _formStep2, _formStep3];
    if (_step < 3 && keys[_step].currentState?.validate() == true) {
      setState(() => _step++);
    }
  }

  void _goBack() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finishAndGoToPin() async {
    if (_navigatingToPin) return;
    if (_formStep3.currentState?.validate() != true) return;
    if (!_noAgentSelected && (_selectedAgentUserId == null || _selectedAgentUserId! <= 0)) {
      if (_agentChoices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Liste agents indisponible : cochez « Je n’ai pas encore d’agent » pour payer l’adhésion en mobile money.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisissez un agent ou cochez « Je n’ai pas encore d’agent ».')),
        );
      }
      return;
    }
    if (!_validateStep2Files()) return;

    final lieu = _lieuTravailQuartierCtrl.text.trim();
    File? photo = _profilePhoto;
    photo = await RegistrationFileStore.persist(photo!, 'profile');
    File? doc;
    if (!_noIdDocument && _idDocument != null) {
      doc = await RegistrationFileStore.persist(_idDocument!, 'identity');
    }
    if (photo == null || (!_noIdDocument && doc == null)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de préparer les pièces jointes. Réessayez.')),
      );
      return;
    }

    final clientProfile = ref.read(tempClientProfileProvider);
    ref.read(tempRegistrationDataProvider.notifier).setData({
      'fullName': '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}'.trim(),
      'clientProfile': clientProfile,
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'profession': _metierCtrl.text.trim(),
      'gender': registrationGenderCode(_gender),
      'workplaceName': lieu,
      'workplaceAddress': lieu,
      'bossName': _bossNameCtrl.text.trim(),
      'bossPhone': _bossPhoneCtrl.text.trim(),
      'assignedAgentUserId': _noAgentSelected ? null : _selectedAgentUserId,
      'noAgent': _noAgentSelected,
      'accountPassword': _passwordCtrl.text.trim(),
      'submittedBy': 'self',
      'profilePhoto': photo,
      'idDocument': doc,
      'idDocumentWaived': _noIdDocument,
    });

    if (!mounted) return;
    setState(() => _navigatingToPin = true);
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PinSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _step == 0
                        ? () => Navigator.maybePop(context)
                        : _goBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: const PayFlexLogo(size: 88),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 28),
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'Inscription',
                      style: GoogleFonts.manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stepSubtitle(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: KeyedSubtree(
                        key: ValueKey<int>(_step),
                        child: _stepContent(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildPrimaryActions(),
                    const SizedBox(height: 20),
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
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepSubtitle() {
    switch (_step) {
      case 0:
        return 'Étape 1 — Vos informations personnelles';
      case 1:
        return 'Étape 2 — Sécurité et pièces jointes';
      case 2:
        return 'Étape 3 — Référence professionnelle';
      default:
        return '';
    }
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepIndicator() {
    Widget stepColumn(int i, String n, String title) {
      final active = _step >= i;
      final current = _step == i;
      return Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.secondary : Colors.white,
              border: Border.all(
                color: active ? AppColors.secondary : Colors.grey.shade400,
                width: 2,
              ),
              boxShadow: current
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                n,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: active ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.secondary : Colors.grey.shade600,
            ),
          ),
        ],
      );
    }

    Widget connector(int segmentIndex) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 26),
          child: Align(
            alignment: Alignment.center,
            child: Divider(
              thickness: 2,
              color: _step > segmentIndex ? AppColors.secondary : Colors.grey.shade300,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: stepColumn(0, '1', 'Infos')),
        connector(0),
        Expanded(child: stepColumn(1, '2', 'Sécurité')),
        connector(1),
        Expanded(child: stepColumn(2, '3', 'Parrain')),
      ],
    );
  }

  InputDecoration _decor(IconData icon, String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant.withValues(alpha: 0.55)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nomCtrl,
            style: _fieldStyle,
            decoration: _decor(Icons.badge_outlined, 'Nom'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _prenomCtrl,
            style: _fieldStyle,
            decoration: _decor(Icons.person_outline_rounded, 'Prénom(s)'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
          ),
          const SizedBox(height: 18),
          Text(
            'Sexe',
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color.fromARGB(255, 1, 85, 182)),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Homme', label: Text('Homme'), icon: Icon(Icons.male, size: 18)),
              ButtonSegment(value: 'Femme', label: Text('Femme'), icon: Icon(Icons.female, size: 18)),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return const Color.fromARGB(255, 238, 160, 15);
                return Colors.black87;
              }),
            ),
          ),
          const SizedBox(height: 14),
          PayflexPhoneField(
            completeNumberController: _phoneCtrl,
            hint: 'Ex. 90000000',
            textStyle: _fieldStyle,
            validator: (v) => PayflexPhoneValidator.validate(v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailCtrl,
            style: _fieldStyle,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: _decor(Icons.email_outlined, 'E-mail (facultatif)'),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              if (!t.contains('@') || !t.contains('.')) return 'Adresse e-mail invalide';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _metierCtrl,
            style: _fieldStyle,
            decoration: _decor(Icons.build_circle_outlined, 'Métier'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Métier requis' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cityCtrl,
            style: _fieldStyle,
            decoration: _decor(Icons.location_on_outlined, 'Ville'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ville requise' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _lieuTravailQuartierCtrl,
            style: _fieldStyle,
            decoration: _decor(Icons.maps_home_work_outlined, 'Lieu de travail / établissement'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez votre quartier ou lieu de travail' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Choisissez un mot de passe (connexion) puis un code PIN à 4 chiffres à l’étape suivante.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.secondary, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: !_isPasswordVisible,
            style: _fieldStyle,
            decoration: _decor(
              Icons.lock_outline_rounded,
              'Mot de passe (connexion)',
              suffix: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (v) => (v == null || v.trim().length < 6) ? 'Au moins 6 caractères' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: !_isConfirmVisible,
            style: _fieldStyle,
            decoration: _decor(
              Icons.lock_outline_rounded,
              'Confirmer le mot de passe',
              suffix: IconButton(
                icon: Icon(
                  _isConfirmVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                onPressed: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
              ),
            ),
            validator: (v) => (v != _passwordCtrl.text) ? 'Les mots de passe ne correspondent pas' : null,
          ),
          const SizedBox(height: 20),
          Text(
            'Pièces jointes',
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondary),
          ),
          const SizedBox(height: 10),
          _buildFilePicker(
            'Photo de profil',
            _profilePhoto != null ? _basename(_profilePhoto!.path) : 'Aucune photo',
            Icons.photo_camera_outlined,
            _pickProfilePhoto,
          ),
          const SizedBox(height: 12),
          _buildFilePicker(
            'Carte d’identité ou passeport',
            _noIdDocument
                ? 'Non fourni (case cochée)'
                : (_idDocument != null ? _basename(_idDocument!.path) : 'Aucun fichier'),
            Icons.badge_outlined,
            _noIdDocument ? null : _pickIdDocument,
            enabled: !_noIdDocument,
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: CheckboxListTile(
              value: _noIdDocument,
              onChanged: (v) {
                setState(() {
                  _noIdDocument = v ?? false;
                  if (_noIdDocument) _idDocument = null;
                });
              },
              activeColor: AppColors.primary,
              checkColor: AppColors.secondary,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Je n’ai pas de carte d’identité ni de passeport',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Cochez uniquement si vous ne disposez d’aucune pièce officielle.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validation pièces jointes : explicite car hors FormField.
  bool _validateStep2Files() {
    if (_profilePhoto == null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ajoutez une photo de profil.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return false;
    }
    if (!_noIdDocument && _idDocument == null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ajoutez une pièce d’identité, ou cochez l’option si vous n’en avez pas.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Widget _buildStep3() {
    return Form(
      key: _formStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Agent PayFlex (optionnel)',
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.secondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Si un agent vous a invité, il encaissera votre adhésion (250 FCFA) en espèces. Sinon, payez l’adhésion en mobile money dans l’application.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _noAgentSelected,
            onChanged: _agentsLoading
                ? null
                : (v) => setState(() {
                      _noAgentSelected = v == true;
                      if (_noAgentSelected) _selectedAgentUserId = null;
                    }),
            title: Text(
              'Je n’ai pas encore d’agent PayFlex',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Paiement adhésion 250 FCFA par mobile money (FedaPay) dans l’app',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (!_noAgentSelected) ...[
          if (_agentsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_agentChoices.isEmpty)
            Text(
              'Liste des agents indisponible. Vérifiez votre connexion et réessayez.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700),
            )
          else
            DropdownButtonFormField<int>(
              value: _selectedAgentUserId,
              dropdownColor: Colors.white,
              iconEnabledColor: AppColors.secondary,
              style: _fieldStyle,
              decoration: _decor(Icons.support_agent_rounded, 'Agent qui m\'a invité'),
              items: _agentChoices
                  .map((a) {
                    final id = (a['id'] as num?)?.toInt();
                    final name = (a['fullName'] ?? a['full_name'] ?? 'Agent').toString();
                    if (id == null) return null;
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        name,
                        style: GoogleFonts.inter(color: Colors.black87, fontSize: 15),
                      ),
                    );
                  })
                  .whereType<DropdownMenuItem<int>>()
                  .toList(),
              onChanged: (v) => setState(() => _selectedAgentUserId = v),
              validator: (v) {
                if (_noAgentSelected) return null;
                return v == null ? 'Choisissez votre agent ou cochez l’option ci-dessus' : null;
              },
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Patron ou formateur (optionnel)',
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bossNameCtrl,
            style: _fieldStyle,
            decoration: _decor(Icons.person_pin_circle_outlined, 'Nom du patron / formateur'),
          ),
          const SizedBox(height: 14),
          PayflexPhoneField(
            completeNumberController: _bossPhoneCtrl,
            hint: 'Téléphone du patron / formateur',
            required: false,
            textStyle: _fieldStyle,
            validator: (v) => PayflexPhoneValidator.validate(v, required: false),
          ),
          const SizedBox(height: 16),
          Text(
            'Ces informations nous aident à valider votre activité. Vous pouvez les compléter plus tard si besoin.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions() {
    if (_step < 2) {
      return ElevatedButton(
        onPressed: () {
          if (_step == 1) {
            if (_formStep2.currentState?.validate() != true) return;
            if (!_validateStep2Files()) return;
          }
          _goNext();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          'Suivant',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ).animate().fadeIn(delay: 100.ms);
    }

    return ElevatedButton(
      onPressed: () async => _finishAndGoToPin(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        'Continuer vers le code PIN',
        style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  String _basename(String path) {
    final s = path.replaceAll('\\', '/');
    final i = s.lastIndexOf('/');
    return i < 0 ? s : s.substring(i + 1);
  }

  Widget _buildFilePicker(
    String label,
    String value,
    IconData icon,
    VoidCallback? onTap, {
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: enabled ? 0.25 : 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.onSurfaceVariant.withValues(alpha: 0.65)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label : $value',
                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.black87),
              ),
            ),
            const Icon(Icons.upload_file_rounded, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xFile == null) return;
    final raw = File(xFile.path);
    final stored = await RegistrationFileStore.persist(raw, 'profile');
    if (stored != null && mounted) {
      setState(() => _profilePhoto = stored);
    }
  }

  Future<void> _pickIdDocument() async {
    final picked = await FilePicker.platform.pickFiles(withData: false);
    if (picked == null || picked.files.single.path == null) return;
    final raw = File(picked.files.single.path!);
    final stored = await RegistrationFileStore.persist(raw, 'identity');
    if (stored != null && mounted) {
      setState(() => _idDocument = stored);
    }
  }
}
