import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorApi {
  static const String baseUrl = 'https://torshizstore.com';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<int?> _getVendorId() async {
    final prefs = await SharedPreferences.getInstance();

    final vendorId = prefs.getInt('vendor_id');

    if (vendorId != null) {
      return vendorId;
    }

    final vendorIdString = prefs.getString('vendor_id');

    if (vendorIdString != null) {
      return int.tryParse(vendorIdString);
    }

    return null;
  }

  /// اطلاعات پروفایل فروشنده را از دو منبع می‌گیرد و ترکیب می‌کند:
  /// ۱) wcfmmp/v1/store-vendors  -> نام فروشگاه، لوگو، وضعیت آنلاین/آفلاین
  /// ۲) torshiz/v1/vendor-profile -> شماره تماس، آدرس، شهر، استان
  ///    (همان جایی که صفحه‌ی ویرایش پروفایل هم در آن ذخیره می‌کند)
  ///
  /// این کار باعث می‌شود بعد از ذخیره‌ی تغییرات در صفحه‌ی ویرایش،
  /// همان مقادیر تازه در صفحه‌ی «حساب من» هم دیده شوند.
  Future<Map<String, dynamic>> getVendorProfile() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('توکن ورود پیدا نشد');
    }

    final vendorId = await _getVendorId();

    if (vendorId == null) {
      throw Exception('شناسه فروشنده پیدا نشد');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };

    /*
    |------------------------------------------------------------------
    | ۱) اطلاعات نمایشی فروشگاه از WCFM
    |------------------------------------------------------------------
    */

    final storeUrl = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/store-vendors/$vendorId',
    );

    print('============================');
    print('VENDOR PROFILE API (store)');
    print('URL: $storeUrl');
    print('VENDOR ID: $vendorId');
    print('============================');

    final storeResponse = await http.get(storeUrl, headers: headers);

    print('STORE API STATUS: ${storeResponse.statusCode}');
    print('STORE API BODY: ${storeResponse.body}');

    if (storeResponse.statusCode == 401) {
      throw Exception('دسترسی غیرمجاز یا توکن منقضی شده است');
    }

    if (storeResponse.statusCode == 404) {
      throw Exception('فروشنده پیدا نشد');
    }

    Map<String, dynamic> storeData = {};

    if (storeResponse.statusCode == 200) {
      final decoded = jsonDecode(storeResponse.body);

      if (decoded is Map<String, dynamic>) {
        storeData = decoded;
      }
    }

    if (storeData.isEmpty) {
      throw Exception(
        'خطا در دریافت اطلاعات فروشنده: ${storeResponse.statusCode}',
      );
    }

    /*
    |------------------------------------------------------------------
    | ۲) اطلاعات تماس/آدرس دقیق از پلاگین اختصاصی torshiz
    |------------------------------------------------------------------
    | اگر این درخواست به هر دلیلی خطا بدهد (مثلاً پلاگین با توکن JWT
    | سازگار نباشد)، خطا را نادیده می‌گیریم تا کل صفحه از کار نیفتد؛
    | فقط مقادیر phone/address/city/state آپدیت نمی‌شوند.
    */

    final contactUrl = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-profile',
    );

    try {
      final contactResponse = await http.get(contactUrl, headers: headers);

      print('CONTACT API STATUS: ${contactResponse.statusCode}');
      print('CONTACT API BODY: ${contactResponse.body}');

      if (contactResponse.statusCode == 200) {
        final decoded = jsonDecode(contactResponse.body);

        if (decoded is Map<String, dynamic>) {
          storeData['phone'] = decoded['phone'] ?? '';
          storeData['store_address'] = decoded['address'] ?? '';
          storeData['store_city'] = decoded['city'] ?? '';
          storeData['store_state'] = decoded['state'] ?? '';

          // اگر عکس/بنر از طریق اپ آپلود شده باشد، همان نسخه تازه
          // را نشان بده؛ در غیر این صورت مقدار قبلی WCFM باقی می‌ماند.
          final logoUrl = decoded['logo_url']?.toString() ?? '';
          if (logoUrl.isNotEmpty) {
            storeData['vendor_shop_logo'] = logoUrl;
          }

          final bannerUrl = decoded['banner_url']?.toString() ?? '';
          if (bannerUrl.isNotEmpty) {
            storeData['vendor_banner'] = bannerUrl;
          }
        }
      }
    } catch (e) {
      print('CONTACT API ERROR (ignored): $e');
    }

    return storeData;
  }

  /// تعداد کل محصولات فروشنده را برمی‌گرداند.
  ///
  /// به‌جای گرفتن کل لیست محصولات (که سنگین است)، فقط یک محصول
  /// می‌خواهیم (per_page=1) و عدد کل را از هدر پجینیشن استاندارد
  /// ووکامرس (X-WP-Total) می‌خوانیم. اگر این هدر برنگردد، به شمارش
  /// طول آرایه‌ی پاسخ برمی‌گردیم.
  Future<int> getVendorProductCount() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('توکن ورود پیدا نشد');
    }

    final vendorId = await _getVendorId();

    if (vendorId == null) {
      throw Exception('شناسه فروشنده پیدا نشد');
    }

    final url = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/products'
      '?vendor_id=$vendorId&per_page=1',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    print('PRODUCT COUNT STATUS: ${response.statusCode}');
    print('PRODUCT COUNT HEADERS: ${response.headers}');

    if (response.statusCode != 200) {
      throw Exception(
        'خطا در دریافت تعداد محصولات: ${response.statusCode}',
      );
    }

    final totalHeader = response.headers['x-wp-total'];

    if (totalHeader != null) {
      final parsed = int.tryParse(totalHeader);
      if (parsed != null) {
        return parsed;
      }
    }

    // بازگشتی: اگر هدر پجینیشن موجود نبود، طول آرایه را می‌شماریم
    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded.length;
    }

    return 0;
  }

  /// آپلود عکس فروشگاه (لوگو). فایل انتخاب‌شده را به صورت
  /// multipart می‌فرستد و URL تصویر تازه را برمی‌گرداند.
  /// از XFile استفاده می‌شود (نه dart:io File) تا هم روی موبایل
  /// و هم روی Flutter Web کار کند.
  Future<String> uploadVendorLogo(XFile imageFile) async {
    return _uploadVendorImage(imageFile, 'vendor-logo', 'logo_url');
  }

  /// آپلود بنر فروشگاه. مشابه uploadVendorLogo عمل می‌کند.
  Future<String> uploadVendorBanner(XFile imageFile) async {
    return _uploadVendorImage(imageFile, 'vendor-banner', 'banner_url');
  }

  Future<String> _uploadVendorImage(
    XFile imageFile,
    String endpoint,
    String responseKey,
  ) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('توکن ورود پیدا نشد');
    }

    final url = Uri.parse('$baseUrl/wp-json/torshiz/v1/$endpoint');

    final bytes = await imageFile.readAsBytes();

    final fileName = imageFile.name.isNotEmpty
        ? imageFile.name
        : 'upload.jpg';

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('UPLOAD ($endpoint) STATUS: ${response.statusCode}');
    print('UPLOAD ($endpoint) BODY: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic> &&
          decoded[responseKey] != null &&
          decoded[responseKey].toString().isNotEmpty) {
        return decoded[responseKey].toString();
      }

      throw Exception('پاسخ آپلود نامعتبر است');
    }

    if (response.statusCode == 401) {
      throw Exception('دسترسی غیرمجاز یا توکن منقضی شده است');
    }

    // سعی می‌کنیم پیام خطای فارسی سرور را نشان دهیم، اگر موجود بود
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] != null) {
        throw Exception(decoded['message'].toString());
      }
    } catch (_) {
      // نادیده گرفتن خطای parse و رفتن به پیام پیش‌فرض زیر
    }

    throw Exception('خطا در آپلود تصویر: ${response.statusCode}');
  }
}
