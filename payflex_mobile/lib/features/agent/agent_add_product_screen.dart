import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/models/product_model.dart';
import '../../core/network/mobile_api_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/user_visible_message.dart';
import '../../core/widgets/registration_form_theme.dart';
import '../catalogue/product_detail_screen.dart';

/// Ajout d'un ou plusieurs produits au dossier d'un client existant (agent terrain).
class AgentAddProductScreen extends ConsumerStatefulWidget {
  const AgentAddProductScreen({
    super.key,
    required this.clientUserId,
    required this.clientName,
    required this.currentTotalFcfa,
    required this.currentDailyFcfa,
    required this.collectedFcfa,
    this.existingProductIds = const {},
  });

  final int clientUserId;
  final String clientName;
  final double currentTotalFcfa;
  final double currentDailyFcfa;
  final double collectedFcfa;
  final Set<int> existingProductIds;

  @override
  ConsumerState<AgentAddProductScreen> createState() => _AgentAddProductScreenState();
}

class _AgentAddProductScreenState extends ConsumerState<AgentAddProductScreen> {
  final MobileApiService _api = MobileApiService();
  final DatabaseService _db = DatabaseService();
  final _dailyCtrl = TextEditingController();

  List<Product> _products = [];
  bool _loadingProducts = true;
  bool _saving = false;
  final Set<int> _selectedIndices = {};
  final Map<int, int> _quantities = {};

  double get _addedAmount => _selectedIndices.fold(0.0, (sum, i) {
        final qty = _quantities[i] ?? 1;
        return sum + _products[i].price * qty;
      });

  double get _newTotal => widget.currentTotalFcfa + _addedAmount;

