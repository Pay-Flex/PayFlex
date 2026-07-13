import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/catalogue_provider.dart';
import '../../core/providers/client_inbox_provider.dart';
import '../../core/services/payflex_poll_config.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/widgets/count_badge.dart';
import '../../core/widgets/offline_banner.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import '../auth/widgets/registration_feature_guard.dart';
import '../chat/chat_screen.dart';

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key, this.isAgent = false});

  final bool isAgent;

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _searchController = TextEditingController();
  Timer? _cataloguePollTimer;

  static const Map<String, IconData> _categoryIcons = {
    'Tous': Icons.dashboard_customize_rounded,
    'Couture': Icons.content_cut_rounded,
    'Coiffure': Icons.face_retouching_natural_rounded,
    'Mécanique': Icons.settings_suggest_rounded,
    'Menuiserie': Icons.carpenter_rounded,
    'Maçonnerie': Icons.construction_rounded,
    'Soudure': Icons.bolt_rounded,
    'Électricité bâtiment': Icons.electrical_services_rounded,
    'Plomberie': Icons.plumbing_rounded,
    'Froid et climatisation': Icons.ac_unit_rounded,
  };

  @override
  void initState() {
    super.initState();
    _cataloguePollTimer = Timer.periodic(PayflexPollConfig.catalogue, (_) {
      if (!mounted) return;
      // IndexedStack garde les écrans montés : ne poll que si l’onglet Catalogue est visible.
      final visible = widget.isAgent
          ? ref.read(agentNavigationIndexProvider) == 2
          : ref.read(navigationIndexProvider) == 1;
      if (!visible) return;
      ref.read(catalogueProvider.notifier).loadProducts(silent: true);
    });
  }

  @override
  void dispose() {
    _cataloguePollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueProvider);
    final auth = ref.watch(authProvider);
    final inbox = !widget.isAgent && auth.role == 'client' ? ref.watch(clientInboxProvider) : null;
    final showSupportChat = !widget.isAgent;
    
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
              child: _buildBlob(AppColors.primary.withValues(alpha: 0.3), 200),
            ),

            // Contenu principal (tirer pour actualiser + polling silencieux toutes les 10 s)
            RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: () => ref.read(catalogueProvider.notifier).loadProducts(silent: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                // AppBar
                SliverAppBar(
                  expandedHeight: 70,
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.white.withValues(alpha: 0.95),
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
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined, color: AppColors.secondary, size: 20),
                            ),
                            if (ref.watch(catalogueProvider).cartItemCount > 0)
                              CountBadge(count: ref.watch(catalogueProvider).cartItemCount, top: -2, right: -2),
                          ],
                        ),
                      ),
                    ),
                    if (showSupportChat)
                      GestureDetector(
                        onTap: () {
                          if (!auth.canUseAppFeatures) {
                            showRegistrationFeatureLockedSnackBar(context, 'Discussion support');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChatScreen()),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 16),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.secondary, size: 20),
                              ),
                              if (inbox != null && inbox.chatUnread > 0)
                                CountBadge(count: inbox.chatUnread, top: -2, right: -2),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                if (catalogue.isOffline)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: OfflineBanner(
                        margin: EdgeInsets.only(top: 12),
                      ),
                    ),
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
                                  color: AppColors.secondary.withValues(alpha: 0.3),
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
                                hintStyle: GoogleFonts.manrope(color: Colors.white.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w500),
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
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Icon(Icons.tune_rounded, size: 14, color: Colors.white.withValues(alpha: 0.6)),
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
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: catalogue.categoryFilterOptions.length,
                              itemBuilder: (_, i) {
                                final cat = catalogue.categoryFilterOptions[i];
                                final isActive = catalogue.selectedCategory == cat;
                                return GestureDetector(
                                  onTap: () => ref.read(catalogueProvider.notifier).filterByCategory(cat),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: isActive ? AppColors.secondary : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isActive ? AppColors.secondary : const Color(0xFFEDF2F7),
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        children: [
                                          Icon(
                                            _categoryIcons[cat] ?? Icons.category_rounded,
                                            size: 15,
                                            color: isActive ? Colors.white : AppColors.secondary.withValues(alpha: 0.8),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            cat,
                                            style: GoogleFonts.manrope(
                                              color: isActive ? Colors.white : AppColors.secondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Section Vedette
                          if (catalogue.selectedCategory == 'Tous' && catalogue.searchQuery.isEmpty && catalogue.featuredProducts.isNotEmpty) ...[
                            _buildSectionHeader('⭐ SÉLECTION VEDETTE', 'À la une'),
                            const SizedBox(height: 16),
                            if (catalogue.featuredProducts.length == 1)
                              _buildFeaturedCard(context, catalogue.featuredProducts.first)
                            else
                              _FeaturedTicker(
                                products: catalogue.featuredProducts,
                                itemBuilder: (p) => _carouselFeaturedTile(context, p),
                              ),
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
                        childAspectRatio: 0.57,
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
        color: color.withValues(alpha: 0.12),
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

  Widget _carouselFeaturedTile(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(product.displayImageUrl, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text('Dès ${product.formattedDaily}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            image: DecorationImage(image: NetworkImage(product.displayImageUrl), fit: BoxFit.cover),
            boxShadow: [
              BoxShadow(color: AppColors.secondary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8)),
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
                    image: DecorationImage(image: NetworkImage(product.displayImageUrl), fit: BoxFit.cover),
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
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.secondary.withValues(alpha: 0.55),
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(product.formattedPrice, style: GoogleFonts.manrope(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Voir détail',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
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

/// Défilement horizontal continu pour plusieurs produits « vedette ».
class _FeaturedTicker extends StatefulWidget {
  final List<Product> products;
  final Widget Function(Product) itemBuilder;

  const _FeaturedTicker({required this.products, required this.itemBuilder});

  @override
  State<_FeaturedTicker> createState() => _FeaturedTickerState();
}

class _FeaturedTickerState extends State<_FeaturedTicker> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  static const double _cardW = 268;
  static const double _gap = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.products.length < 2) return;
      _timer = Timer.periodic(const Duration(milliseconds: 28), (_) {
        if (!mounted || !_controller.hasClients) return;
        final loop = (_cardW + _gap) * widget.products.length;
        if (loop <= 0) return;
        final next = _controller.offset + 1.1;
        if (next >= loop) {
          _controller.jumpTo(next - loop);
        } else {
          _controller.jumpTo(next);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.products;
    if (p.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemExtent: _cardW + _gap,
        itemCount: p.length * 800,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: SizedBox(
              width: _cardW,
              child: widget.itemBuilder(p[i % p.length]),
            ),
          );
        },
      ),
    );
  }
}
