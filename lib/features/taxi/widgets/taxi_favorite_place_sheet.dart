import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/taxi_favorite_place.dart';
import '../services/taxi_places_service.dart';

/// حوار إضافة/تعديل مكان مفضل.
Future<TaxiFavoritePlace?> showTaxiFavoritePlaceSheet(
  BuildContext context, {
  TaxiFavoritePlace? existing,
  String? presetLabel,
}) {
  return showModalBottomSheet<TaxiFavoritePlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _TaxiFavoritePlaceSheet(
      existing: existing,
      presetLabel: presetLabel,
    ),
  );
}

class _TaxiFavoritePlaceSheet extends StatefulWidget {
  final TaxiFavoritePlace? existing;
  final String? presetLabel;

  const _TaxiFavoritePlaceSheet({this.existing, this.presetLabel});

  @override
  State<_TaxiFavoritePlaceSheet> createState() => _TaxiFavoritePlaceSheetState();
}

class _TaxiFavoritePlaceSheetState extends State<_TaxiFavoritePlaceSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;
  LatLng? _coord;
  List<TaxiPlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _isSaving = false;

  static const _presetLabels = ['المنزل', 'العمل', 'الجامعة', 'أخرى'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final initialLabel = existing?.label ?? widget.presetLabel ?? 'المنزل';
    _labelController = TextEditingController(text: initialLabel);
    _addressController = TextEditingController(text: existing?.address ?? '');
    if (existing != null && existing.lat != 0 && existing.lng != 0) {
      _coord = existing.coord;
    }
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = _addressController.text.trim();
      if (query.length < 2) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      final results = await TaxiPlacesService.autocomplete(query, bias: _coord);
      if (!mounted) return;
      setState(() => _suggestions = results);
    });
  }

  Future<void> _selectSuggestion(TaxiPlaceSuggestion suggestion) async {
    LatLng? coord = suggestion.latLng;
    var address = suggestion.displayName;

    if (coord == null &&
        suggestion.googlePlaceId != null &&
        suggestion.googlePlaceId!.isNotEmpty) {
      final details =
          await TaxiPlacesService.placeDetails(suggestion.googlePlaceId!);
      if (details != null) {
        coord = details.latLng;
        address = details.displayName;
      }
    }

    if (!mounted) return;
    _addressController.text = address;
    _coord = coord;
    setState(() => _suggestions = []);
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();
    if (label.isEmpty || address.isEmpty) {
      _showMessage('أدخل اسم المكان والعنوان');
      return;
    }
    if (_coord == null) {
      final results = await TaxiPlacesService.autocomplete(address);
      if (results.isNotEmpty) {
        await _selectSuggestion(results.first);
      }
    }
    final coord = _coord;
    if (coord == null || coord.latitude == 0 || coord.longitude == 0) {
      _showMessage('اختر عنواناً من الاقتراحات أو حدّد موقعاً صالحاً');
      return;
    }

    setState(() => _isSaving = true);
    final place = TaxiFavoritePlace(
      id: widget.existing?.id ?? 'fav-${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      address: address,
      lat: coord.latitude,
      lng: coord.longitude,
      sortOrder: widget.existing?.sortOrder ?? 0,
    );
    if (!mounted) return;
    Navigator.of(context).pop(place);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing == null ? 'إضافة مكان مفضل' : 'تعديل المكان',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetLabels.map((label) {
              final selected = _labelController.text.trim() == label;
              return ChoiceChip(
                label: Text(label, style: const TextStyle(fontFamily: 'Cairo')),
                selected: selected,
                onSelected: (_) {
                  _labelController.text = label;
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'اسم المكان',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              hintText: 'ابحث عن العنوان...',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 20),
                    title: Text(
                      item.displayName,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                    subtitle: item.subtitle == null
                        ? null
                        : Text(
                            item.subtitle!,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                          ),
                    onTap: () => _selectSuggestion(item),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'حفظ المكان',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