  double get _suggestedDaily {
    final addedMin = _selectedIndices.fold(0.0, (sum, i) {
      final qty = _quantities[i] ?? 1;
      return sum + _products[i].dailyMin * qty;
    });
    final base = widget.currentDailyFcfa > 0 ? widget.currentDailyFcfa : 0;
    final suggested = base + addedMin;
    if (suggested > 0) return suggested;
    return _newTotal > 0 ? (_newTotal / 365).clamp(200.0, _newTotal) : 500;
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _dailyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final maps = await _api.fetchProducts();
      if (maps.isNotEmpty) {
        _products = maps.map(Product.fromMap).toList();
      } else {
        final local = await _db.getCatalogueItems();
        _products = local.map(Product.fromMap).toList();
      }
    } catch (_) {
      final local = await _db.getCatalogueItems();
      _products = local.map(Product.fromMap).toList();
    } finally {
      if (mounted) {
        setState(() => _loadingProducts = false);
        _refreshDailyField();
      }
    }
  }

  void _refreshDailyField() {
    if (_dailyCtrl.text.trim().isEmpty && _selectedIndices.isNotEmpty) {
      _dailyCtrl.text = _suggestedDaily.toInt().toString();
    }
  }

  Future<void> _submit() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un produit.')),
      );
      return;
    }

    final daily = double.tryParse(_dailyCtrl.text.trim()) ?? _suggestedDaily;
    if (daily < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez une cotisation journalière valide.')),
      );
      return;
    }

    final auth = ref.read(authProvider);
    if (auth.userId == null) return;

    setState(() => _saving = true);
    try {
      final selections = _selectedIndices.map((i) {
        final p = _products[i];
        return {
          'productId': int.tryParse(p.id) ?? p.id,
          'quantity': _quantities[i] ?? 1,
        };
      }).toList();

      final res = await _api.addAgentClientProducts(
        userId: auth.userId!,
        phone: auth.phone ?? '',
        pin: auth.pin ?? '',
        clientUserId: widget.clientUserId,
        productSelections: selections,
        dailyContribution: daily,
      );

      if (!mounted) return;

      if (res == null || res['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res?['message']?.toString() ??
                  'Impossible d\'ajouter le produit. Vérifiez le réseau.',
            ),
          ),
        );
        return;
      }

      final client = res['client'];
      if (client is Map<String, dynamic>) {
        final products = client['products'] is List ? client['products'] as List : <dynamic>[];
        final productMaps = products
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        int? primaryId;
        if (selections.isNotEmpty) {
          primaryId = int.tryParse(selections.last['productId'].toString());
        }
        await _db.syncClientFinanceForAgent(
          serverClientUserId: widget.clientUserId,
          clientName: widget.clientName,
          agentUserId: auth.userId!,
          products: productMaps,
          totalProject: (client['totalProjectFcfa'] as num?)?.toDouble() ?? _newTotal,
          dailyContribution: (client['dailyContributionFcfa'] as num?)?.toDouble() ?? daily,
          collected: (client['collectedFcfa'] as num?)?.toDouble() ?? widget.collectedFcfa,
          primaryProductId: primaryId,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, client is Map<String, dynamic> ? client : true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit(s) ajouté(s) — montants mis à jour.')),
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
        title: Text(
          'Ajouter un produit',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loadingProducts
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                RegistrationFormTheme.infoBanner(
                  'Client : ${widget.clientName}. Choisissez le produit, la quantité et validez la cotisation journalière.',
                ),
                const SizedBox(height: 16),
                _summaryCard(),
                const SizedBox(height: 20),
                RegistrationFormTheme.sectionTitle('Catalogue'),
                const SizedBox(height: 10),
                if (_products.isEmpty)
                  Text(
                    'Aucun produit disponible.',
                    style: GoogleFonts.manrope(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  )
                else
                  ...List.generate(_products.length, (i) => _productCard(i)),
                if (_selectedIndices.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  RegistrationFormTheme.sectionTitle('Cotisation journalière'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dailyCtrl,
                    keyboardType: TextInputType.number,
                    style: RegistrationFormTheme.fieldStyle(context),
                    decoration: RegistrationFormTheme.decor(
                      Icons.payments_outlined,
                      'Montant journalier (FCFA)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suggestion : ${_suggestedDaily.toInt()} F/jour · Nouveau total projet : ${_newTotal.toInt()} FCFA',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: _selectedIndices.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: RegistrationFormTheme.primaryActionButton(height: 54),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Valider et ajouter au dossier'),
                ),
              ),
            ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('Total actuel', '${widget.currentTotalFcfa.toInt()} FCFA'),
          if (_addedAmount > 0) _summaryRow('Ajout', '+${_addedAmount.toInt()} FCFA', color: AppColors.primary),
          if (_addedAmount > 0)
            _summaryRow('Nouveau total', '${_newTotal.toInt()} FCFA', bold: true),
          if (widget.currentDailyFcfa > 0)
            _summaryRow('Journalier actuel', '${widget.currentDailyFcfa.toInt()} F/jour'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color ?? AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(int i) {
    final p = _products[i];
    final productId = int.tryParse(p.id);
    final alreadyOwned = productId != null && widget.existingProductIds.contains(productId);
    final isSelected = _selectedIndices.contains(i);
    final qty = _quantities[i] ?? 1;

    return InkWell(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: p,
            agentPickerMode: true,
            initialDailyContribution: double.tryParse(_dailyCtrl.text.trim()),
            onPicked: (product, qty, daily) {
              final pickedIdx = _products.indexWhere((x) => x.id == product.id);
              if (pickedIdx < 0) return;
              setState(() {
                _selectedIndices.add(pickedIdx);
                _quantities[pickedIdx] = qty;
                if (daily > 0) {
                  _dailyCtrl.text = daily.round().toString();
                } else {
                  _refreshDailyField();
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
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
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
                        p.displayImageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.price.toInt()} FCFA · min ${p.dailyMin.toInt()} F/j',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  if (alreadyOwned)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Déjà au dossier — la quantité sera cumulée',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (isSelected) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _qtyBtn(Icons.remove_rounded, qty > 1 ? () => setState(() => _quantities[i] = qty - 1) : null),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$qty', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                        _qtyBtn(Icons.add_rounded, () => setState(() => _quantities[i] = qty + 1)),
                        const Spacer(),
                        Text(
                          '${(p.price * qty).toInt()} F',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13),
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
                  _selectedIndices.remove(i);
                  _quantities.remove(i);
                } else {
                  _selectedIndices.add(i);
                  _quantities[i] = 1;
                  _refreshDailyField();
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

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      color: Colors.grey.shade200,
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey.shade500),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
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
}
