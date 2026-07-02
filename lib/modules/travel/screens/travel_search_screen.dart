import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/app_config_service.dart';
import '../../../providers/app_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../services/travel_api_service.dart';
import 'flight_results_screen.dart';
import 'hotel_results_screen.dart';

class TravelSearchScreen extends StatefulWidget {
  final String mode; // 'flights' | 'hotels'
  const TravelSearchScreen({super.key, required this.mode});

  @override
  State<TravelSearchScreen> createState() => _TravelSearchScreenState();
}

class _TravelSearchScreenState extends State<TravelSearchScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _queryCtrl = TextEditingController();
  DateTime? _departDate;
  DateTime? _returnDate;
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _adults = 1;
  bool _searching = false;

  bool get _isFlights => widget.mode == 'flights';

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      if (_isFlights) {
        final results = await TravelApiService.instance.searchFlights(
          origin: _originCtrl.text,
          destination: _destCtrl.text,
          departDate: _departDate?.toIso8601String().substring(0, 10) ?? '',
          returnDate: _returnDate?.toIso8601String().substring(0, 10),
          passengers: _adults,
        );
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FlightResultsScreen(results: results, origin: _originCtrl.text, destination: _destCtrl.text),
        ));
      } else {
        final searchId = await TravelApiService.instance.searchHotels(
          query: _queryCtrl.text,
          checkIn: _checkIn?.toIso8601String().substring(0, 10) ?? '',
          checkOut: _checkOut?.toIso8601String().substring(0, 10) ?? '',
          adults: _adults,
        );
        if (!mounted) return;
        if (searchId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HotelResultsScreen(searchId: searchId),
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في البحث: $e', style: const TextStyle(fontFamily: 'Cairo'))),
      );
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _pickDate({required bool isDepart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        if (_isFlights) {
          if (isDepart) _departDate = picked; else _returnDate = picked;
        } else {
          if (isDepart) _checkIn = picked; else _checkOut = picked;
        }
      });
    }
  }

  String _fmt(DateTime? d) => d != null ? '${d.year}/${d.month}/${d.day}' : 'اختر';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(_isFlights ? 'بحث رحلات الطيران' : 'بحث الفنادق', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isFlights) ...[
            _field('من (رمز المطار)', _originCtrl, hint: 'BGW - بغداد'),
            const SizedBox(height: 14),
            _field('إلى (رمز المطار)', _destCtrl, hint: 'IST - إسطنبول'),
            const SizedBox(height: 14),
            _dateTile('تاريخ الذهاب', _departDate, () => _pickDate(isDepart: true)),
            const SizedBox(height: 14),
            _dateTile('تاريخ العودة (اختياري)', _returnDate, () => _pickDate(isDepart: false)),
          ] else ...[
            _field('المدينة أو اسم الفندق', _queryCtrl, hint: 'بغداد، أربيل، إسطنبول...'),
            const SizedBox(height: 14),
            _dateTile('تاريخ الدخول', _checkIn, () => _pickDate(isDepart: true)),
            const SizedBox(height: 14),
            _dateTile('تاريخ المغادرة', _checkOut, () => _pickDate(isDepart: false)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('عدد البالغين: ', style: TextStyle(fontFamily: 'Cairo')),
              const Spacer(),
              IconButton(onPressed: _adults > 1 ? () => setState(() => _adults--) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$_adults', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              IconButton(onPressed: () => setState(() => _adults++), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _searching ? null : _search,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _searching
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('بحث', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black, fontSize: 15),
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      tileColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      trailing: Text(_fmt(date), style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: date != null ? AppColors.primary : Colors.grey)),
      onTap: onTap,
    );
  }
}
