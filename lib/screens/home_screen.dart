import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/dummy_data.dart';
import 'category_items_screen.dart';

import '../widgets/app_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 100), // هوامش جانبية 8 بكسل
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 7, // المسافة بين الكارتين 7 بكسل
            mainAxisSpacing: 7,  // المسافة الرأسية 7 بكسل
            childAspectRatio: 0.85,
          ),
          itemCount: DummyData.categories.length,
          itemBuilder: (context, index) {
            final cat = DummyData.categories[index];
            final isActive = appProvider.selectedCategory == cat.id;
            return GestureDetector(
              onTap: () {
                appProvider.setCategory(cat.id);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => CategoryItemsScreen(category: cat),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isActive ? Colors.orange : Colors.transparent, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: AppImage(
                  imageData: cat.image,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
