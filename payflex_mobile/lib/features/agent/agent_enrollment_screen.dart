import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/utils/user_visible_message.dart';
import '../../core/models/product_model.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/payflex_phone_field.dart';
import '../../core/utils/phone_input_utils.dart';

/// Inscription d’un **client** par un agent déjà connecté (l’agent ne s’inscrit pas lui-même).
class AgentEnrollmentScreen extends ConsumerStatefulWidget {
  const AgentEnrollmentScreen({super.key});

  @override
  ConsumerState<AgentEnrollmentScreen> createState() => _AgentEnrollmentScreenState();
}

class _AgentEnrollmentScreenState extends ConsumerState<AgentEnrollmentScreen> {
  final DatabaseService _dbService = DatabaseService();
  final MobileApiService _api = MobileApiService();

  int _currentStep = 0;
  final Set<int> _selectedIndices = {};
  List<Product> _products = [];
  bool _isLoadingProducts = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _professionController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _bossNameController = TextEditingController();
  final _bossPhoneController = TextEditingController();
  final _dailyAmountController = TextEditingController();
  final _pinController = TextEditingController();

  double get _totalProjectAmount => _selectedIndices.fold(0.0, (sum, i) => sum + _products[i].price);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    _workplaceController.dispose();
    _bossNameController.dispose();
    _bossPhoneController.dispose();
    _dailyAmountController.dispose();
    _pinController.dispose();
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
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      await _saveClient();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _saveClient() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir les champs obligatoires.')));
      return;
    }
    final auth = ref.read(authProvider);
    if (auth.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session agent introuvable. Reconnectez-vous.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final selectedNames = _selectedIndices.map((i) => _products[i].name).join(' + ');
      final targetAmount = _selectedIndices.isEmpty ? 0.0 : _totalProjectAmount;
      final daily = double.tryParse(_dailyAmountController.text.trim()) ?? (targetAmount > 0 ? targetAmount / 365 : 0);

      await _dbService.registerClientAndProject(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        pin: _pinController.text.trim(),
        secretCode: _pinController.text.trim(),
        profession: _professionController.text.trim(),
        agentId: auth.userId!,
        projectTitle: selectedNames.isEmpty ? 'Projet client' : selectedNames,
        targetAmount: targetAmount <= 0 ? 50000 : targetAmount,
        dailySuggested: daily <= 0 ? 500 : daily,
      );

      final uniqueCode = 'CL-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      final regResult = await _api.submitRegistration(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        profession: _professionController.text.trim(),
        gender: 'Non précisé',
        pin: _pinController.text.trim(),
        secretCode: _pinController.text.trim(),
        accountPassword: _pinController.text.trim().length >= 6
            ? _pinController.text.trim()
            : 'PayFlex${_pinController.text.trim()}',
        uniqueCode: uniqueCode,
        submittedBy: 'agent',
        requestedRole: 'client',
        submittedByAgentUserId: auth.userId,
        assignedAgentUserId: auth.userId,
        workplaceName: _workplaceController.text.trim(),
        bossName: _bossNameController.text.trim(),
        bossPhone: _bossPhoneController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _currentStep == 0 ? () => Navigator.pop(context) : _prevStep,
          icon: Icon(_currentStep == 0 ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, color: AppColors.secondary),
        ),
        title: Text('Nouveau Client', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                    decoration: BoxDecoration(
                      color: index <= _currentStep ? AppColors.primary : const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStepContent())),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_currentStep == 3 ? 'Finaliser l\'inscription' : 'Continuer', style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _stepInfo();
      case 1:
        return _stepFinance();
      case 2:
        return _stepProducts();
      case 3:
        return _stepSecurity();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _stepInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Nom & Prénoms complets', _nameController, Icons.person_outline_rounded),
        const SizedBox(height: 16),
        PayflexPhoneField(
          completeNumberController: _phoneController,
          hint: 'Numéro de téléphone',
          validator: (v) => PayflexPhoneValidator.validate(v),
        ),
        const SizedBox(height: 16),
        _buildTextField('Ville', _cityController, Icons.location_city_rounded),
        const SizedBox(height: 16),
        _buildTextField('Profession / Secteur', _professionController, Icons.work_outline_rounded),
        const SizedBox(height: 16),
        _buildTextField('Lieu de travail', _workplaceController, Icons.apartment_rounded),
        const SizedBox(height: 16),
        _buildTextField('Nom patron/formateur', _bossNameController, Icons.badge_outlined),
        const SizedBox(height: 16),
        PayflexPhoneField(
          completeNumberController: _bossPhoneController,
          hint: 'Téléphone patron/formateur',
          required: false,
          validator: (v) => PayflexPhoneValidator.validate(v, required: false),
        ),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _stepFinance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Montant idéal journalier (FCFA)', _dailyAmountController, Icons.payments_outlined, keyboardType: TextInputType.number),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _stepProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingProducts) const Center(child: CircularProgressIndicator()),
        if (!_isLoadingProducts)
          ...List.generate(_products.length, (i) {
            final isSelected = _selectedIndices.contains(i);
            final p = _products[i];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.secondary : Colors.grey.shade200, width: 2),
              ),
              child: ListTile(
                onTap: () => setState(() => isSelected ? _selectedIndices.remove(i) : _selectedIndices.add(i)),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    p.imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(width: 52, height: 52, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported_outlined)),
                  ),
                ),
                title: Text(p.name, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppColors.secondary)),
                subtitle: Text('${p.price.toInt()} FCFA', style: GoogleFonts.manrope(color: isSelected ? Colors.white70 : AppColors.primary, fontWeight: FontWeight.w900)),
                trailing: Icon(isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: isSelected ? Colors.white : Colors.grey.shade400),
              ),
            );
          }),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _stepSecurity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          'Code PIN PayFlex du client (4 à 12 chiffres)',
          _pinController,
          Icons.pin_outlined,
          isPassword: true,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Text(
          'Ce même code sert à la connexion mobile et aux cotisations sur le terrain.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant.withValues(alpha: 0.75), height: 1.35),
        ),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary.withValues(alpha: 0.7))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFFF7FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Dossier soumis'),
        content: const Text('Le client a été enregistré et envoyé au backend pour validation admin.'),
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
