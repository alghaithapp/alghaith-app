import '../../../core/network/api_client.dart';

/// خدمة Travelpayouts — بحث فنادق وطيران
class TravelApiService {
  TravelApiService._();
  static final TravelApiService instance = TravelApiService._();

  // ── Flight Search ─────────────────────────────────────────────
  /// origin, destination: رموز المطارات (BGW, IST, DXB...)
  /// departDate, returnDate: YYYY-MM-DD
  Future<List<Map<String, dynamic>>> searchFlights({
    required String origin,
    required String destination,
    required String departDate,
    String? returnDate,
    int passengers = 1,
  }) async {
    final params = <String, String>{
      'origin': origin.toUpperCase().trim(),
      'destination': destination.toUpperCase().trim(),
      'departDate': departDate,
      if (returnDate != null && returnDate.isNotEmpty) 'returnDate': returnDate,
      'passengers': passengers.toString(),
    };
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final result = await ApiClient.instance.get('/api/travel/flights/search?$qs');
    if (result is Map && result['data'] is List) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    return [];
  }

  // ── Hotel Search ──────────────────────────────────────────────
  Future<String?> searchHotels({
    required String query,
    required String checkIn,
    required String checkOut,
    int adults = 1,
  }) async {
    final params = <String, String>{
      'query': query.trim(),
      'checkIn': checkIn,
      'checkOut': checkOut,
      'adults': adults.toString(),
    };
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final result = await ApiClient.instance.get('/api/travel/hotels/search?$qs');
    if (result is Map && result['searchId'] is String) {
      return result['searchId'] as String;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getHotelResults(String searchId) async {
    final result = await ApiClient.instance.get('/api/travel/hotels/results/$searchId');
    if (result is Map && result['result'] is List) {
      return List<Map<String, dynamic>>.from(result['result']);
    }
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }

  // ── Affiliate URL ─────────────────────────────────────────────
  Future<String?> getAffiliateUrl(String type, Map<String, String> params) async {
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final result = await ApiClient.instance.get('/api/travel/affiliate-url?type=$type&$qs');
    if (result is Map && result['url'] is String) {
      return result['url'] as String;
    }
    return null;
  }
}
