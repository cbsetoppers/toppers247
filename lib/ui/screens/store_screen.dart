import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/store_product_model.dart';
import '../widgets/aesthetic_click_effect.dart';
import 'product_preview_screen.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String _selectedCategory = 'ALL';
  final List<String> _categories = [
    'ALL',
    'CBSE',
    'JEE',
    'NEET',
    'CUET',
    'PREMIUM',
  ];

  late PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerTimer(int totalBanners) {
    _bannerTimer?.cancel();
    if (totalBanners <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_bannerController.hasClients) {
        _currentBannerPage = (_currentBannerPage + 1) % totalBanners;
        _bannerController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(storeProductsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildStoreAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _buildCategoryTabs(isDark),
            ),
          ),
          productsAsync.when(
            data: (products) {
              final filteredItems = _selectedCategory == 'ALL'
                  ? products
                  : products
                        .where(
                          (p) =>
                              (p.category?.toUpperCase() ==
                                  _selectedCategory.toUpperCase()) ||
                              (p.exam?.toUpperCase() ==
                                  _selectedCategory.toUpperCase()),
                        )
                        .toList();

              if (filteredItems.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'NO ITEMS FOUND',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white24 : Colors.black12,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = filteredItems[index];
                    final user = ref.watch(authProvider).value;
                    final plan = user?.subscriptionPlan ?? 'free';
                    return _buildProductCard(product, isDark, plan);
                  }, childCount: filteredItems.length),
                ),
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGold,
                  strokeWidth: 3,
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  'Error: $e',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildStoreAppBar(bool isDark) {
    final bannersAsync = ref.watch(storeBannersProvider);

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: bannersAsync.when(
          data: (banners) {
            final total = banners.length + 1;
            if (_bannerTimer == null && banners.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _startBannerTimer(total),
              );
            }

            return PageView.builder(
              controller: _bannerController,
              onPageChanged: (v) => _currentBannerPage = v,
              itemCount: total,
              itemBuilder: (context, index) {
                if (index == 0) return _buildDefaultBanner(isDark);
                return _buildImageBanner(banners[index - 1].imageUrl);
              },
            );
          },
          loading: () => _buildDefaultBanner(isDark),
          error: (_, _) => _buildDefaultBanner(isDark),
        ),
      ),
    );
  }

  Widget _buildImageBanner(String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (_, _, _) => _buildDefaultBanner(true),
        ),
        // Gradient overlay for readability if needed
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultBanner(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGold.withOpacity(0.15),
                AppTheme.primaryGold.withOpacity(0.02),
                Theme.of(context).scaffoldBackgroundColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGold.withOpacity(0.08),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.primaryGold.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryGold,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PREMIUM RESOURCES',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryGold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().scale(),
              const SizedBox(height: 16),
              Text(
                'T0PPER STORE',
                style: GoogleFonts.outfit(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textHeadingColor,
                  letterSpacing: -1,
                ),
              ).animate().fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 2),
              Text(
                'BRIDGE TO SUCCESS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                  letterSpacing: 6,
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGold
                    : (isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryGold
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white60 : Colors.black54),
                  letterSpacing: 1,
                ),
              ),
            ),
          ).animate().fadeIn(delay: (index * 50).ms).scale();
        },
      ),
    );
  }

  Widget _buildProductCard(
    StoreProductModel product,
    bool isDark,
    String plan,
  ) {
    final hasPlan = plan != 'free';
    final planPrice = product.getPlanPrice(plan);
    final isDiscounted = hasPlan && planPrice < product.sellingPrice;

    return AestheticClickEffect(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductPreviewScreen(product: product),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        color: isDark ? Colors.black26 : Colors.grey.shade50,
                        child: Hero(
                          tag: 'store_${product.id}',
                          child: _buildIcon(product),
                        ),
                      ),
                      if (product.discountPercentage > 0)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '-${product.discountPercentage.toInt()}%',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      if (isDiscounted)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGold.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'PLAN PRICE',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : AppTheme.textHeadingColor,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isDiscounted)
                                Text(
                                  '₹${product.sellingPrice.toInt()}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                    letterSpacing: 0,
                                  ),
                                )
                              else if (product.discountPercentage > 0)
                                Text(
                                  '₹${product.originalPrice.toInt()}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                    letterSpacing: 0,
                                  ),
                                ),
                              Text(
                                '₹${planPrice.toInt()}',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryGold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shopping_cart_outlined,
                              size: 16,
                              color: AppTheme.primaryGold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }

  Widget _buildIcon(StoreProductModel product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackIcon(),
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Center(
      child:
          Icon(
                Icons.auto_stories_rounded,
                color: AppTheme.primaryGold.withOpacity(0.5),
                size: 56,
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 2.seconds),
    );
  }
}
