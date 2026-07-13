import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/catalogue_provider.dart';
import '../agent/agent_enrollment_screen.dart';
import 'contribution_config_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final cart = catalogue.cart;
    final total = catalogue.cartTotal;
    final isAgent = ref.watch(authProvider).role == 'agent';

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
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Vider le panier', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                    content: Text(
                      'Supprimer tous les articles du panier ?',
                      style: GoogleFonts.inter(),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(catalogueProvider.notifier).clearCart();
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
                  Text(
                    'Votre panier est vide',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.grey.shade400, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajoutez des articles depuis le catalogue',
                    style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                  ),
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
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final line = cart[index];
                      final product = line.product;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(product.imageUrl, width: 80, height: 80, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(product.category, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Text(
                                    line.formattedLineTotal,
                                    style: GoogleFonts.manrope(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _qtyBtn(
                                        icon: Icons.remove_rounded,
                                        onTap: () => ref
                                            .read(catalogueProvider.notifier)
                                            .setCartQuantity(product.id, line.quantity - 1),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          '${line.quantity}',
                                          style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 16),
                                        ),
                                      ),
                                      _qtyBtn(
                                        icon: Icons.add_rounded,
                                        onTap: () => ref
                                            .read(catalogueProvider.notifier)
                                            .setCartQuantity(product.id, line.quantity + 1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                                  onPressed: () => ref.read(catalogueProvider.notifier).removeFromCart(product.id),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                                  ),
                                  child: Text(
                                    isAgent ? 'Détails' : 'Épargner',
                                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.05);
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sous-total (${catalogue.cartItemCount} art.)', style: GoogleFonts.inter(fontSize: 13)),
                          Text(
                            '${total.toInt()} FCFA',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          if (isAgent) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AgentEnrollmentScreen(fromCart: true)),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ContributionConfigScreen()),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          isAgent ? 'Inscrire un client' : 'Valider le panier',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _qtyBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.secondary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 18, color: AppColors.secondary)),
      ),
    );
  }
}
