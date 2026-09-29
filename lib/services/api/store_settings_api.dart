import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StoreSettingsApi {
  static const String baseUrl = 'https://torshizstore.com';

  Future<Map<String, dynamic>> getStoreSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      throw Exception('توکن ورود پیدا نشد');
    }

    // فروشنده‌ای که قبلاً با آن تست کردیم
    const vendorId = 30;

    final url = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/settings/id/$vendorId/',
    );

    print('STORE SETTINGS URL: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('STORE SETTINGS STATUS: ${response.statusCode}');
    print('STORE SETTINGS BODY: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      'خطا در دریافت تنظیمات فروشگاه: '
      '${response.statusCode} - ${response.body}',
    );
  }
}