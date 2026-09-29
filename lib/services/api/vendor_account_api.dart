import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VendorAccountApi {
  static const String baseUrl = 'https://torshizstore.com';

  // ============================================================
  // دریافت توکن
  // ============================================================

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('jwt_token');

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token.trim();
  }

  // ============================================================
  // دریافت شناسه فروشنده
  // ============================================================

  Future<int?> _getVendorId() async {
    final prefs = await SharedPreferences.getInstance();

    final vendorId = prefs.getInt('vendor_id');

    if (vendorId != null && vendorId > 0) {
      return vendorId;
    }

    final vendorIdString = prefs.getString('vendor_id');

    if (vendorIdString != null) {
      final parsed = int.tryParse(
        vendorIdString,
      );

      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return null;
  }

  // ============================================================
  // هدرهای API
  // ============================================================

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();

    if (token == null) {
      throw Exception(
        'توکن ورود پیدا نشد. لطفاً از حساب خارج شوید و دوباره وارد شوید.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // پردازش پاسخ API
  // ============================================================

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
  ) async {
    Map<String, dynamic> data = {};

    try {
      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(
          decoded,
        );
      }
    } catch (_) {
      data = {};
    }

    // ----------------------------------------------------------
    // پاسخ موفق
    // ----------------------------------------------------------

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    // ----------------------------------------------------------
    // پیام خطا
    // ----------------------------------------------------------

    String message =
        'خطایی در ارتباط با سرور رخ داد.';

    if (data['message'] != null) {
      message = data['message'].toString();
    }

    if (data['code'] != null) {
      message =
          '$message\nکد خطا: ${data['code']}';
    }

    throw Exception(message);
  }

  // ============================================================
  // دریافت پروفایل فروشنده
  // ============================================================

  Future<Map<String, dynamic>> getVendorProfile() async {
    final headers = await _getHeaders();

    final vendorId = await _getVendorId();

    if (vendorId == null) {
      throw Exception(
        'شناسه فروشنده پیدا نشد. لطفاً یک بار از حساب خارج شوید و دوباره وارد شوید.',
      );
    }

    // ----------------------------------------------------------
    // ابتدا اطلاعات WCFM
    // ----------------------------------------------------------

    final uri = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/store-vendors/$vendorId',
    );

    final response = await http.get(
      uri,
      headers: headers,
    );

    final wcfmData =
        await _handleResponse(response);

    // ----------------------------------------------------------
    // سپس اطلاعات اختصاصی ترشیز
    // ----------------------------------------------------------

    try {
      final customUri = Uri.parse(
        '$baseUrl/wp-json/torshiz/v1/vendor-profile',
      );

      final customResponse =
          await http.get(
        customUri,
        headers: headers,
      );

      if (customResponse.statusCode >= 200 &&
          customResponse.statusCode < 300) {
        final customData =
            await _handleResponse(
          customResponse,
        );

        if (customData.isNotEmpty) {
          wcfmData.addAll(
            customData,
          );
        }
      }
    } catch (_) {
      // اگر API اختصاصی در دسترس نبود،
      // اطلاعات WCFM همچنان برگردانده می‌شود.
    }

    return wcfmData;
  }

  // ============================================================
  // بروزرسانی پروفایل فروشنده
  // ============================================================
  //
  // نکته مهم:
  //
  // category_id و subcategory_id عمداً در این متد
  // برای تغییر ارسال نمی‌شوند.
  //
  // دسته و زیر دسته فروشنده از زمان ثبت نام ذخیره شده
  // و بعد از تایید مدیر قفل هستند.
  //
  // پارامترهای categoryId و subcategoryId را در امضای متد
  // نگه داشته‌ایم تا اگر فایل قدیمی دیگری هنوز آنها را
  // ارسال کرد، باعث خطای کامپایل نشود.
  //
  // اما عمداً آنها را داخل body قرار نمی‌دهیم.
  // ============================================================

  Future<Map<String, dynamic>> updateVendorProfile({
    required String userName,
    required String email,
    required String storeName,
    required String phone,
    required String state,
    required String city,
    required String address,

    // برای سازگاری با کدهای قدیمی نگه داشته شده‌اند.
    // استفاده نمی‌شوند.
    int? categoryId,
    int? subcategoryId,
  }) async {
    final headers = await _getHeaders();

    // ----------------------------------------------------------
    // اطلاعات قابل ویرایش
    // ----------------------------------------------------------

    final Map<String, dynamic> body = {
      'user_name': userName.trim(),
      'email': email.trim(),
      'store_name': storeName.trim(),
      'phone': phone.trim(),
      'state': state.trim(),
      'city': city.trim(),
      'address': address.trim(),
    };

    // ----------------------------------------------------------
    // عمداً این دو مقدار اضافه نمی‌شوند:
    //
    // body['category_id']
    // body['subcategory_id']
    //
    // چون دسته‌بندی و زیر‌دسته‌بندی پس از تایید مدیر قفل هستند.
    // ----------------------------------------------------------

    final uri = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-profile',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(
      response,
    );
  }

  // ============================================================
  // دریافت دسته بندی های فروشنده
  // ============================================================

  Future<Map<String, dynamic>> getVendorCategories() async {
    final headers = await _getHeaders();

    final uri = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-categories',
    );

    final response = await http.get(
      uri,
      headers: headers,
    );

    return _handleResponse(
      response,
    );
  }

  // ============================================================
  // بروزرسانی دسته بندی فروشنده
  // ============================================================
  //
  // این متد برای سازگاری نگه داشته شده است.
  //
  // سرور PHP باید تغییر دسته بندی فروشنده تاییدشده را
  // با پاسخ 403 رد کند.
  //
  // بنابراین حتی اگر جایی از برنامه از این متد استفاده کند،
  // قفل سمت سرور همچنان برقرار است.
  // ============================================================

  Future<Map<String, dynamic>> updateVendorCategories({
    required int categoryId,
    required int subcategoryId,
  }) async {
    final headers = await _getHeaders();

    final Map<String, dynamic> body = {
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
    };

    final uri = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-categories',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(
      response,
    );
  }

  // ============================================================
  // دریافت ساعت کاری فروشنده
  // ============================================================

  Future<Map<String, dynamic>> getVendorBusinessHours() async {
    final headers = await _getHeaders();

    final uri = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-business-hours',
    );

    final response = await http.get(
      uri,
      headers: headers,
    );

    return _handleResponse(
      response,
    );
  }

  // ============================================================
  // بروزرسانی ساعت کاری فروشنده
  // ============================================================

  Future<Map<String, dynamic>> updateVendorBusinessHours({
    required Map<String, dynamic> storeHours,
  }) async {
    final headers = await _getHeaders();

    final Map<String, dynamic> body = {
      'store_hours': storeHours,
    };

    final uri = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-business-hours',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(
      response,
    );
  }

  // ============================================================
  // تغییر رمز عبور
  // ============================================================

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await _getHeaders();

    final Map<String, dynamic> body = {
      'current_password': currentPassword,
      'new_password': newPassword,
      'confirm_password': newPassword,
    };

    final uri = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/change-password',
    );

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(
      response,
    );
  }
}