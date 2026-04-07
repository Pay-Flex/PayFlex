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
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            // Décor atmosphérique
            Positioned(
              top: -100, right: -100,
              child: _buildBlob(AppColors.primary, 300),
            ),
            Positioned(
              bottom: -50, left: -50,
              child: _buildBlob(AppColors.primary.withOpacity(0.3), 200),
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
                    // Icone utilisateur
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=payflex'),
                      ),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barre de recherche "Elite" Sombre (Corrigée)
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => ref.read(catalogueProvider.notifier).search(v),
                              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                              cursorColor: AppColors.primary,
                              decoration: InputDecoration(
                                filled: false, // Forcer à false pour éviter les fonds gris auto
                                hintText: 'Rechercher un article ou une catégorie...',
                                hintStyle: GoogleFonts.manrope(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w500),
                                prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                                suffixIcon: catalogue.searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(catalogueProvider.notifier).search('');
                                      },
                                    )
                                  : Container(
                                      margin: const EdgeInsets.all(10),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Icon(Icons.tune_rounded, size: 14, color: Colors.white.withOpacity(0.6)),
                                    ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Catégories
                          SizedBox(
                            height: 42,
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

                          const SizedBox(height: 32),

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
                        childAspectRatio: 0.68,
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

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildSectionHeader(String label, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w900,
            color: AppColors.primary, letterSpacing: 1.5,
          )),
        const SizedBox(height: 4),
        Text(title,
          style: GoogleFonts.manrope(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: AppColors.secondary, letterSpacing: -0.5,
          )),
      ],
    );
  }

  Widget _buildFeaturedCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Hero(
        tag: 'featured_${product.id}',
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: DecorationImage(image: NetworkImage(product.imageUrl), fit: BoxFit.cover),
            boxShadow: [
              BoxShadow(color: AppColors.secondary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                      child: Text('OFFRE ÉLITE', style: GoogleFonts.manrope(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 8),
                    Text(product.name, style: GoogleFonts.manrope(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Dès ${product.formattedDaily} / jour', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: product.id,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    image: DecorationImage(image: NetworkImage(product.imageUrl), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(product.category, style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(product.formattedPrice, style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.05), shape: BoxShape.circle),
                        child: Icon(Icons.add_rounded, size: 16, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Aucun résultat trouvé', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
          Text('Essayez d\'autres mots clés ou catégories', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
