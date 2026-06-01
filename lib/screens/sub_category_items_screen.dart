import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';
import '../widgets/app_image.dart';

class SubCategoryItemsScreen extends StatelessWidget {
  final ServiceCategory subCategory;

  const SubCategoryItemsScreen({super.key, required this.subCategory});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';
    final filteredItems = appProvider.items
        .where((item) => item.subCategory == subCategory.id)
        .toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? subCategory.titleAr : subCategory.titleEn,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        previousPageTitle: isAr ? 'الرجوع' : 'Back',
      ),
      child: SafeArea(
        child: filteredItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      size: 60,
                      color: CupertinoColors.systemGrey4,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr
                          ? 'لا توجد نتائج في قسم ${subCategory.titleAr} حاليًا'
                          : 'No items in ${subCategory.titleEn} yet',
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppImage(
                          imageData: item.image,
                          height: 180,
                          width: double.infinity,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      isAr ? item.nameAr : item.nameEn,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        appProvider.toggleFavorite(item.id),
                                    child: Icon(
                                      item.isFavorite
                                          ? CupertinoIcons.heart_fill
                                          : CupertinoIcons.heart,
                                      color: item.isFavorite
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isAr
                                    ? item.descriptionAr
                                    : item.descriptionEn,
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAr
                                            ? item.avgPriceLabelAr
                                            : item.avgPriceLabelEn,
                                        style: const TextStyle(
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 11,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                      Text(
                                        '${item.price.toLocaleString()} د.ع',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: () {
                                      appProvider.addToCart(item);
                                      showCupertinoDialog(
                                        context: context,
                                        builder: (context) =>
                                            CupertinoAlertDialog(
                                          title: Text(
                                            isAr ? 'تمت الإضافة' : 'Added',
                                          ),
                                          content: Text(
                                            isAr
                                                ? 'تمت إضافة المنتج إلى السلة بنجاح'
                                                : 'Item added to cart successfully',
                                          ),
                                          actions: [
                                            CupertinoDialogAction(
                                              child:
                                                  Text(isAr ? 'حسنًا' : 'OK'),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Text(
                                      isAr
                                          ? item.actionLabelAr
                                          : item.actionLabelEn,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
