import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/models/product_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/catalogue_provider.dart';
import '../../core/providers/finance_provider.dart';
import '../agent/agent_enrollment_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  final double? initialDailyContribution;
  final bool agentPickerMode;
  final void Function(Product product, int quantity, double dailyContribution)? onPicked;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.initialDailyContribution,
    this.agentPickerMode = false,
    this.onPicked,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _amountController = TextEditingController();
  final _galleryController = PageController();
  double _dailyAmount = 0;
  int _daysToFinish = 0;
  int _quantity = 1;
  bool _isSaving = false;
  int _galleryIndex = 0;

  double _lineTotal(Product p) => p.price * _quantity;

  double _floorDaily(Product p) {
    final total = _lineTotal(p);
    return math.min(math.max(p.dailyMin * _quantity, 1.0), total);
  }

  double _ceilDaily(Product p) => _lineTotal(p);

  int _sliderDivisions(double lo, double hi) {
    final span = hi - lo;
    if (span <= 1) return 1;
    final n = (span / 2500).ceil();
    return math.min(80, math.max(5, n));
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final initial = widget.initialDailyContribution;
    if (initial != null && initial > 0) {
      _dailyAmount = initial.clamp(_floorDaily(p), _ceilDaily(p));
    } else {
      _dailyAmount = _floorDaily(p);
    }
    _amountController.text = _dailyAmount.round().toString();
    if (_dailyAmount > 0) {
      _daysToFinish = (_lineTotal(p) / _dailyAmount).ceil();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cartLine = ref.read(catalogueProvider).cart.where((l) => l.product.id == p.id).toList();
      if (cartLine.isNotEmpty) {
        setState(() {
          _quantity = cartLine.first.quantity;
          _daysToFinish = _dailyAmount > 0 ? (_lineTotal(p) / _dailyAmount).ceil() : 0;
        });
      }
    });
  }

  void _setQuantity(int qty) {
    final p = widget.product;
    final next = qty < 1 ? 1 : qty;
    setState(() {
      _quantity = next;
      final lo = _floorDaily(p);
      final hi = _ceilDaily(p);
      if (_dailyAmount < lo) _dailyAmount = lo;
      if (_dailyAmount > hi) _dailyAmount = hi;
      _amountController.text = _dailyAmount.round().toString();
      _daysToFinish = _dailyAmount > 0 ? (_lineTotal(p) / _dailyAmount).ceil() : 0;
    });
    final inCart = ref.read(catalogueProvider).cart.any((l) => l.product.id == p.id);
    if (inCart) {
      ref.read(catalogueProvider.notifier).setCartQuantity(p.id, next);
    }
  }

  void _setDaily(double v) {
    final p = widget.product;
    final lo = _floorDaily(p);
    final hi = _ceilDaily(p);
    final nv = v.clamp(lo, hi);
    setState(() {
      _dailyAmount = nv;
      _amountController.text = nv.round().toString();
      _daysToFinish = nv > 0 ? (_lineTotal(p) / nv).ceil() : 0;
    });
  }

  void _commitManualDaily() {
    final raw = _amountController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final v = double.tryParse(raw);
    if (v == null) {
      _amountController.text = _dailyAmount.round().toString();
      return;
    }
    final p = widget.product;
    final lo = _floorDaily(p);
    final hi = _ceilDaily(p);
    if (v < lo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le minimum pour ce produit est de ${lo.round()} FCFA / jour.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _setDaily(lo);
      return;
    }
    if (v > hi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le montant ne peut pas dépasser ${hi.round()} FCFA / jour (prix catalogue).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _setDaily(hi);
      return;
    }
    _setDaily(v);
  }

  bool get _isAgent => ref.read(authProvider).role == 'agent';

  Future<void> _pickForAgent() async {
    final p = widget.product;
    final lo = _floorDaily(p);
    final hi = _ceilDaily(p);
    if (_dailyAmount < lo || _dailyAmount > hi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Choisissez un montant entre ${lo.round()} et ${hi.round()} FCFA / jour.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onPicked?.call(p, _quantity, _dailyAmount);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openEnrollmentForAgent() async {
    final p = widget.product;
    final lo = _floorDaily(p);
    final hi = _ceilDaily(p);
    if (_dailyAmount < lo || _dailyAmount > hi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Choisissez un montant entre ${lo.round()} et ${hi.round()} FCFA / jour.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!ref.read(catalogueProvider.notifier).isInCart(p.id)) {
      ref.read(catalogueProvider.notifier).addToCart(p, quantity: _quantity);
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AgentEnrollmentScreen(
          seedProductId: p.id,
          seedQuantity: _quantity,
          seedDailyContribution: _dailyAmount,
        ),
      ),
    );
  }

  Future<void> _startSaving() async {
    if (_isAgent) {
      await _openEnrollmentForAgent();
      return;
    }
    if (!ref.read(authProvider).canUseAppFeatures) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Démarrer une épargne sera possible après validation de votre inscription par PayFlex.',
            style: GoogleFonts.manrope(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final p = widget.product;
    final lo = _floorDaily(p);
    final hi = _ceilDaily(p);
    if (_dailyAmount < lo || _dailyAmount > hi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Choisissez un montant entre ${lo.round()} et ${hi.round()} FCFA / jour.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final db = DatabaseService();
      await db.addProject(
        widget.product.id,
        _quantity > 1 ? '${widget.product.name} (×$_quantity)' : widget.product.name,
        _lineTotal(widget.product),
        _dailyAmount,
      );
      if (ref.read(catalogueProvider.notifier).isInCart(widget.product.id)) {
        ref.read(catalogueProvider.notifier).removeFromCart(widget.product.id);
      }
      final uid = ref.read(authProvider).userId;
      if (uid != null) {
        await db.setUserCurrentProject(uid, widget.product.id);
      }
      await ref.read(financeProvider.notifier).reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Épargne démarrée ! Retrouvez votre carnet dans l\'onglet Finances.',
                    style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF38A169),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isInCart = ref.watch(catalogueProvider).cart.any((l) => l.product.id == product.id);
    final gallery = product.galleryUrls;
    final heroUrl = gallery.isNotEmpty ? gallery.first : product.displayImageUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Hero Image AppBar
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.secondary,
            surfaceTintColor: Colors.transparent,
            leading: Container(
              margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () {
                  if (isInCart) {
                    ref.read(catalogueProvider.notifier).removeFromCart(product.id);
                    setState(() => _quantity = 1);
                  } else {
                    ref.read(catalogueProvider.notifier).addToCart(product, quantity: _quantity);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                  child: Icon(
                    isInCart ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
                    color: isInCart ? AppColors.primary : Colors.white, size: 20,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: product.id,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (gallery.length > 1)
                      PageView.builder(
                        controller: _galleryController,
                        onPageChanged: (i) => setState(() => _galleryIndex = i),
                        itemCount: gallery.length,
                        itemBuilder: (_, i) => Image.network(gallery[i], fit: BoxFit.cover),
                      )
                    else
                      Image.network(heroUrl, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                        ),
                      ),
                    ),
                    if (gallery.length > 1)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(gallery.length, (i) {
                            final active = i == _galleryIndex;
                            return Container(
                              width: active ? 10 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: active ? AppColors.primary : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + Catégorie
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('ÉLIGIBLE COTISATION',
                          style: GoogleFonts.manrope(
                            color: AppColors.primary, fontSize: 10,
                            fontWeight: FontWeight.w900, letterSpacing: 1.5,
                          )),
                      ).animate().fadeIn().slideX(begin: -0.2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF2F7), borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(product.category,
                          style: GoogleFonts.manrope(
                            color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.w700,
                          )),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Nom du produit
                  Text(product.name,
                    style: GoogleFonts.manrope(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: AppColors.secondary, letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _quantity > 1
                                  ? '${product.formattedPrice} × $_quantity'
                                  : product.formattedPrice,
                              style: GoogleFonts.manrope(
                                color: AppColors.primary, fontSize: 30, fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (_quantity > 1)
                              Text(
                                'Total : ${_lineTotal(product).round()} FCFA',
                                style: GoogleFonts.manrope(
                                  color: AppColors.secondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 20),
                              onPressed: _quantity > 1 ? () => _setQuantity(_quantity - 1) : null,
                            ),
                            Text('$_quantity', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 20),
                              onPressed: () => _setQuantity(_quantity + 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 28),
                  Container(height: 1, color: AppColors.secondary.withOpacity(0.06)),
                  const SizedBox(height: 28),

                  // Description
                  Text('DESCRIPTION',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900, letterSpacing: 2,
                      fontSize: 11, color: AppColors.secondary.withOpacity(0.4),
                    )).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 12),
                  Text(product.description,
                    style: GoogleFonts.inter(height: 1.7, fontSize: 15, color: AppColors.secondary.withOpacity(0.7)),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 36),
                  Container(height: 1, color: AppColors.secondary.withOpacity(0.06)),
                  const SizedBox(height: 28),

                  // ---- CALCULATEUR D'ÉPARGNE ----
                  Text('SIMULATEUR D\'ÉPARGNE',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900, letterSpacing: 2,
                      fontSize: 11, color: AppColors.secondary.withOpacity(0.4),
                    )),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cotisation journalière souhaitée',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.secondary, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Minimum : ${(_floorDaily(product)).round()} FCFA/j. Maximum : ${_lineTotal(product).round()} FCFA/j (prix × quantité).',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            height: 1.35,
                            color: AppColors.secondary.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_ceilDaily(product) > _floorDaily(product) + 0.01)
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                              thumbColor: AppColors.secondary,
                              overlayColor: AppColors.secondary.withOpacity(0.1),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _dailyAmount.clamp(_floorDaily(product), _ceilDaily(product)),
                              min: _floorDaily(product),
                              max: _ceilDaily(product),
                              divisions: _sliderDivisions(_floorDaily(product), _ceilDaily(product)),
                              onChanged: _setDaily,
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Montant unique : ${_floorDaily(product).round()} FCFA / jour (égal au prix catalogue).',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.secondary.withOpacity(0.75)),
                            ),
                          ),
                        Center(
                          child: Text(
                            '${_dailyAmount.round()} FCFA / jour',
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                                cursorColor: AppColors.secondary,
                                decoration: InputDecoration(
                                  labelText: 'Saisie manuelle (FCFA)',
                                  hintText: '≥ ${_floorDaily(product).round()}',
                                  labelStyle: GoogleFonts.manrope(
                                    color: AppColors.secondary.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  hintStyle: GoogleFonts.manrope(
                                    color: AppColors.secondary.withValues(alpha: 0.45),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                ),
                                onSubmitted: (_) => _commitManualDaily(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _commitManualDaily,
                              child: Text('Appliquer', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(height: 1, color: AppColors.primary.withOpacity(0.1)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoTile('Durée estimée', '$_daysToFinish jours', Icons.calendar_month_outlined),
                            _infoTile('Par mois', '${(_dailyAmount * 30).toInt()} FCFA', Icons.account_balance_wallet_outlined),
                            _infoTile(
                              'Progression /mois',
                              _lineTotal(product) > 0
                                  ? '${((_dailyAmount * 30 / _lineTotal(product)) * 100).toStringAsFixed(0)}%'
                                  : '—',
                              Icons.trending_up_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 36),

                  // Bouton principal
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : widget.agentPickerMode
                              ? _pickForAgent
                              : _startSaving,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.agentPickerMode
                                ? 'CHOISIR CET ARTICLE'
                                : _isAgent
                                    ? 'INSCRIRE UN CLIENT'
                                    : 'COMMENCER L\'ÉPARGNE',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15),
                          ),
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.secondary),
        ),
        const SizedBox(height: 8),
        Text(value,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.secondary, fontSize: 13)),
        Text(label,
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}
