import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FlightResultsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final String origin;
  final String destination;
  const FlightResultsScreen({super.key, required this.results, required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('$origin → $destination', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flight_takeoff, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا توجد رحلات متاحة', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: isDark ? Colors.white54 : Colors.grey)),
                    const SizedBox(height: 8),
                    Text('حاول تغيير التاريخ أو الوجهة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final flight = results[index];
                final airline = flight['airline']?.toString() ?? '';
                final flightNumber = flight['flight_number']?.toString() ?? '';
                final price = flight['price']?.toString() ?? '0';
                final departAt = flight['departure_at']?.toString() ?? '';
                final returnAt = flight['return_at']?.toString() ?? '';
                final link = flight['link']?.toString() ?? '';

                return Card(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flight, size: 20, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('$airline $flightNumber', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                            const Spacer(),
                            Text('$price د.ع', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary, fontFamily: 'Cairo')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(departAt, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey, fontFamily: 'Cairo')),
                        if (returnAt.isNotEmpty) Text(returnAt, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey, fontFamily: 'Cairo')),
                        if (link.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {/* open affiliate link */},
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('حجز', style: TextStyle(fontFamily: 'Cairo')),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
