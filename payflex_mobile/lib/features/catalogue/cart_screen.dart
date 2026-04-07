import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/catalogue_provider.dart';
import 'product_detail_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(catalogueProvider).cart;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mon Panier',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Vider le panier', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                    content: Text('Êtes-vous sûr de vouloir supprimer tous les articles ?',
                      style: GoogleFonts.inter()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          for (final p in [...cart]) {
                            ref.read(catalogueProvider.notifier).removeFromCart(p.id);
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                        child: const Text('Vider', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Vider', style: GoogleFonts.manrope(color: Colors.red.shade400, fontSize: 13)),
            ),
        ],
      ),
      body: cart.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                Text('Votre panier est vide',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.grey.shade400, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Ajoutez des articles depuis le catalogue',
                  style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13)),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Explorer le catalogue', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final product = cart[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        product.imageUrl, width: 80, height: 80, fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(product.category,
                            style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 8),
                          Text(product.formattedPrice,
                            style: GoogleFonts.manrope(
                              color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15,
                            )),
                          Text('Dès ${product.formattedDaily}',
                            style: GoogleFonts.inter(color: const Color(0xFF38A169), fontSize: 11)),
                        ],
                      ),
                    ),
                    // Actions
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                          onPressed: () => ref.read(catalogueProvider.notifier).removeFromCart(product.id),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: product),
                          )),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Épargner',
                              style: GoogleFonts.manrope(
                                fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary,
                              )),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.05);
            },
          ),
    );
  }
}
