import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/travel_api_service.dart';

class HotelResultsScreen extends StatefulWidget {
  final String searchId;
  const HotelResultsScreen({super.key, required this.searchId});

  @override
  State<HotelResultsScreen> createState() => _HotelResultsScreenState();
}

class _HotelResultsScreenState extends State<HotelResultsScreen> {
  List<Map<String, dynamic>> _hotels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await TravelApiService.instance.getHotelResults(widget.searchId);
      if (mounted) setState(() { _hotels = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نتائج الفنادق', style: TextStyle(fontFamily: 'Cairo', fontSize: 15)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('خطأ: $_error', style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)))
              : _hotels.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hotel, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('لا توجد فنادق متاحة', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: isDark ? Colors.white54 : Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _hotels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final hotel = _hotels[index];
                        final name = hotel['hotelName']?.toString() ?? hotel['name']?.toString() ?? '';
                        final price = hotel['price']?.toString() ?? '0';
                        final stars = hotel['stars']?.toString() ?? '';
                        final image = hotel['image']?.toString() ?? '';

                        return Card(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                    image: image.isNotEmpty ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover) : null,
                                  ),
                                  child: image.isEmpty ? const Icon(Icons.hotel, color: Colors.grey) : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                                      if (stars.isNotEmpty) ...[const SizedBox(height: 2), Text('⭐ $stars', style: const TextStyle(fontSize: 12))],
                                      const SizedBox(height: 4),
                                      Text('$price د.ع/ليلة', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary, fontFamily: 'Cairo')),
                                    ],
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
