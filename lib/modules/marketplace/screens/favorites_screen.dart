import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/extensions.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_state_views.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    // جلب العناصر المفضلة فقط من الـ Provider
    final favoriteItems = appProvider.items.where((item) => item.isFavorite).toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text("المفضلة", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ),
      child: SafeArea(
        child: favoriteItems.isEmpty
            ? const EmptyStateView(
                icon: CupertinoIcons.heart_slash,
                title: 'قائمة المفضلة فارغة',
                message: 'أضف المنتجات التي تعجبك لتجدها هنا بسهولة.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favoriteItems.length,
                itemBuilder: (context, index) {
                  final item = favoriteItems[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        AppImage(
                          imageData: item.imageBase64 ?? item.image,
                          width: 100,
                          height: 100,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                              Text("${item.price.toLocaleString()} د.ع", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.heart_fill, color: Colors.red),
                          onPressed: () => appProvider.toggleFavorite(item.id),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
