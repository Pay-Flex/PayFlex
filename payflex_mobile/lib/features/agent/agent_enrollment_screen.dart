import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class AgentEnrollmentScreen extends StatefulWidget {
  const AgentEnrollmentScreen({super.key});

  @override
  State<AgentEnrollmentScreen> createState() => _AgentEnrollmentScreenState();
}

class _AgentEnrollmentScreenState extends State<AgentEnrollmentScreen> {
  int _currentStep = 0;
  final Set<int> _selectedIndices = {};
  
  final List<Map<String, dynamic>> _products = [
    {'name': 'Moto Jakarta 100cc', 'price': 850000.0, 'img': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&q=80'},
    {'name': 'Solaire Elite Pack', 'price': 120000.0, 'img': 'https://images.unsplash.com/photo-1509391366360-fe5bb65858cf?w=400&q=80'},
    {'name': 'Congélateur Solaire XL', 'price': 350000.0, 'img': 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=400&q=80'},
    {'name': 'Kit TV + Solaire', 'price': 210000.0, 'img': 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=400&q=80'},
    {'name': 'Pompe à eau Solaire', 'price': 450000.0, 'img': 'https://images.unsplash.com/photo-1466692473996-395bf6463328?w=400&q=80'},
  ];

  double get _totalProjectAmount => _selectedIndices.fold(0, (sum, i) => sum + _products[i]['price']);
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _professionController = TextEditingController();
  final _dailyAmountController = TextEditingController();
  
  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _showSuccessDialog();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
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
        title: Text(
          'Nouveau Client',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Stepper Indicator "Elite"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: List.generate(4, (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: index <= _currentStep ? AppColors.primary : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),
          
          // Bottom Navigation Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                _currentStep == 3 ? 'Finaliser l\'inscription' : 'Continuer',
                style: GoogleFonts.manrope(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _stepInfoPersonnelle();
      case 1: return _stepConfigFinanciere();
      case 2: return _stepSelectionProduit();
      case 3: return _stepSecuriteClient();
      default: return const SizedBox();
    }
  }

  Widget _stepInfoPersonnelle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INFORMATIONS PERSONNELLES', 
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text('Commençons par l\'identité du client', 
          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
        const SizedBox(height: 32),
        _buildTextField('Nom & Prénoms complets', _nameController, Icons.person_outline_rounded),
        const SizedBox(height: 20),
        _buildTextField('Numéro de téléphone', _phoneController, Icons.phone_android_rounded, keyboardType: TextInputType.phone),
        const SizedBox(height: 20),
        _buildTextField('Profession / Secteur d\'activité', _professionController, Icons.work_outline_rounded),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _stepConfigFinanciere() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONFIGURATION FINANCIÈRE', 
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text('Définissons sa capacité de cotisation', 
          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
        const SizedBox(height: 32),
        _buildTextField('Montant idéal journalier (FCFA)', _dailyAmountController, Icons.payments_outlined, keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        Text('Estimation des revenus mensuels', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.secondary)),
        const SizedBox(height: 12),
        _buildSelectionGrid(['< 50.000 F', '50.000 - 150.000 F', '150.000 - 300.000 F', '> 300.000 F']),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _stepSelectionProduit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SÉLECTION ÉQUIPEMENTS', 
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text('Quels équipements pour le client ?', 
          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
        const SizedBox(height: 8),
        Text('Sélectionnez un ou plusieurs articles du catalogue PayFlex.', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey)),
        
        const SizedBox(height: 32),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _products.length,
          itemBuilder: (context, i) {
            final isSelected = _selectedIndices.contains(i);
            final p = _products[i];
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondary : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isSelected ? AppColors.secondary : Colors.grey.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? AppColors.secondary.withOpacity(0.2) : Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ListTile(
                onTap: () => setState(() => isSelected ? _selectedIndices.remove(i) : _selectedIndices.add(i)),
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(p['img'], width: 60, height: 60, fit: BoxFit.cover),
                ),
                title: Text(p['name'], 
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppColors.secondary, fontSize: 15)),
                subtitle: Text('${(p['price'] as double).toInt()} FCFA', 
                  style: GoogleFonts.manrope(fontSize: 13, color: isSelected ? Colors.white.withOpacity(0.7) : AppColors.primary, fontWeight: FontWeight.w900)),
                trailing: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  color: isSelected ? Colors.white : Colors.grey.shade300,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        // Résumé Financier
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('VALEUR TOTALE PROJET', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  Text('${_totalProjectAmount.toInt()} FCFA', 
                    style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                ],
              ),
              if (_selectedIndices.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MOYENNE SUGGÉRÉE', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                    Text('${(_totalProjectAmount / 365).toInt()} F / jour', 
                      style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _stepSecuriteClient() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SÉCURITÉ DU COMPTE', 
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text('Passez le téléphone au client pour ses codes', 
          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
        const SizedBox(height: 12),
        Text('Ces codes doivent rester strictement confidentiels.', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 32),
        _buildTextField('Créer un Mot de passe (Saisi par le client)', TextEditingController(), Icons.lock_outline_rounded, isPassword: true),
        const SizedBox(height: 20),
        _buildTextField('Créer un Code Secret de validation (Saisi par le client)', TextEditingController(), Icons.verified_user_outlined, isPassword: true, keyboardType: TextInputType.number),
      ],
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary.withOpacity(0.7))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.secondary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFFF7FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionGrid(List<String> options) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: options.length,
      itemBuilder: (context, i) {
        final isSelected = i == 1; // Démo
        return Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.secondary : Colors.grey.shade200),
          ),
          child: Center(
            child: Text(options[i], style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.secondary)),
          ),
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 80),
              const SizedBox(height: 24),
              Text('Dossier Soumis !', textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
              const SizedBox(height: 12),
              Text('Le compte du client est en cours de validation par les administrateurs PayFlex.', 
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey, height: 1.5)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Dialog
                  Navigator.pop(context); // Dashboard
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Retour à l\'accueil', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ).animate().scale().fadeIn(),
      ),
    );
  }
}
