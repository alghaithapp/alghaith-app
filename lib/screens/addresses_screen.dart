import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(isAr ? "عناويني" : "My Addresses", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add_circled_solid, color: Colors.orange),
          onPressed: () => _showAddAddressDialog(context),
        ),
      ),
      child: SafeArea(
        child: appProvider.addresses.isEmpty
            ? Center(child: Text(isAr ? "لا توجد عناوين مضافة" : "No addresses added", style: const TextStyle(fontFamily: 'Cairo')))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appProvider.addresses.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.location_solid, color: Colors.orange),
                        const SizedBox(width: 15),
                        Expanded(child: Text(appProvider.addresses[index], style: const TextStyle(fontFamily: 'Cairo'))),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.delete, color: Colors.red, size: 20),
                          onPressed: () => appProvider.removeAddress(index),
                        )
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showAddAddressDialog(BuildContext context) {
    final controller = TextEditingController();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("إضافة عنوان جديد", style: TextStyle(fontFamily: 'Cairo')),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(controller: controller, placeholder: "مثال: بغداد، الكرادة..."),
        ),
        actions: [
          CupertinoDialogAction(child: const Text("إلغاء"), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            child: const Text("إضافة"),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                appProvider.addAddress(controller.text);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
