import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/models/product_model.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/catalogue_provider.dart';
import '../catalogue/product_detail_screen.dart';
import '../../core/utils/phone_input_utils.dart';
import '../../core/utils/registration_file_store.dart' show RegistrationFileStore, registrationGenderCode;
import '../../core/utils/user_visible_message.dart';
import '../../core/widgets/payflex_phone_field.dart';
import '../../core/widgets/registration_form_theme.dart';
import '../auth/widgets/auth_wave_background.dart';

/// Inscription d’un client par un agent — même parcours que l’auto-inscription + catalogue.
class AgentEnrollmentScreen extends ConsumerStatefulWidget {
  const AgentEnrollmentScreen({
    super.key,
    this.fromCart = false,
    this.seedProductId,
    this.seedQuantity = 1,
    this.seedDailyContribution,
  });

  final bool fromCart;
  final String? seedProductId;
  final int seedQuantity;
  final double? seedDailyContribution;

  @override
  ConsumerState<AgentEnrollmentScreen> createState() => _AgentEnrollmentScreenState();
}

class _AgentEnrollmentScreenState extends ConsumerState<AgentEnrollmentScreen> {
  final DatabaseService _dbService = DatabaseService();
  final MobileApiService _api = MobileApiService();

  final _formStep1 = GlobalKey<FormState>();
  final _formStep2 = GlobalKey<FormState>();
  final _formStep4 = GlobalKey<FormState>();

  int _step = 0;
  bool _isSaving = false;

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _metierCtrl = TextEditingController();
  final _lieuTravailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _bossNameCtrl = TextEditingController();
  final _bossPhoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  final _dailyAmountCtrl = TextEditingController();

  String _gender = 'Homme';
  String _financingType = 'cotisation_journaliere';
  bool _clientWithoutPhone = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _isPinVisible = false;
  bool _isPinConfirmVisible = false;
  File? _profilePhoto;
  File? _idDocument;
  bool _noIdDocument = false;

  final Set<int> _selectedProductIndices = {};
  final Map<int, int> _productQuantities = {};
  List<Product> _products = [];
  bool _isLoadingProducts = true;

  TextStyle get _fieldStyle => RegistrationFormTheme.fieldStyle(context);

