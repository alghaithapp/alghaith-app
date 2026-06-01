import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';
import '../utils/translations.dart';
import '../widgets/app_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final lang = appProvider.lang;
    final isAr = lang == 'ar';
    final cart = appProvider.cart;
    const deliveryFee = 3000;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppTranslations.t('cart', lang),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        border: null,
      ),
      child: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.cart,
                      size: 80, color: CupertinoColors.systemGrey4),
                  const SizedBox(height: 16),
                  Text(isAr ? "سلتك فارغة حالياً" : "Your cart is empty",
                      style:
                          const TextStyle(color: CupertinoColors.systemGrey)),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Cart List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : CupertinoColors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              AppImage(
                                imageData: item.image,
                                width: 60,
                                height: 60,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isAr ? item.nameAr : item.nameEn,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text("${item.price.toLocaleString()} د.ع",
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: item.count > 1
                                        ? () => appProvider
                                            .decrementCartItem(item.id)
                                        : () =>
                                            appProvider.removeFromCart(item.id),
                                    child: Icon(
                                      item.count > 1
                                          ? CupertinoIcons.minus_circle
                                          : CupertinoIcons.delete_solid,
                                      color: item.count > 1
                                          ? CupertinoColors.systemGrey
                                          : CupertinoColors.systemRed,
                                    ),
                                  ),
                                  Text("${item.count}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () =>
                                        appProvider.incrementCartItem(item.id),
                                    child: const Icon(
                                        CupertinoIcons.plus_circle_fill,
                                        color: Colors.orange),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // Bill Summary (iOS Table Style)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : CupertinoColors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [
                          _buildSummaryRow(isAr ? "المجموع الفرعي" : "Subtotal",
                              "${appProvider.cartTotal.toLocaleString()} د.ع"),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                              isAr ? "رسوم التوصيل" : "Delivery fee",
                              "${deliveryFee.toLocaleString()} د.ع"),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1, color: Color(0xFFE5E5EA)),
                          ),
                          _buildSummaryRow(isAr ? "المجموع الكلي" : "Total",
                              "${(appProvider.cartTotal + deliveryFee).toLocaleString()} د.ع",
                              isTotal: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // COD Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.1))),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.info,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAr
                                  ? "الدفع يتم نقداً عند استلام الطلب من المندوب"
                                  : "Payment is made in cash upon receiving the order",
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.brown,
                                  fontWeight: FontWeight.w500),
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Checkout Button (iOS Style)
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: Colors.orange[800],
                        borderRadius: BorderRadius.circular(15),
                        onPressed: () => appProvider.checkout(),
                        child: Text(
                          AppTranslations.t('checkout', lang),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: isTotal
                    ? CupertinoColors.black
                    : CupertinoColors.systemGrey,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 17 : 14)),
        Text(value,
            style: TextStyle(
                color: isTotal ? Colors.orange[800] : CupertinoColors.black,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
                fontSize: isTotal ? 20 : 14)),
      ],
    );
  }
}
