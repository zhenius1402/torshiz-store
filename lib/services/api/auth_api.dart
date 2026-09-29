import 'dart:convert';
import 'package:http/http.dart' as http;

class WordPressAuthService {
  final String baseUrl = 'https://torshizstore.com';

  // =========================================================
  // LOGIN
  // =========================================================

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/jwt-auth/v1/token',
    );

    print('============================');
    print('شروع LOGIN');
    print('URL: $url');
    print('USERNAME: $username');
    print('============================');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 60),
          );

      print('============================');
      print('پاسخ WordPress دریافت شد');
      print('STATUS CODE: ${response.statusCode}');
      print('BODY: ${response.body}');
      print('============================');

      Map<String, dynamic> responseData;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw Exception(
            'ساختار پاسخ WordPress معتبر نیست.',
          );
        }

        responseData = decoded;
      } catch (e) {
        throw Exception(
          'پاسخ WordPress قابل خواندن نیست:\n${response.body}',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          responseData['message'] ??
              responseData['code'] ??
              'ورود ناموفق بود (${response.statusCode})',
        );
      }

      final token = responseData['token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception(
          'ورود انجام شد اما توکن دریافت نشد.',
        );
      }

      final storeId = responseData['store_id'];

      if (storeId == null) {
        throw Exception(
          'شناسه فروشگاه/فروشنده از WordPress دریافت نشد.',
        );
      }

      final vendorId = int.tryParse(
        storeId.toString(),
      );

      if (vendorId == null) {
        throw Exception(
          'شناسه فروشنده معتبر نیست.',
        );
      }

      print('============================');
      print('LOGIN SUCCESS');
      print('EMAIL: ${responseData['user_email']}');
      print('NAME: ${responseData['user_display_name']}');
      print('STORE NAME: ${responseData['store_name']}');
      print('VENDOR ID: $vendorId');
      print('ROLE: ${responseData['roles']}');
      print('TOKEN LENGTH: ${token.toString().length}');
      print('============================');

      responseData['vendor_id'] = vendorId;

      return responseData;
    } on http.ClientException catch (e) {
      print('HTTP CLIENT ERROR: $e');

      throw Exception(
        'خطا در ارتباط با سرور:\n$e',
      );
    } on FormatException catch (e) {
      print('JSON ERROR: $e');

      throw Exception(
        'پاسخ سرور نامعتبر است.',
      );
    } catch (e) {
      print('LOGIN ERROR: $e');

      throw Exception(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // =========================================================
  // دریافت اطلاعات ثبت نام فروشنده
  //
  // GET:
  // /wp-json/torshiz/v1/vendor-registration-data
  // =========================================================

  Future<Map<String, dynamic>> getVendorRegistrationData() async {
    final url = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-registration-data',
    );

    print('============================');
    print('GET VENDOR REGISTRATION DATA');
    print('URL: $url');
    print('============================');

    try {
      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 60),
          );

      print('STATUS CODE: ${response.statusCode}');
      print('BODY: ${response.body}');

      Map<String, dynamic> responseData;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw Exception(
            'ساختار اطلاعات ثبت‌نام معتبر نیست.',
          );
        }

        responseData = decoded;
      } catch (e) {
        throw Exception(
          'پاسخ اطلاعات ثبت‌نام قابل خواندن نیست.',
        );
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          responseData['message'] ??
              responseData['code'] ??
              'دریافت اطلاعات ثبت‌نام ناموفق بود.',
        );
      }

      return responseData;
    } on http.ClientException catch (e) {
      throw Exception(
        'خطا در ارتباط با سرور:\n$e',
      );
    } on FormatException {
      throw Exception(
        'پاسخ سرور نامعتبر است.',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // =========================================================
  // ثبت نام فروشنده
  //
  // POST:
  // /wp-json/torshiz/v1/vendor-registration
  // =========================================================

  Future<Map<String, dynamic>> registerVendor({
    required String firstName,
    required String lastName,
    required String email,
    required String username,
    required String password,
    required String phone,
    required String storeName,
    required String city,
    required int categoryId,
    required int subcategoryId,
    required String address,
    required String description,
    required String storePhone,
  }) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/torshiz/v1/vendor-registration',
    );

    final requestBody = {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'username': username.trim(),
      'password': password,
      'phone': phone.trim(),
      'store_name': storeName.trim(),
      'city': city.trim(),
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'address': address.trim(),
      'description': description.trim(),
      'store_phone': storePhone.trim(),
    };

    print('============================');
    print('VENDOR REGISTRATION');
    print('URL: $url');
    print('BODY:');
    print(jsonEncode(requestBody));
    print('============================');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 60),
          );

      print('============================');
      print('REGISTRATION RESPONSE');
      print('STATUS CODE: ${response.statusCode}');
      print('BODY: ${response.body}');
      print('============================');

      Map<String, dynamic> responseData;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw Exception(
            'ساختار پاسخ ثبت‌نام معتبر نیست.',
          );
        }

        responseData = decoded;
      } catch (e) {
        throw Exception(
          'پاسخ ثبت‌نام از سرور قابل خواندن نیست.\n'
          '${response.body}',
        );
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        String message =
            responseData['message']?.toString() ??
                responseData['code']?.toString() ??
                'ثبت‌نام ناموفق بود.';

        throw Exception(message);
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ??
              'ثبت‌نام انجام نشد.',
        );
      }

      return responseData;
    } on http.ClientException catch (e) {
      print('REGISTRATION HTTP ERROR: $e');

      throw Exception(
        'خطا در ارتباط با سرور:\n$e',
      );
    } on FormatException catch (e) {
      print('REGISTRATION JSON ERROR: $e');

      throw Exception(
        'پاسخ سرور نامعتبر است.',
      );
    } catch (e) {
      print('REGISTRATION ERROR: $e');

      throw Exception(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }
}