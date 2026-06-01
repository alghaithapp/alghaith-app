import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import 'image_storage_service.dart';
import 'dart:io';

class SupabaseService {
  static const Duration _backendTimeout = Duration(seconds: 15);
  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gyayjuhrjvxhjjinerdx.supabase.co/rest/v1/',
  );
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5YXlqdWhyanZ4aGpqaW5lcmR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxMjkyMzAsImV4cCI6MjA5NTcwNTIzMH0.WPPJUR1OtqNCCcQNoejsy2Vh_vqWsK0yvr44WaRERPM',
  );

  static bool get isConfigured => _url.isNotEmpty && _anonKey.isNotEmpty;
  static bool _initialized = false;
  static String? _sessionToken;

  static void _assertProductionBackendConfigured() {
    if (kReleaseMode && !_useBackend) {
      throw StateError(
        'DATABASE_BACKEND_BASE_URL is required in release builds to keep Supabase protected behind the backend.',
      );
    }
  }

  static String get _databaseBackendBaseUrl {
    const compiledBaseUrl =
        String.fromEnvironment('DATABASE_BACKEND_BASE_URL', defaultValue: '');
    return compiledBaseUrl;
  }

  static bool get _useBackend => _databaseBackendBaseUrl.trim().isNotEmpty;

  static String get _projectUrl {
    var normalized = _url.trim();
    if (normalized.endsWith('/rest/v1/')) {
      normalized = normalized.substring(0, normalized.length - '/rest/v1/'.length);
    } else if (normalized.endsWith('/rest/v1')) {
      normalized = normalized.substring(0, normalized.length - '/rest/v1'.length);
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static Future<void> initialize() async {
    _assertProductionBackendConfigured();
    if (!isConfigured || _initialized) return;
    await Supabase.initialize(url: _projectUrl, anonKey: _anonKey);
    _initialized = true;
  }

  static SupabaseClient? get client {
    if (!isConfigured) return null;
    return Supabase.instance.client;
  }

  static void setSessionToken(String? token) {
    final normalized = token?.trim();
    _sessionToken = normalized == null || normalized.isEmpty ? null : normalized;
  }

  static Future<dynamic> _backendRequest(String method, String path, {Map<String, String>? queryParameters, Object? body}) async {
    final baseUrl = _databaseBackendBaseUrl.trim();
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
    late http.Response response;
    final headers = {'Content-Type': 'application/json'};
    final token = _sessionToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    if (method == 'GET') {
      response = await http.get(uri, headers: headers).timeout(_backendTimeout);
    } else if (method == 'PUT') {
      response = await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(_backendTimeout);
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: headers).timeout(_backendTimeout);
    } else {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_backendTimeout);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    var message = 'Backend error: ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        final backendMessage = (decoded['message'] as String).trim();
        if (backendMessage.isNotEmpty) {
          message = backendMessage;
        }
      }
    } catch (_) {}
    throw Exception(message);
  }

  static List<String> _getPhoneVariants(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return [phone];
    final core = digits.substring(digits.length - 10);
    return ['+964$core', '964$core', '0$core', core];
  }

  static String _normalizePhoneForStorage(String phone) {
    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('0') && digits.length >= 11) {
      return '+964${digits.substring(1)}';
    }
    if (digits.startsWith('964')) {
      return '+$digits';
    }
    if (digits.length == 10 && digits.startsWith('7')) {
      return '+964$digits';
    }
    return phone.trim().startsWith('+') ? phone.trim() : '+$digits';
  }

  static Future<Map<String, dynamic>?> loadAppUser(String phone) async {
    if (_useBackend) return await _backendRequest('GET', '/db/app-user', queryParameters: {'phone': phone});
    final supabase = client;
    if (supabase == null) return null;
    final response = await supabase.from('app_users').select().inFilter('phone', _getPhoneVariants(phone)).order('updated_at', ascending: false).limit(1);
    return (response is List && response.isNotEmpty) ? Map<String, dynamic>.from(response.first) : null;
  }

  static Future<Map<String, dynamic>?> loadMerchantProfile(String phone) async {
    if (_useBackend) return await _backendRequest('GET', '/db/merchant-profile', queryParameters: {'phone': phone});
    final supabase = client;
    if (supabase == null) return null;
    final response = await supabase.from('merchant_profiles').select().inFilter('phone', _getPhoneVariants(phone)).limit(1);
    return (response is List && response.isNotEmpty) ? Map<String, dynamic>.from(response.first) : null;
  }

  static Future<List<Map<String, dynamic>>> loadMerchantProducts(String phone) async {
    if (_useBackend) {
      final res = await _backendRequest('GET', '/db/merchant-products', queryParameters: {'phone': phone});
      return res is List ? res.cast<Map<String, dynamic>>() : [];
    }
    final supabase = client;
    if (supabase == null) return [];
    final response = await supabase.from('merchant_products').select().inFilter('phone', _getPhoneVariants(phone));
    return response.whereType<Map>().map((i) => Map<String, dynamic>.from(i)).toList();
  }

  static Future<Map<String, dynamic>?> loadUserState(String phone) async {
    if (_useBackend) return await _backendRequest('GET', '/db/user-state', queryParameters: {'phone': phone});
    final supabase = client;
    if (supabase == null) return null;
    final response = await supabase.from('app_state').select('state').inFilter('phone', _getPhoneVariants(phone)).limit(1);
    if (response is List && response.isNotEmpty && response.first['state'] is Map) return Map<String, dynamic>.from(response.first['state']);
    return null;
  }

  static Future<List<Map<String, dynamic>>> loadProfessionalProfiles({String? professionId}) async {
    if (_useBackend) {
      final res = await _backendRequest('GET', '/db/professionals', queryParameters: {if (professionId != null) 'professionId': professionId});
      return res is List ? res.cast<Map<String, dynamic>>() : [];
    }
    final supabase = client;
    if (supabase == null) return [];
    var query = supabase.from('merchant_profiles').select();
    final response = await query;
    return response.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).where((row) {
      final serviceIds = row['service_ids'];
      final hasProfessionals = serviceIds is List && serviceIds.map((i) => i.toString()).contains('professionals');
      if (!hasProfessionals) return false;
      if (professionId == null || professionId.trim().isEmpty) return true;
      return row['professional_category_id']?.toString().trim() == professionId.trim();
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> loadShoppingStores({String? subCategoryId}) async {
    if (_useBackend) {
      final res = await _backendRequest('GET', '/db/shopping-stores', queryParameters: {if (subCategoryId != null) 'subCategoryId': subCategoryId});
      return res is List ? res.cast<Map<String, dynamic>>() : [];
    }
    final supabase = client;
    if (supabase == null) return [];
    final profiles = await supabase.from('merchant_profiles').select();
    final stores = <Map<String, dynamic>>[];
    for (final profile in profiles) {
      final phone = profile['phone']?.toString().trim();
      if (phone == null || phone.isEmpty) continue;
      final products = await loadMerchantProducts(phone);
      final filtered = products.where((p) => subCategoryId == null || p['sub_category'] == subCategoryId).toList();
      if (filtered.isNotEmpty) stores.add({'profile': profile, 'products': filtered});
    }
    return stores;
  }

  static Future<List<Map<String, dynamic>>> loadRealEstateListings({String? subCategoryId}) async {
    if (_useBackend) {
      final res = await _backendRequest('GET', '/db/real-estate-listings', queryParameters: {if (subCategoryId != null) 'subCategoryId': subCategoryId});
      return res is List ? res.cast<Map<String, dynamic>>() : [];
    }
    final supabase = client;
    if (supabase == null) return [];
    final products = await supabase.from('merchant_products').select().eq('category', 'real_estate');
    final result = <Map<String, dynamic>>[];
    for (final product in products) {
      final phone = product['phone']?.toString();
      final merchant = phone != null ? await loadMerchantProfile(phone) : null;
      if (subCategoryId == null || product['sub_category'] == subCategoryId) {
        result.add({'product': product, 'merchant': merchant});
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>?> loadCustomerProfile(String phone) async {
    if (_useBackend) return await _backendRequest('GET', '/db/customer-profile', queryParameters: {'phone': phone});
    final supabase = client;
    if (supabase == null) return null;
    final response = await supabase.from('customer_profiles').select().inFilter('phone', _getPhoneVariants(phone)).limit(1);
    return (response is List && response.isNotEmpty) ? Map<String, dynamic>.from(response.first) : null;
  }

  static Future<List<String>> loadCustomerAddresses(String phone) async {
    if (_useBackend) {
      final res = await _backendRequest('GET', '/db/customer-addresses', queryParameters: {'phone': phone});
      return res is List ? res.map((i) => i['address_text'].toString()).toList() : [];
    }
    final supabase = client;
    if (supabase == null) return [];
    final response = await supabase.from('customer_addresses').select('address_text').inFilter('phone', _getPhoneVariants(phone));
    return response.map((i) => i['address_text'].toString()).toList();
  }

  static Future<List<String>> loadCustomerFavoriteIds(String phone) async {
    if (_useBackend) {
      final res = await _backendRequest('GET', '/db/customer-favorites', queryParameters: {'phone': phone});
      return res is List ? res.map((i) => i['product_id'].toString()).toList() : [];
    }
    final supabase = client;
    if (supabase == null) return [];
    final response = await supabase.from('customer_favorites').select('product_id').inFilter('phone', _getPhoneVariants(phone));
    return response.map((i) => i['product_id'].toString()).toList();
  }

  static Future<List<ActiveOrder>> loadCustomerOrders(String phone) async {
    if (_useBackend) {
      final res = await _backendRequest('GET', '/db/customer-orders', queryParameters: {'phone': phone});
      return res is List ? res.map((i) => ActiveOrder.fromMap(Map<String, dynamic>.from(i['order_payload']))).toList() : [];
    }
    final supabase = client;
    if (supabase == null) return [];
    final response = await supabase.from('customer_orders').select('order_payload').inFilter('phone', _getPhoneVariants(phone));
    return response.map((i) => ActiveOrder.fromMap(Map<String, dynamic>.from(i['order_payload']))).toList();
  }

  static Future<void> saveAppUser(
    String phone, {
    String? fullName,
    String? role,
    String? avatarBase64,
  }) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/app-user', body: {
        'phone': phone,
        if (fullName != null) 'full_name': fullName,
        if (role != null) 'role': role,
        ...ImageStorageService.customerAvatarFields(avatarBase64),
      });
      return;
    }
    final supabase = client;
    if (supabase == null || phone.trim().isEmpty) return;
    
    try {
      final cleanPhone = _normalizePhoneForStorage(phone);
      if (cleanPhone.isEmpty) return;
      await supabase.from('app_users').upsert({
        'phone': cleanPhone,
        if (fullName != null) 'full_name': fullName.trim(),
        if (role != null) 'role': role.trim(),
        ...ImageStorageService.customerAvatarFields(avatarBase64),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'phone');
      debugPrint('DB_SUCCESS: AppUser saved for $cleanPhone');
    } catch (e) {
      debugPrint('DB_ERROR: Failed to save AppUser: $e');
    }
  }

  static Future<void> saveMerchantProfile(String phone, Map<String, dynamic> profile) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/merchant-profile', body: {'phone': phone, ...profile});
      return;
    }
    final supabase = client;
    if (supabase == null) return;
    
    final cleanPhone = _normalizePhoneForStorage(phone);
    if (cleanPhone.isEmpty) return;
    final profileImage = profile['profile_image_base64'] ??
        profile['profileImageBase64'];
    final coverImage = profile['cover_image_url'] ??
        profile['coverImageUrl'] ??
        profile['coverImageBase64'] ??
        profile['coverImage'];
    final logoImage = profile['logo_image_url'] ??
        profile['logoImageUrl'] ??
        profile['logoImageBase64'] ??
        profile['logoImage'];
    final workSamples = profile['work_sample_images_base64'] ??
        profile['workSampleImagesBase64'];

    await supabase.from('merchant_profiles').upsert({
      'phone': cleanPhone,
      'store_name': profile['store_name'],
      'description': profile['description'],
      'primary_service_id': profile['primary_service_id'],
      'whatsapp': profile['whatsapp'],
      'address': profile['address'],
      'open_time': profile['open_time'],
      'close_time': profile['close_time'],
      'delivery_areas': profile['delivery_areas'],
      'delivery_fee': profile['delivery_fee'],
      'is_open': profile['is_open'] ?? true,
      if (profileImage != null) 'profile_image_base64': profileImage,
      if (coverImage != null) 'cover_image_url': coverImage,
      if (logoImage != null) 'logo_image_url': logoImage,
      if (workSamples != null) 'work_sample_images_base64': workSamples,
      'service_ids': profile['service_ids'],
      'active_service_id': profile['active_service_id'],
      'professional_category_id': profile['professional_category_id'],
      'professional_info': profile['professional_info'],
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveMerchantProduct(String phone, Map<String, dynamic> product) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/merchant-product', body: {'phone': phone, ...product});
      return;
    }
    final supabase = client;
    if (supabase == null) return;
    
    final cleanPhone = _normalizePhoneForStorage(phone);
    if (cleanPhone.isEmpty) return;
    final imageRef = product['image_base64']?.toString() ??
        product['image']?.toString();
    final imageFields = ImageStorageService.productImageFields(
      imageRef,
      fallbackAsset: product['image']?.toString(),
    );

    await supabase.from('merchant_products').upsert({
      'id': product['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'phone': cleanPhone,
      'name_ar': product['name_ar'],
      'name_en': product['name_en'] ?? product['name_ar'],
      'description_ar': product['description_ar'],
      'description_en': product['description_en'] ?? product['description_ar'],
      'price': product['price'],
      'category': product['category'],
      'sub_category': product['sub_category'],
      ...imageFields,
      'is_available': product['is_available'] ?? true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveUserState(String phone, Map<String, dynamic> state) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/user-state', body: {'phone': phone, 'state': state});
      return;
    }
    final supabase = client;
    if (supabase == null) return;
    final cleanPhone = _normalizePhoneForStorage(phone);
    if (cleanPhone.isEmpty) return;
    await supabase.from('app_state').upsert({
      'phone': cleanPhone,
      'state': state,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> saveCustomerProfile(String phone, Map<String, dynamic> profile) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/customer-profile', body: {
        'phone': phone,
        ...profile,
      });
      return;
    }
    final supabase = client;
    if (supabase == null || phone.trim().isEmpty) return;
    
    try {
      final cleanPhone = _normalizePhoneForStorage(phone);
      if (cleanPhone.isEmpty) return;
      final avatar = profile['avatar_base64'] ?? profile['avatarBase64'];
      await supabase.from('customer_profiles').upsert({
        'phone': cleanPhone,
        'display_name': profile['display_name'],
        if (avatar != null) 'avatar_base64': avatar,
        'address': profile['address'],
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'phone'); 
      debugPrint('DB_SUCCESS: Customer Profile saved for $cleanPhone');
    } catch (e) {
      debugPrint('DB_ERROR: Failed to save CustomerProfile: $e');
    }
  }

  static Future<void> saveCustomerAddress(String phone, String address, {int sortOrder = 0}) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/customer-address', body: {
        'phone': phone,
        'address': address,
        'sort_order': sortOrder,
      });
      return;
    }
    final supabase = client;
    if (supabase == null || phone.trim().isEmpty) return;
    
    try {
      final cleanPhone = _normalizePhoneForStorage(phone);
      final cleanAddress = address.trim();
      if (cleanPhone.isEmpty || cleanAddress.isEmpty) return;

      await supabase.from('customer_addresses').upsert({
        'phone': cleanPhone,
        'address_text': cleanAddress,
        'sort_order': sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'phone,address_text'); 
      debugPrint('DB_SUCCESS: Address saved for $cleanPhone');
    } catch (e) {
      debugPrint('DB_ERROR: Failed to save address: $e');
    }
  }

  static Future<void> deleteCustomerAddress(String phone, String address) async {
    if (_useBackend) {
      await _backendRequest('DELETE', '/db/customer-address', queryParameters: {'phone': phone, 'address': address});
      return;
    }
    final supabase = client;
    if (supabase == null) return;
    await supabase
        .from('customer_addresses')
        .delete()
        .inFilter('phone', _getPhoneVariants(phone))
        .eq('address_text', address.trim());
  }

  static Future<void> saveCustomerFavorite(String phone, String productId, {required bool isFavorite}) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/customer-favorite', body: {'phone': phone, 'productId': productId, 'isFavorite': isFavorite});
      return;
    }
    final supabase = client;
    if (supabase == null) return;
    final normalizedPhone = phone.trim();
    if (!isFavorite) {
      await supabase
          .from('customer_favorites')
          .delete()
          .inFilter('phone', _getPhoneVariants(normalizedPhone))
          .eq('product_id', productId);
    } else {
      await supabase.from('customer_favorites').upsert({
        'phone': _normalizePhoneForStorage(normalizedPhone),
        'product_id': productId,
      });
    }
  }

  static Future<void> saveCustomerOrder(String phone, ActiveOrder order) async {
    if (_useBackend) {
      await _backendRequest('PUT', '/db/customer-order', body: {'phone': phone, 'order': order.toMap()});
      return;
    }
    final supabase = client;
    if (supabase == null) return;
    final cleanPhone = _normalizePhoneForStorage(phone);
    if (cleanPhone.isEmpty) return;
    await supabase.from('customer_orders').upsert({
      'id': order.id,
      'phone': cleanPhone,
      'order_number': order.orderNumber,
      'status_key': order.statusKey,
      'delivery_status_key': order.deliveryStatusKey,
      'order_payload': order.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  static Future<void> deleteMerchantProduct(String productId, {String? phone}) async {
    if (_useBackend) {
      await _backendRequest('DELETE', '/db/merchant-product', queryParameters: {
        'id': productId,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      });
      return;
    }
    final supabase = client;
    if (supabase == null) return;
    await supabase.from('merchant_products').delete().eq('id', productId);
  }

  static Future<String?> uploadImage(String bucket, String path, dynamic file) async {
    final supabase = client;
    if (supabase == null) return null;

    try {
      final segment = path.split('/').where((part) => part.isNotEmpty).toList();
      final folder = segment.isNotEmpty ? segment.first : 'media';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${segment.length > 1 ? segment.last : 'image.jpg'}';
      final filePath = '$folder/$fileName';

      if (file is File) {
        await supabase.storage.from(bucket).upload(
              filePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
      } else if (file is Uint8List) {
        await supabase.storage.from(bucket).uploadBinary(
              filePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
      } else {
        return null;
      }

      return supabase.storage.from(bucket).getPublicUrl(filePath);
    } catch (e) {
      debugPrint('SUPABASE_STORAGE_ERROR: $e');
      return null;
    }
  }
}
