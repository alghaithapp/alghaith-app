import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Cairo', decoration: TextDecoration.none),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.orange, Colors.amber]),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 20)],
                  ),
                  child: const Icon(CupertinoIcons.drop_fill, color: Colors.white, size: 60),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Al-Ghaith",
                  style: TextStyle(color: CupertinoColors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1),
                ),
                const SizedBox(height: 10),
                const Text(
                  "بوابتك للخدمات المتكاملة في العراق",
                  style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text(
                  "اختر اللغة لتبدأ / Select Language",
                  style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        color: CupertinoColors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        onPressed: () => appProvider.setLanguage('ar'),
                        child: const Text("العربية", style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        color: CupertinoColors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        onPressed: () => appProvider.setLanguage('en'),
                        child: const Text("English", style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
