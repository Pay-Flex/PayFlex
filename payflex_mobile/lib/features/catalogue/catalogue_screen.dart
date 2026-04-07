import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import '../../core/providers/catalogue_provider.dart';
import 'product_detail_screen.dart';
import '../chat/chat_screen.dart'; // Import ChatScreen

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueProvider);
    final cartCount = catalogue.cart.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Décor atmosphérique
          Positioned(
            top: -100, right: -100,
            child: _buildBlob(AppColors.primary, 300),
          ),

          // Contenu principal
          CustomScrollView(
            slivers: [
              // AppBar
              SliverAppBar(
                expandedHeight: 70,
                floating: true,
                pinned: true,
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white.withOpacity(0.95),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Catalogue',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.secondary,
                  ),
                ),
                centerTitle: true,
                actions: [
                  // Support Chat au lieu du Panier
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.secondary, size: 20),
                      ),
                    ),
                  ),
                  // Icone utilisateur (identique au Dashboard)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=payflex'),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barre de recherche "Elite"
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(color: AppColors.secondary.withOpacity(0.05)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => ref.read(catalogueProvider.notifier).search(v),
                          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondary),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un article ou une catégorie...',
                            hintStyle: GoogleFonts.manrope(color: AppColors.secondary.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w500),
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                            suffixIcon: catalogue.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF718096), size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(catalogueProvider.notifier).search('');
                                  },
                                )
                              : Container(
                                  margin: const EdgeInsets.all(10),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.tune_rounded, size: 14, color: AppColors.secondary.withOpacity(0.4)),
                                ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Chips de catégorie cliquables
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: catalogueCategories.length,
                          itemBuilder: (_, i) {
                            final cat = catalogueCategories[i];
                            final isActive = catalogue.selectedCategory == cat;
                            return GestureDetector(
                              onTap: () => ref.read(catalogueProvider.notifier).filterByCategory(cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.secondary : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive ? AppColors.secondary : const Color(0xFFEDF2F7),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    cat,
                                    style: GoogleFonts.manrope(
                                      color: isActive ? Colors.white : AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Section Vedette
                      if (catalogue.selectedCategory == 'Tous' && catalogue.searchQuery.isEmpty && catalogue.featuredProduct != null) ...[
                        _buildSectionHeader('⭐ SÉLECTION VEDETTE', 'À la une'),
                        const SizedBox(height: 16),
                        _buildFeaturedCard(context, catalogue.featuredProduct!),
                        const SizedBox(height: 32),
                      ],

                      // Header liste
                      _buildSectionHeader(
                        catalogue.filteredProducts.isEmpty ? 'AUCUN ARTICLE' : '${catalogue.filteredProducts.length} ARTICLES',
                        catalogue.searchQuery.isNotEmpty
                          ? 'Résultats pour "${catalogue.searchQuery}"'
                          : catalogue.selectedCategory == 'Tous' ? 'Tous les articles' : catalogue.selectedCategory,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Grille de produits
              if (catalogue.isLoading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.secondary),
                    ),
                  ),
                )
              else if (catalogue.filteredProducts.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68, // Fix overflow
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = catalogue.filteredProducts[index];
                        return _buildProductCard(context, product);
                      },
                      childCount: catalogue.filteredProducts.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w900,
            letterSpacing: 1.5, color: const Color(0xFF48BB78),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 22, fontWeight: FontWeight.w900,
            height: 1.2, color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () => _openDetail(context, product),
      child: Container(
        height: 340,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          image: DecorationImage(
            image: NetworkImage(product.imageUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.2),
              blurRadius: 30, offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAFBC8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up, size: 12, color: Color(0xFF2D6A4F)),
                        const SizedBox(width: 4),
                        Text('Bestseller', style: GoogleFonts.manrope(
                          color: const Color(0xFF2D6A4F), fontSize: 10, fontWeight: FontWeight.w900,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(product.name, style: GoogleFonts.manrope(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1,
                  )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(product.formattedPrice, style: GoogleFonts.manrope(
                        color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600,
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('|', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                      ),
                      Text('À partir de ${product.formattedDaily}', style: GoogleFonts.manrope(
                        color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold,
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _openDetail(context, product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Voir le détail', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final isInCart = ref.watch(catalogueProvider).cart.any((p) => p.id == product.id);

    return GestureDetector(
      onTap: () => _openDetail(context, product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
          ],
          border: Border.all(color: const Color(0xFFEDF2F7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Hero(
                    tag: product.id,
                    child: Image.network(
                      product.imageUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 130,
                            color: const Color(0xFFEDF2F7),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                      errorBuilder: (_, __, ___) => Container(
                        height: 130,
                        color: const Color(0xFFEDF2F7),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF718096), size: 32),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: GestureDetector(
                    onTap: () {
                      if (isInCart) {
                        ref.read(catalogueProvider.notifier).removeFromCart(product.id);
                      } else {
                        ref.read(catalogueProvider.notifier).addToCart(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} ajouté au panier !',
                              style: GoogleFonts.manrope(color: Colors.white)),
                            backgroundColor: AppColors.secondary,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isInCart ? AppColors.secondary : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInCart ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
                        size: 16,
                        color: isInCart ? Colors.white : AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.secondary)),
                  const SizedBox(height: 2),
                  Text(product.category,
                    style: GoogleFonts.inter(color: const Color(0xFF718096), fontSize: 10)),
                  const SizedBox(height: 10),
                  Text(product.formattedPrice,
                    style: GoogleFonts.manrope(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4), borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF38A169)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Dès ${product.formattedDaily}',
                            style: GoogleFonts.manrope(color: const Color(0xFF38A169), fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.secondary, borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text('Voir détail',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucun article trouvé',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('Essayez une autre recherche',
              style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlob(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.04), shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  void _openDetail(BuildContext context, Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }
}
