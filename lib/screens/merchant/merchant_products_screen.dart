import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/catalog/marketplace_catalog.dart';
import '../../core/storage/bazaar_approval_notice_store.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/dummy_data.dart';
import '../../utils/sync_error_message.dart';
import '../../utils/extensions.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';
import '../real_estate_form_screen.dart';
import 'merchant_store_sections_screen.dart';
import 'merchant_store_settings_screen.dart';
import 'merchant_profile_screen.dart';
import 'product_form_screen.dart';

const _bg = Color(0xFFF2F2F7);
const _brand = Color(0xFFF5A01D);

const _shadowSoft = [
  BoxShadow(
    color: Color(0x12000000),
    blurRadius: 20,
    offset: Offset(0, 8),
  ),
];

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSyncingCatalog = false;
  bool _showBazaarApprovedNotice = false;
  bool? _lastBazaarApproved;
  bool _showSearch = false;

  bool _ensureCanPublish(AppProvider provider, String serviceId) {
    if (provider.canPublishForService(serviceId)) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'حدد موقع المتجر على الخريطة قبل نشر المنتجات.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
    return false;
  }

  Future<void> _syncCatalogNow(AppProvider provider) async {
    if (_isSyncingCatalog) return;
    setState(() => _isSyncingCatalog = true);
    try {
      await provider.syncMerchantCatalogToCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تمت مزامنة بيانات المتجر والمنتجات بنجاح.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncErrorMessage(error),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingCatalog = false);
    }
  }

  void _openProfessionalProfileEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MerchantStoreSettingsScreen()),
    );
  }

  void _openAddForm(AppProvider provider, String serviceId) {
    if (!_ensureCanPublish(provider, serviceId)) return;
    if (serviceId == 'professionals') {
      _openProfessionalProfileEditor();
      return;
    }
    if (serviceId == 'real_estate') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const RealEstateFormScreen(mode: 'sell'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          isRestaurant: serviceId == 'restaurant',
          serviceId: serviceId,
        ),
      ),
    );
  }

  void _openEditForm(AppProvider provider, ListItem item, String serviceId) {
    if (serviceId == 'professionals') {
      _openProfessionalProfileEditor();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => serviceId == 'real_estate'
            ? RealEstateFormScreen(
                mode: item.listingMode ?? 'sell',
                item: item,
              )
            : ProductFormScreen(
                isRestaurant: serviceId == 'restaurant',
                serviceId: serviceId,
                item: item,
              ),
      ),
    );
  }

  Future<void> _confirmDelete(
    AppProvider provider,
    ListItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'حذف المنتج',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        content: Text(
          'هل تريد حذف «${item.nameAr}»؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppButtonStyles.accentFilled(),
            child: const Text(
              'حذف',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deleteProduct(item.id);
  }

  String _pageSubtitle(String serviceId, MerchantServiceLabels labels) {
    switch (normalizeMerchantServiceId(serviceId)) {
      case 'restaurant':
        return 'إدارة منيو مطعمك وخدماتك بسهولة';
      case 'real_estate':
        return 'إدارة عقاراتك وخدماتك بسهولة';
      case 'cars':
        return 'إدارة سياراتك وخدماتك بسهولة';
      case 'professionals':
        return 'إدارة ملفك المهني وخدماتك بسهولة';
      default:
        return 'إدارة ${labels.itemPluralAr}ك وخدماتك بسهولة';
    }
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });
    if (_showSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _searchFocusNode.unfocus();
    });
  }

  String? _professionalCategoryName(String? categoryId) {
    final id = categoryId?.trim();
    if (id == null || id.isEmpty) return null;
    for (final category in DummyData.professionalsSubCategories) {
      if (category.id == id) return category.titleAr;
    }
    return null;
  }

  Widget _buildProfessionalProfileTab(
    BuildContext context,
    AppProvider provider,
    MerchantServiceLabels labels,
    List<String> serviceIds,
  ) {
    final storeName = provider.merchantStoreName.trim().isNotEmpty
        ? provider.merchantStoreName.trim()
        : 'اسم المهني';
    final description = provider.merchantDescription.trim().isNotEmpty
        ? provider.merchantDescription.trim()
        : 'أضف وصفاً مختصراً عن خبرتك وخدماتك.';
    final professionName =
        _professionalCategoryName(provider.merchantProfessionalCategoryId) ??
            'التخصص غير محدد';
    final profileImage = provider.merchantProfileImageBase64 ??
        provider.merchantProfileImageUrl ??
        provider.merchantLogoImage;
    final workSamples = provider.merchantWorkSampleImagesBase64
        .where((sample) => sample.trim().isNotEmpty)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: _bg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _PageHeader(
              title: labels.productsTitleAr,
              subtitle: _pageSubtitle('professionals', labels),
              searchActive: false,
              onSearchTap: () {},
            ),
            if (serviceIds.length > 1) ...[
              const SizedBox(height: 16),
              _ServiceChipsRow(
                serviceIds: serviceIds,
                activeId: 'professionals',
                onSelected: provider.setMerchantActiveService,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: _shadowSoft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: AppImage(
                            imageData: profileImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EAF6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                professionName,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3949AB),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                height: 1.5,
                                color: Color(0xFF636366),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        provider.isMerchantStoreOpen
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_rounded,
                        size: 18,
                        color: provider.isMerchantStoreOpen
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF9500),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isMerchantStoreOpen ? 'متاح للزبائن' : 'غير متاح حالياً',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'نماذج الأعمال',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 10),
            if (workSamples.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _shadowSoft,
                ),
                child: const Text(
                  'لم تُضف صوراً لنماذج أعمالك بعد. أضف صوراً من تعديل الملف.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workSamples.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AppImage(
                      imageData: workSamples[index],
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _openProfessionalProfileEditor,
                style: AppButtonStyles.accentFilled(),
                child: const Text(
                  'تعديل الملف المهني',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MerchantProfileScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'معاينة الملف كما يراه الزبون',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshBazaarNoticeState() async {
    final provider = context.read<AppProvider>();
    final phone = provider.authPhone?.trim() ?? '';
    if (phone.isEmpty) {
      if (mounted) setState(() => _showBazaarApprovedNotice = false);
      return;
    }

    if (!provider.isBazaarApproved) {
      await BazaarApprovalNoticeStore.clearSeen(phone);
      if (mounted) setState(() => _showBazaarApprovedNotice = false);
      return;
    }

    final seen = await BazaarApprovalNoticeStore.hasSeen(phone);
    if (mounted) setState(() => _showBazaarApprovedNotice = !seen);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (_lastBazaarApproved != provider.isBazaarApproved) {
      _lastBazaarApproved = provider.isBazaarApproved;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshBazaarNoticeState();
      });
    }
    final serviceId = provider.merchantActiveServiceId;
    final labels = merchantServiceLabels(serviceId);
    final serviceIds = provider.merchantServiceIds;
    final query = _searchController.text.trim().toLowerCase();
    final allItems = provider.merchantItems;
    final items = allItems.where((item) {
      if (query.isEmpty) return true;
      return item.nameAr.toLowerCase().contains(query) ||
          item.nameEn.toLowerCase().contains(query);
    }).toList();

    final total = allItems.length;
    final available = allItems.where((e) => e.isAvailable).length;
    final unavailable = total - available;

    if (serviceId == 'professionals') {
      return _buildProfessionalProfileTab(
        context,
        provider,
        labels,
        serviceIds,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: _bg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _PageHeader(
              title: labels.productsTitleAr,
              subtitle: _pageSubtitle(serviceId, labels),
              searchActive:
                  _showSearch || _searchController.text.trim().isNotEmpty,
              onSearchTap: _toggleSearch,
            ),
            if (_showSearch) ...[
              const SizedBox(height: 12),
              _SearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (_) => setState(() {}),
                onClose: _closeSearch,
              ),
            ],
            if (serviceIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ServiceChipsRow(
                serviceIds: serviceIds,
                activeId: serviceId,
                onSelected: provider.setMerchantActiveService,
              ),
            ],
            const SizedBox(height: 16),
            _StatsCard(
              total: total,
              available: available,
              unavailable: unavailable,
            ),
            if (serviceId == 'product' ||
                serviceId == 'restaurant' ||
                serviceId == 'bazar_ghaith') ...[
              const SizedBox(height: 14),
              if (provider.isBazaarApproved && _showBazaarApprovedNotice)
                _BazaarApprovedBanner(
                  onDisplayed: () {
                    final phone = provider.authPhone?.trim() ?? '';
                    if (phone.isNotEmpty) {
                      BazaarApprovalNoticeStore.markSeen(phone);
                    }
                  },
                )
              else if (!provider.isBazaarApproved)
                const _BazaarVisibilityBanner(),
            ],
            const SizedBox(height: 14),
            if (serviceId == 'product' ||
                serviceId == 'restaurant' ||
                serviceId == 'bazar_ghaith') ...[
              _StoreSectionsBanner(
                isRestaurant: serviceId == 'restaurant',
                sectionCount: provider.merchantProductSections.length,
                onManage: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MerchantStoreSectionsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
            _ActionRow(
              addLabel: labels.addItemAr,
              isSyncing: _isSyncingCatalog,
              onAdd: () => _openAddForm(provider, serviceId),
              onSync: () => _syncCatalogNow(provider),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              _EmptyProductsCard(message: 'لا توجد ${labels.itemPluralAr} هنا')
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PremiumProductCard(
                    item: item,
                    sectionLabel: (serviceId == 'product' ||
                            serviceId == 'restaurant' ||
                            serviceId == 'bazar_ghaith')
                        ? provider.merchantProductSectionName(item.sectionId)
                        : null,
                    onToggle: () async {
                      final newValue = !item.isAvailable;
                      try {
                        await provider.updateProduct(
                          item.copyWith(isAvailable: newValue),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تعذّر تحديث حالة المنتج. تحقق من الاتصال وحاول مجدداً.',
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        );
                      }
                    },
                    onEdit: () => _openEditForm(provider, item, serviceId),
                    onDelete: () => _confirmDelete(provider, item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreSectionsBanner extends StatelessWidget {
  final bool isRestaurant;
  final int sectionCount;
  final VoidCallback onManage;

  const _StoreSectionsBanner({
    this.isRestaurant = false,
    required this.sectionCount,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.category_rounded, color: _brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRestaurant ? 'أقسام مطعمك' : 'أقسام متجرك',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  sectionCount == 0
                      ? (isRestaurant
                          ? 'أنشئ أقسام المنيو (بيتزا، شاورما…) قبل نشر الأصناف'
                          : 'لم تُنشئ أقساماً بعد — الزبون يرى منتجاتك دون تنظيم')
                      : '$sectionCount قسم — يرتب ${isRestaurant ? 'منيوك' : 'منتجاتك'} للزبون',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onManage,
            style: AppButtonStyles.accentFilled(
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(
              sectionCount == 0 ? 'إنشاء' : 'إدارة',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header & service chips
// ─────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSearchTap;
  final bool searchActive;

  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.onSearchTap,
    this.searchActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1C1C1E),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Color(0xFF636366),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _SearchIconButton(
          active: searchActive,
          onTap: onSearchTap,
        ),
      ],
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _SearchIconButton({
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _brand.withValues(alpha: 0.14) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _shadowSoft,
            border: active
                ? Border.all(color: _brand.withValues(alpha: 0.45))
                : null,
          ),
          child: Icon(
            Icons.search_rounded,
            color: active ? _brand : const Color(0xFF1C1C1E),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ServiceChipsRow extends StatelessWidget {
  final List<String> serviceIds;
  final String activeId;
  final Future<void> Function(String) onSelected;

  const _ServiceChipsRow({
    required this.serviceIds,
    required this.activeId,
    required this.onSelected,
  });

  static _ServiceChipStyle _styleFor(String id) {
    switch (id) {
      case 'restaurant':
        return const _ServiceChipStyle(
          label: 'مطعم',
          icon: Icons.restaurant_rounded,
        );
      case 'product':
        return const _ServiceChipStyle(
          label: 'منتجات',
          icon: Icons.shopping_bag_rounded,
        );
      case 'real_estate':
        return const _ServiceChipStyle(
          label: 'عقارات',
          icon: Icons.home_work_rounded,
        );
      case 'cars':
        return const _ServiceChipStyle(
          label: 'سيارات',
          icon: Icons.directions_car_rounded,
        );
      case 'professionals':
        return const _ServiceChipStyle(
          label: 'مهنيين',
          icon: Icons.work_rounded,
        );
      default:
        final cat = DummyData.categories
            .where((c) => c.id == id)
            .map((c) => c.titleAr)
            .firstOrNull;
        return _ServiceChipStyle(
          label: cat ?? merchantServiceLabels(id).storeLabelAr,
          icon: Icons.storefront_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: serviceIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final id = serviceIds[index];
          final style = _styleFor(id);
          final selected = id == activeId;
          return GestureDetector(
            onTap: () => onSelected(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _brand : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _brand : const Color(0xFFE5E5EA),
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x26E60012),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    style.icon,
                    size: 18,
                    color: selected ? Colors.white : const Color(0xFF8E8E93),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    style.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceChipStyle {
  final String label;
  final IconData icon;

  const _ServiceChipStyle({required this.label, required this.icon});
}

// ─────────────────────────────────────────────────────────────
// Stats & search
// ─────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int total;
  final int available;
  final int unavailable;

  const _StatsCard({
    required this.total,
    required this.available,
    required this.unavailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _shadowSoft,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                label: 'إجمالي المنتجات',
                value: '$total',
                valueColor: const Color(0xFF1C1C1E),
              ),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE5E5EA)),
            Expanded(
              child: _StatColumn(
                label: 'المنتجات المتاحة',
                value: '$available',
                valueColor: const Color(0xFF34C759),
              ),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE5E5EA)),
            Expanded(
              child: _StatColumn(
                label: 'المنتجات غير المتاحة',
                value: '$unavailable',
                valueColor: const Color(0xFFFF3B30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: valueColor,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _shadowSoft,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        decoration: InputDecoration(
          hintText: 'ابحث باسم المنتج العربي أو الإنجليزي',
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: Color(0xFFAEAEB2),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF8E8E93),
          ),
          suffixIcon: IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF8E8E93),
              size: 20,
            ),
            tooltip: 'إغلاق البحث',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Action row
// ─────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final String addLabel;
  final bool isSyncing;
  final VoidCallback onAdd;
  final VoidCallback onSync;

  const _ActionRow({
    required this.addLabel,
    required this.isSyncing,
    required this.onAdd,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              addLabel,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            style: AppButtonStyles.accentFilled(
              borderRadius: BorderRadius.circular(999),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: isSyncing ? null : onSync,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1C1C1E),
            backgroundColor: Colors.white,
            minimumSize: const Size(120, 48),
            side: const BorderSide(color: Color(0xFFE5E5EA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.sync_rounded, size: 20, color: Color(0xFF8E8E93)),
              const SizedBox(width: 6),
              Text(
                isSyncing ? 'جاري' : 'مزامنة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Product card
// ─────────────────────────────────────────────────────────────

class _PremiumProductCard extends StatelessWidget {
  final ListItem item;
  final String? sectionLabel;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PremiumProductCard({
    required this.item,
    this.sectionLabel,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  String get _categoryLabel {
    if (sectionLabel != null && sectionLabel!.trim().isNotEmpty) {
      return sectionLabel!.trim();
    }
    if (item.subCategory != null && item.subCategory!.trim().isNotEmpty) {
      return MarketplaceCatalog.shoppingSubCategoryTitle(item.subCategory) ??
          item.subCategory!.trim();
    }
    if (item.categoryLabelAr.trim().isNotEmpty) return item.categoryLabelAr;
    return item.category;
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = AppImage(
      imageData: item.imageBase64 != null && item.imageBase64!.isNotEmpty
          ? item.imageBase64
          : item.image,
      width: 88,
      height: 88,
      borderRadius: BorderRadius.circular(16),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _shadowSoft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageWidget,
                      if (!item.isAvailable)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFFF3B30),
                    bg: const Color(0xFFFFEBEE),
                    onTap: onDelete,
                  ),
                  const SizedBox(width: 8),
                  _IconActionButton(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF8E8E93),
                    bg: const Color(0xFFF2F2F7),
                    onTap: onEdit,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!item.isApproved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                    ),
                    child: const Text(
                      'بانتظار موافقة الإدارة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                Text(
                  item.nameAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.nameEn.isNotEmpty ? item.nameEn : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.price.toPrice()} د.ع',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                if (item.rating != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFFFCC00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _categoryLabel,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Color(0xFFAEAEB2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.isAvailable ? 'متاح' : 'غير متاح',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: item.isAvailable
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF3B30),
                ),
              ),
              const SizedBox(height: 6),
              Transform.scale(
                scale: 0.85,
                child: CupertinoSwitch(
                  value: item.isAvailable,
                  activeTrackColor: const Color(0xFF34C759),
                  onChanged: (_) => onToggle(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _EmptyProductsCard extends StatelessWidget {
  final String message;

  const _EmptyProductsCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _shadowSoft,
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: const Color(0xFF8E8E93).withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }
}

class _BazaarApprovedBanner extends StatefulWidget {
  final VoidCallback onDisplayed;

  const _BazaarApprovedBanner({required this.onDisplayed});

  @override
  State<_BazaarApprovedBanner> createState() => _BazaarApprovedBannerState();
}

class _BazaarApprovedBannerState extends State<_BazaarApprovedBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDisplayed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'عضوية البازار مفعّلة. منتجاتك المنشورة في قسمك '
              '(منتجات أو مطاعم) تظهر للزبائن في قسمك وفي '
              '«بازار ومطاعم الغيث» معاً — دون إعادة نشر.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF166534),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BazaarVisibilityBanner extends StatelessWidget {
  const _BazaarVisibilityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'انشر في قسمك (منتجات أو مطاعم) كأي تاجر. عند موافقة '
              'الإدارة على عضوية البازار ستظهر منتجاتك تلقائياً في '
              'قسمك وفي «بازار ومطاعم الغيث» — دون إعادة نشر.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
