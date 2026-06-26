import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/taxi_favorite_place.dart';
import '../../models/taxi_saved_place_use.dart';
import '../../providers/taxi_provider.dart';
import '../../widgets/taxi_favorite_place_sheet.dart';
import '../../widgets/taxi_saved_place_role_sheet.dart';

/// صفحة إدارة عناوين الزبون: المنزل، العمل، وأماكن أخرى.
class TaxiSavedPlacesScreen extends StatefulWidget {
  final void Function(TaxiFavoritePlace place, TaxiSavedPlaceField field)?
      onPlaceSelected;

  const TaxiSavedPlacesScreen({super.key, this.onPlaceSelected});

  @override
  State<TaxiSavedPlacesScreen> createState() => _TaxiSavedPlacesScreenState();
}

class _TaxiSavedPlacesScreenState extends State<TaxiSavedPlacesScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await context.read<TaxiProvider>().loadFavoritePlaces();
    if (mounted) setState(() => _isLoading = false);
  }

  bool _hasLabel(List<TaxiFavoritePlace> places, String label) {
    return places.any((p) => p.label.trim() == label);
  }

  Future<void> _addOrEdit({
    TaxiFavoritePlace? existing,
    String? presetLabel,
  }) async {
    final draft = await showTaxiFavoritePlaceSheet(
      context,
      existing: existing,
      presetLabel: presetLabel,
    );
    if (draft == null || !mounted) return;
    final ok = await context.read<TaxiProvider>().saveFavoritePlace(draft);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<TaxiProvider>().error ?? 'تعذّر حفظ العنوان',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }

  Future<void> _delete(TaxiFavoritePlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العنوان', style: TextStyle(fontFamily: 'Cairo')),
        content: Text(
          'حذف «${place.label}»؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<TaxiProvider>().deleteFavoritePlace(place.id);
  }

  Future<void> _usePlace(TaxiFavoritePlace place) async {
    final field = await showTaxiSavedPlaceRoleSheet(context, place: place);
    if (field == null || !mounted) return;
    widget.onPlaceSelected?.call(place, field);
  }

  IconData _iconForLabel(String label) {
    switch (label.trim()) {
      case 'المنزل':
        return Icons.home_rounded;
      case 'العمل':
        return Icons.work_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final places = context.watch<TaxiProvider>().favoritePlaces;
    final hasHome = _hasLabel(places, 'المنزل');
    final hasWork = _hasLabel(places, 'العمل');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          title: const Text(
            'عناويني المحفوظة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
        ),
        floatingActionButton: places.length >= 10
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _addOrEdit(),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add),
                label: const Text(
                  'إضافة عنوان',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                ),
              ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              Text(
                'احفظ عنوان منزلك وعملك وأماكنك المعتادة. عند اختيار أي عنوان، حدّد هل تريده كنقطة انطلاق أم وجهة.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (!hasHome || !hasWork) ...[
                const Text(
                  'إضافة سريعة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (!hasHome)
                      Expanded(
                        child: _QuickAddTile(
                          icon: Icons.home_rounded,
                          label: 'المنزل',
                          onTap: () => _addOrEdit(presetLabel: 'المنزل'),
                        ),
                      ),
                    if (!hasHome && !hasWork) const SizedBox(width: 10),
                    if (!hasWork)
                      Expanded(
                        child: _QuickAddTile(
                          icon: Icons.work_rounded,
                          label: 'العمل',
                          onTap: () => _addOrEdit(presetLabel: 'العمل'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'عناوينك',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${places.length} / 10',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (places.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.location_on_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text(
                        'لا توجد عناوين محفوظة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أضف عنوان المنزل أو العمل للوصول السريع',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...places.map(
                  (place) => _SavedPlaceCard(
                    place: place,
                    icon: _iconForLabel(place.label),
                    onTap: widget.onPlaceSelected == null
                        ? null
                        : () => _usePlace(place),
                    onEdit: () => _addOrEdit(existing: place),
                    onDelete: () => _delete(place),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                'إضافة $label',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  final TaxiFavoritePlace place;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavedPlaceCard({
    required this.place,
    required this.icon,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          place.label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          place.address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('تعديل', style: TextStyle(fontFamily: 'Cairo')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
