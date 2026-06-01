import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/merchant_models.dart';
import '../../providers/app_provider.dart';

class MerchantOffersScreen extends StatelessWidget {
  const MerchantOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final labels = provider.merchantLabels;
    final offers = provider.merchantOffers;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(
          isAr ? 'عروض ${labels.storeLabelAr}' : '${labels.storeLabelEn} Offers',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _showOfferDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              isAr ? 'إنشاء عرض جديد' : 'Create new offer',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (offers.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_offer_outlined,
                      size: 42, color: Colors.deepOrange),
                  const SizedBox(height: 10),
                  Text(
                    isAr ? 'لا توجد عروض بعد' : 'No offers yet',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr
                        ? 'أنشئ أول عرض أو خصم واختر المنتجات من قائمة متجرك.'
                        : 'Create your first offer and pick items from your store menu.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else
            ...offers.map(
              (offer) => _OfferCard(
                offer: offer,
                isAr: isAr,
                onEdit: () => _showOfferDialog(context, offer: offer),
                onToggle: () => context
                    .read<AppProvider>()
                    .toggleMerchantOfferActive(offer.id),
                onDelete: () => _confirmDelete(context, offer),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showOfferDialog(
    BuildContext context, {
    MerchantOffer? offer,
  }) async {
    final provider = context.read<AppProvider>();
    final isEdit = offer != null;
    final isAr = provider.lang == 'ar';
    final availableProducts = provider.merchantItems;

    final formKey = GlobalKey<FormState>();
    final titleArController = TextEditingController(text: offer?.titleAr ?? '');
    final titleEnController = TextEditingController(text: offer?.titleEn ?? '');
    final discountController =
        TextEditingController(text: offer?.discountPercent.toString() ?? '');
    final selectedProducts = <String>{...?offer?.productNamesAr};

    DateTime startDate = _parseDate(offer?.startDate) ?? DateTime.now();
    DateTime endDate = _parseDate(offer?.endDate) ??
        DateTime.now().add(const Duration(days: 7));
    bool isActive = offer?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStartDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  startDate = picked;
                  if (endDate.isBefore(startDate)) {
                    endDate = startDate.add(const Duration(days: 7));
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                firstDate: startDate,
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  endDate = picked;
                });
              }
            }

            return AlertDialog(
              title: Text(
                isEdit
                    ? (isAr ? 'تعديل العرض' : 'Edit offer')
                    : (isAr ? 'إنشاء عرض جديد' : 'Create offer'),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: titleArController,
                        decoration: InputDecoration(
                          labelText: isAr
                              ? 'عنوان العرض بالعربية'
                              : 'Offer title in Arabic',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return isAr
                                ? 'اكتب عنوان العرض'
                                : 'Enter offer title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleEnController,
                        decoration: InputDecoration(
                          labelText: isAr
                              ? 'العنوان بالإنجليزية'
                              : 'Offer title in English',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              isAr ? 'نسبة الخصم' : 'Discount percent',
                          suffixText: '%',
                        ),
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0 || parsed > 100) {
                            return isAr
                                ? 'أدخل نسبة صحيحة بين 1 و100'
                                : 'Enter a valid percent from 1 to 100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isAr ? 'اختر من قائمة المنتجات' : 'Choose products',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (availableProducts.isEmpty)
                        Text(
                          isAr
                              ? 'لا توجد منتجات بعد. أضف منتجات أولًا ثم أنشئ العرض.'
                              : 'No products yet. Add products first.',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.grey,
                          ),
                        )
                      else
                        ...availableProducts.map(
                          (product) => CheckboxListTile(
                            value: selectedProducts.contains(product.nameAr),
                            onChanged: (selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  selectedProducts.add(product.nameAr);
                                } else {
                                  selectedProducts.remove(product.nameAr);
                                }
                              });
                            },
                            title: Text(
                              isAr ? product.nameAr : product.nameEn,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                        title: Text(
                          isAr ? 'العرض فعال' : 'Offer is active',
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: pickStartDate,
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text(
                              isAr
                                  ? 'البداية: ${_formatDate(startDate)}'
                                  : 'Start: ${_formatDate(startDate)}',
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: pickEndDate,
                            icon: const Icon(Icons.event_available_rounded),
                            label: Text(
                              isAr
                                  ? 'النهاية: ${_formatDate(endDate)}'
                                  : 'End: ${_formatDate(endDate)}',
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    if (selectedProducts.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isAr
                                ? 'اختر منتجًا واحدًا على الأقل'
                                : 'Select at least one product',
                          ),
                        ),
                      );
                      return;
                    }

                    final parsedDiscount =
                        int.parse(discountController.text.trim());
                    final payload = MerchantOffer(
                      id: offer?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      titleAr: titleArController.text.trim(),
                      titleEn: titleEnController.text.trim(),
                      discountPercent: parsedDiscount,
                      startDate: _formatDate(startDate),
                      endDate: _formatDate(endDate),
                      productNamesAr: selectedProducts.toList(),
                      isActive: isActive,
                    );

                    if (isEdit) {
                      provider.updateMerchantOffer(payload);
                    } else {
                      provider.addMerchantOffer(payload);
                    }

                    Navigator.pop(dialogContext);
                  },
                  child: Text(isAr ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MerchantOffer offer,
  ) async {
    final provider = context.read<AppProvider>();
    final isAr = provider.lang == 'ar';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isAr ? 'حذف العرض' : 'Delete offer',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        content: Text(
          isAr
              ? 'هل تريد حذف هذا العرض نهائيًا؟'
              : 'Do you want to delete this offer permanently?',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      provider.deleteMerchantOffer(offer.id);
    }
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.replaceAll('/', '-'));
  }

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _OfferCard extends StatelessWidget {
  final MerchantOffer offer;
  final bool isAr;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _OfferCard({
    required this.offer,
    required this.isAr,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isAr ? offer.titleAr : offer.titleEn,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Switch(
                value: offer.isActive,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'خصم ${offer.discountPercent}%'
                : '${offer.discountPercent}% discount',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.deepOrange,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'من ${offer.startDate} إلى ${offer.endDate}'
                : 'From ${offer.startDate} to ${offer.endDate}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey,
            ),
          ),
          if (offer.productNamesAr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: offer.productNamesAr
                  .map(
                    (name) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  isAr ? 'تعديل' : 'Edit',
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  isAr ? 'حذف' : 'Delete',
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
