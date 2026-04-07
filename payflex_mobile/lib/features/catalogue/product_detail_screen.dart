import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_service.dart';
import '../../core/models/product_model.dart';
import '../../core/providers/catalogue_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _amountController = TextEditingController();
  double _dailyAmount = 0;
  int _daysToFinish = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dailyAmount = widget.product.dailyMin;
    _calculateDays();
  }

  void _calculateDays() {
    if (_dailyAmount > 0) {
      setState(() {
        _daysToFinish = (widget.product.price / _dailyAmount).ceil();
      });
    }
  }

  Future<void> _startSaving() async {
    setState(() => _isSaving = true);
    try {
      final db = DatabaseService();
      await db.addProject(
        widget.product.id,
        widget.product.name,
        widget.product.price,
        _dailyAmount,
      );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isInCart = ref.watch(catalogueProvider).cart.any((p) => p.id == product.id);
    final screenW = MediaQuery.of(context).size.width - 80;

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
                  } else {
                    ref.read(catalogueProvider.notifier).addToCart(product);
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
                    Image.network(product.imageUrl, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                        ),
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

                  // Prix total
                  Text(product.formattedPrice,
                    style: GoogleFonts.manrope(
                      color: AppColors.primary, fontSize: 30, fontWeight: FontWeight.w900,
                    ),
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
                        Text('Cotisation journalière souhaitée',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.secondary, fontSize: 14)),
                        const SizedBox(height: 16),

                        // Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                            thumbColor: AppColors.secondary,
                            overlayColor: AppColors.secondary.withOpacity(0.1),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _dailyAmount.clamp(100, widget.product.price),
                            min: 100,
                            max: widget.product.price > 10000 ? widget.product.price / 2 : widget.product.price,
                            divisions: 50,
                            onChanged: (v) {
                              setState(() { _dailyAmount = v; });
                              _calculateDays();
                            },
                          ),
                        ),

                        // Valeur du slider
                        Center(
                          child: Text(
                            '${_dailyAmount.toInt()} FCFA / jour',
                            style: GoogleFonts.manrope(
                              fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Container(height: 1, color: AppColors.primary.withOpacity(0.1)),
                        const SizedBox(height: 20),

                        // Résultats du calcul
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoTile('Durée estimée', '$_daysToFinish jours', Icons.calendar_month_outlined),
                            _infoTile('Par mois', '${(_dailyAmount * 30).toInt()} FCFA', Icons.account_balance_wallet_outlined),
                            _infoTile('Progression /mois', '${((_dailyAmount * 30 / product.price) * 100).toStringAsFixed(0)}%', Icons.trending_up_rounded),
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
                      onPressed: _isSaving ? null : _startSaving,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('COMMENCER L\'ÉPARGNE',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15)),
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