  double get _totalProjectAmount => _selectedProductIndices.fold(0.0, (sum, i) {
        final qty = _productQuantities[i] ?? 1;
        return sum + _products[i].price * qty;
      });

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _metierCtrl.dispose();
    _lieuTravailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _bossNameCtrl.dispose();
    _bossPhoneCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    _dailyAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final maps = await _api.fetchProducts();
      if (maps.isNotEmpty) {
        _products = maps.map(Product.fromMap).toList();
      } else {
        final local = await _dbService.getCatalogueItems();
        _products = local.map(Product.fromMap).toList();
      }
    } catch (_) {
      final local = await _dbService.getCatalogueItems();
      _products = local.map(Product.fromMap).toList();
    } finally {
      if (mounted) {
        _applyProductSeeds();
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  void _applyProductSeeds() {
    if (widget.fromCart) {
      final cart = ref.read(catalogueProvider).cart;
      for (var i = 0; i < _products.length; i++) {
        final matches = cart.where((l) => l.product.id == _products[i].id).toList();
        if (matches.isNotEmpty) {
          _selectedProductIndices.add(i);
          _productQuantities[i] = matches.first.quantity;
        }
      }
      return;
    }
    final seedId = widget.seedProductId;
    if (seedId == null) return;
    final idx = _products.indexWhere((p) => p.id == seedId);
    if (idx < 0) return;
    _selectedProductIndices.add(idx);
    _productQuantities[idx] = widget.seedQuantity < 1 ? 1 : widget.seedQuantity;
    final daily = widget.seedDailyContribution;
    if (daily != null && daily > 0) {
      _dailyAmountCtrl.text = daily.round().toString();
    }
  }

  void _goBack() {
    if (_step > 0) setState(() => _step--);
    else Navigator.pop(context);
  }

  void _goNext() {
    switch (_step) {
      case 0:
        if (_formStep1.currentState?.validate() != true) return;
        break;
      case 1:
        if (_formStep2.currentState?.validate() != true) return;
        break;
      case 2:
        if (_selectedProductIndices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sélectionnez au moins un article dans le catalogue.')),
          );
          return;
        }
        break;
      case 3:
        return;
    }
    setState(() => _step++);
  }

  Future<void> _saveClient() async {
    if (_formStep4.currentState?.validate() != true) return;

    final auth = ref.read(authProvider);
    if (auth.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session agent introuvable. Reconnectez-vous.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final fullName = '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}'.trim();
      final phoneValue = _clientWithoutPhone ? null : _phoneCtrl.text.trim();
      final profession = '${_metierCtrl.text.trim()} | Financement: $_financingType';
      final selectedNames = _selectedProductIndices.map((i) {
        final qty = _productQuantities[i] ?? 1;
        return qty > 1 ? '${_products[i].name} x$qty' : _products[i].name;
      }).join(' + ');
      final targetAmount = _totalProjectAmount;
      final daily = double.tryParse(_dailyAmountControllerText()) ??
          (targetAmount > 0 ? targetAmount / 365 : 500);

      final productSelections = _selectedProductIndices.map((i) => {
        'productId': int.tryParse(_products[i].id) ?? _products[i].id,
        'quantity': _productQuantities[i] ?? 1,
      }).toList();

      await _dbService.registerClientAndProject(
        name: fullName,
        phone: phoneValue ?? '',
        pin: _pinCtrl.text.trim(),
        secretCode: _pinCtrl.text.trim(),
        profession: _metierCtrl.text.trim(),
        agentId: auth.userId!,
        projectTitle: selectedNames,
        targetAmount: targetAmount <= 0 ? 50000 : targetAmount,
        dailySuggested: daily,
      );

      final uniqueCode = 'CL-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      final regResult = await _api.submitRegistration(
        fullName: fullName,
        phone: phoneValue,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        profession: profession,
        gender: registrationGenderCode(_gender),
        pin: _pinCtrl.text.trim(),
        secretCode: _pinCtrl.text.trim(),
        accountPassword: _passwordCtrl.text.trim(),
        uniqueCode: uniqueCode,
        submittedBy: 'agent',
        requestedRole: 'client',
        submittedByAgentUserId: auth.userId,
        assignedAgentUserId: auth.userId,
        workplaceName: _lieuTravailCtrl.text.trim(),
        workplaceAddress: _lieuTravailCtrl.text.trim(),
        bossName: _bossNameCtrl.text.trim(),
        bossPhone: _bossPhoneCtrl.text.trim(),
        profilePhoto: _profilePhoto,
        idDocument: _idDocument,
        idDocumentWaived: _noIdDocument || _idDocument == null,
        productSelections: productSelections,
      );

      if (mounted && !regResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UserVisibleMessage.apiOrFallback(
                regResult.message,
                'Synchronisation avec le serveur impossible. Réessayez ou vérifiez le réseau.',
              ),
            ),
          ),
        );
      }
      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserVisibleMessage.forException(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _dailyAmountControllerText() => _dailyAmountCtrl.text.trim();

  @override
  Widget build(BuildContext context) {
    return AuthWaveBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded, color: AppColors.secondary),
                  ),
                  Expanded(
                    child: Text(
                      'Nouveau client',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      _stepTitle(),
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stepSubtitle(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_step),
                        child: _stepContent(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPrimaryButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
        return 'Informations personnelles';
      case 1:
        return 'Sécurité du compte';
      case 2:
        return 'Catalogue PayFlex';
      case 3:
        return 'Finalisation';
      default:
        return '';
    }
  }

  String _stepSubtitle() {
    switch (_step) {
      case 0:
        return 'Étape 1 — Identité et coordonnées du client';
      case 1:
        return 'Étape 2 — Mot de passe de connexion (comme l’inscription client)';
      case 2:
        return 'Étape 3 — Articles et quantités choisis pour le client';
      case 3:
        return 'Étape 4 — Financement, référence et code PIN secret du client';
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
        return _buildStepCatalogue();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepIndicator() {
    Widget stepDot(int i, String label) {
      final active = _step >= i;
      final current = _step == i;
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
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
                          color: AppColors.secondary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: active ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.secondary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    Widget line(int afterIndex) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Divider(
            thickness: 2,
            color: _step > afterIndex ? AppColors.secondary : Colors.grey.shade300,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepDot(0, 'Infos'),
        line(0),
        stepDot(1, 'Sécurité'),
        line(1),
        stepDot(2, 'Catalogue'),
        line(2),
        stepDot(3, 'PIN'),
      ],
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
            decoration: RegistrationFormTheme.decor(Icons.badge_outlined, 'Nom'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _prenomCtrl,
            style: _fieldStyle,
            decoration: RegistrationFormTheme.decor(Icons.person_outline_rounded, 'Prénom(s)'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Sexe',
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0156B6)),
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
                if (states.contains(WidgetState.selected)) return AppColors.primary;
                return Colors.black87;
              }),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: CheckboxListTile(
              value: _clientWithoutPhone,
              onChanged: (v) => setState(() {
                _clientWithoutPhone = v == true;
                if (_clientWithoutPhone) _phoneCtrl.clear();
              }),
              activeColor: AppColors.primary,
              title: Text(
                'Client sans téléphone (géré par l’agent)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              subtitle: Text(
                'L’agent choisit les articles et le client valide avec son code PIN secret.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          if (!_clientWithoutPhone) ...[
            const SizedBox(height: 14),
            PayflexPhoneField(
              completeNumberController: _phoneCtrl,
              hint: 'Ex. 90000000',
              textStyle: _fieldStyle,
              validator: (v) => PayflexPhoneValidator.validate(v),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailCtrl,
            style: _fieldStyle,
            keyboardType: TextInputType.emailAddress,
            decoration: RegistrationFormTheme.decor(Icons.email_outlined, 'E-mail (facultatif)'),
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
            decoration: RegistrationFormTheme.decor(Icons.build_circle_outlined, 'Métier'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Métier requis' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cityCtrl,
            style: _fieldStyle,
            decoration: RegistrationFormTheme.decor(Icons.location_on_outlined, 'Ville'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ville requise' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _lieuTravailCtrl,
            style: _fieldStyle,
            decoration: RegistrationFormTheme.decor(Icons.maps_home_work_outlined, 'Lieu de travail / établissement'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le lieu de travail' : null,
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildStep2() {
    return Form(
      key: _formStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          RegistrationFormTheme.infoBanner(
            'Choisissez un mot de passe de connexion pour le client, puis définissez son code PIN secret à l’étape 4.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: !_isPasswordVisible,
            style: _fieldStyle,
            decoration: RegistrationFormTheme.decor(
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
            decoration: RegistrationFormTheme.decor(
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
          RegistrationFormTheme.sectionTitle('Pièces jointes (facultatif)'),
          const SizedBox(height: 8),
          Text(
            'Photo et pièce d’identité recommandées. Le centre peut les demander plus tard.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
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
              title: Text(
                'Le client n’a pas de carte d’identité ni passeport',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildStepCatalogue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegistrationFormTheme.infoBanner(
          'Sélectionnez les articles du catalogue et ajustez les quantités. Le total du projet sera calculé automatiquement.',
        ),
        const SizedBox(height: 16),
        if (_isLoadingProducts)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_products.isEmpty)
          Text(
            'Aucun article disponible pour le moment.',
            style: GoogleFonts.manrope(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          )
        else
          ...List.generate(_products.length, (i) => _buildProductCard(i)),
        if (_selectedProductIndices.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Récapitulatif',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_selectedProductIndices.length} article(s) · Total ${_totalProjectAmount.toInt()} FCFA',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ],
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildProductCard(int i) {
    final p = _products[i];
    final isSelected = _selectedProductIndices.contains(i);
    final qty = _productQuantities[i] ?? 1;

    return InkWell(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: p,
            agentPickerMode: true,
            initialDailyContribution: double.tryParse(_dailyAmountCtrl.text.trim()),
            onPicked: (product, qty, daily) {
              final pickedIdx = _products.indexWhere((x) => x.id == product.id);
              if (pickedIdx < 0) return;
              setState(() {
                _selectedProductIndices.add(pickedIdx);
                _productQuantities[pickedIdx] = qty;
                if (daily > 0) {
                  _dailyAmountCtrl.text = daily.round().toString();
                }
              });
            },
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: p.imageUrl.isNotEmpty
                    ? Image.network(
                        p.imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _productPlaceholder(),
                      )
                    : _productPlaceholder(),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                  Text(
                    p.name,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.price.toInt()} FCFA',
                    style: GoogleFonts.manrope(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sous-total : ${(p.price * qty).toInt()} FCFA',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _qtyButton(
                          icon: Icons.remove_rounded,
                          onTap: qty > 1 ? () => setState(() => _productQuantities[i] = qty - 1) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$qty',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                          ),
                        ),
                        _qtyButton(
                          icon: Icons.add_rounded,
                          onTap: () => setState(() => _productQuantities[i] = qty + 1),
                        ),
                        const Spacer(),
                        Text(
                          'Qté',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                if (isSelected) {
                  _selectedProductIndices.remove(i);
                  _productQuantities.remove(i);
                } else {
                  _selectedProductIndices.add(i);
                  _productQuantities[i] = 1;
                }
              }),
              icon: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                color: isSelected ? AppColors.primary : Colors.grey.shade500,
                size: 28,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _productPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: Colors.grey.shade200,
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey.shade500),
    );
  }

  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: onTap == null ? Colors.grey.shade400 : AppColors.secondary),
        ),
      ),
    );
  }

  Widget _buildStep4() {
    return Form(
      key: _formStep4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegistrationFormTheme.sectionTitle('Type de financement'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _financingType,
            dropdownColor: Colors.white,
            iconEnabledColor: AppColors.secondary,
            style: _fieldStyle,
            decoration: RegistrationFormTheme.decor(Icons.account_balance_wallet_outlined, 'Choisir'),
            items: const [
              DropdownMenuItem(
                value: 'cotisation_journaliere',
                child: Text('Cotisation journalière', style: TextStyle(color: Color(0xFF1E293B), fontSize: 15)),
              ),
              DropdownMenuItem(
                value: 'paiement_unique',
                child: Text('Paiement unique', style: TextStyle(color: Color(0xFF1E293B), fontSize: 15)),
              ),
              DropdownMenuItem(
                value: 'financement_partiel',
                child: Text('Financement partiel PayFlex', style: TextStyle(color: Color(0xFF1E293B), fontSize: 15)),
              ),
            ],
            onChanged: (v) => setState(() => _financingType = v ?? 'cotisation_journaliere'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dailyAmountCtrl,
            style: _fieldStyle,
            keyboardType: TextInputType.number,
            decoration: RegistrationFormTheme.decor(Icons.payments_outlined, 'Montant journalier souhaité (FCFA)'),
          ),
          const SizedBox(height: 20),
          RegistrationFormTheme.sectionTitle('Patron ou formateur (optionnel)'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _bossNameCtrl,
            style: _fieldStyle,
            decoration: RegistrationFormTheme.decor(Icons.person_pin_circle_outlined, 'Nom du patron / formateur'),
          ),
          const SizedBox(height: 14),
          PayflexPhoneField(
            completeNumberController: _bossPhoneCtrl,
            hint: 'Téléphone du patron / formateur',
            required: false,
            textStyle: _fieldStyle,
            validator: (v) => PayflexPhoneValidator.validate(v, required: false),
          ),
          const SizedBox(height: 20),
          RegistrationFormTheme.sectionTitle('Code PIN secret du client'),
        const SizedBox(height: 8),
          RegistrationFormTheme.infoBanner(
            'Ce code PIN est connu du client seul. Il valide les cotisations sur le terrain avec l’agent.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pinCtrl,
            obscureText: !_isPinVisible,
            style: _fieldStyle,
            keyboardType: TextInputType.number,
            decoration: RegistrationFormTheme.decor(
              Icons.pin_outlined,
              'Code PIN (4 à 12 chiffres)',
              suffix: IconButton(
                icon: Icon(
                  _isPinVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
              ),
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length < 4 || t.length > 12) return 'PIN : 4 à 12 chiffres';
              if (!RegExp(r'^\d+$').hasMatch(t)) return 'Chiffres uniquement';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pinConfirmCtrl,
            obscureText: !_isPinConfirmVisible,
            style: _fieldStyle,
            keyboardType: TextInputType.number,
            decoration: RegistrationFormTheme.decor(
              Icons.pin_outlined,
              'Confirmer le code PIN',
              suffix: IconButton(
                icon: Icon(
                  _isPinConfirmVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                onPressed: () => setState(() => _isPinConfirmVisible = !_isPinConfirmVisible),
              ),
            ),
            validator: (v) => (v != _pinCtrl.text) ? 'Les codes PIN ne correspondent pas' : null,
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildPrimaryButton() {
    final isLast = _step == 3;
    return ElevatedButton(
      onPressed: _isSaving
          ? null
          : () {
              if (isLast) {
                _saveClient();
              } else {
                _goNext();
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isSaving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              isLast ? 'Finaliser l’inscription' : 'Suivant',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
            ),
    );
  }

  String _basename(String path) {
    final s = path.replaceAll('\\', '/');
    final i = s.lastIndexOf('/');
    return i < 0 ? s : s.substring(i + 1);
  }

  Widget _buildFilePicker(String label, String value, IconData icon, VoidCallback? onTap, {bool enabled = true}) {
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
    final stored = await RegistrationFileStore.persist(File(xFile.path), 'profile');
    if (stored != null && mounted) setState(() => _profilePhoto = stored);
  }

  Future<void> _pickIdDocument() async {
    final picked = await FilePicker.platform.pickFiles(withData: false);
    if (picked == null || picked.files.single.path == null) return;
    final stored = await RegistrationFileStore.persist(File(picked.files.single.path!), 'identity');
    if (stored != null && mounted) setState(() => _idDocument = stored);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Dossier soumis', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Text(
          'Le client a été enregistré avec les articles choisis. Communiquez-lui son code PIN secret.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
