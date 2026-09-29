import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api/auth_api.dart';

class LoginController extends ChangeNotifier {
  final WordPressAuthService authService =
      WordPressAuthService();

  bool isLoading = false;
  String? errorMessage;

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await authService.login(
        username: username,
        password: password,
      );

      final token = result['token']?.toString().trim();

      if (token == null || token.isEmpty) {
        throw Exception(
          'توکن از سرور دریافت نشد.',
        );
      }

      debugPrint('============================');
      debugPrint('WORDPRESS LOGIN SUCCESS');
      debugPrint('TOKEN RECEIVED');
      debugPrint('Token Length: ${token.length}');
      debugPrint('============================');

      final prefs =
          await SharedPreferences.getInstance();

      /*
       * مهم:
       * هر دو کلید ذخیره می‌شوند تا تمام APIهای پروژه
       * با یکدیگر سازگار باشند.
       */
      await prefs.setString(
        'jwt_token',
        token,
      );

      await prefs.setString(
        'token',
        token,
      );

      /*
       * ایمیل
       */
      await prefs.setString(
        'user_email',
        result['user_email']?.toString() ?? '',
      );

      /*
       * نام فروشنده
       */
      await prefs.setString(
        'user_name',
        result['user_display_name']?.toString() ?? '',
      );

      /*
       * Vendor ID
       */
      final vendorId =
          result['vendor_id'];

      if (vendorId == null) {
        throw Exception(
          'شناسه فروشنده از WordPress دریافت نشد.',
        );
      }

      final vendorIdInt =
          int.tryParse(
        vendorId.toString(),
      );

      if (vendorIdInt == null) {
        throw Exception(
          'شناسه فروشنده معتبر نیست.',
        );
      }

      await prefs.setInt(
        'vendor_id',
        vendorIdInt,
      );

      /*
       * بررسی نهایی
       */
      final savedToken =
          prefs.getString('jwt_token');

      final savedTokenCompat =
          prefs.getString('token');

      final savedVendorId =
          prefs.getInt('vendor_id');

      if (savedToken == null ||
          savedToken.isEmpty) {
        throw Exception(
          'توکن دریافت شد اما در حافظه ذخیره نشد.',
        );
      }

      if (savedTokenCompat == null ||
          savedTokenCompat.isEmpty) {
        throw Exception(
          'توکن سازگاری ذخیره نشد.',
        );
      }

      if (savedVendorId == null) {
        throw Exception(
          'شناسه فروشنده ذخیره نشد.',
        );
      }

      debugPrint('============================');
      debugPrint('LOGIN DATA SAVED');
      debugPrint(
        'Email: ${result['user_email']}',
      );
      debugPrint(
        'Name: ${result['user_display_name']}',
      );
      debugPrint(
        'Vendor ID: $savedVendorId',
      );
      debugPrint(
        'JWT Token Saved: YES',
      );
      debugPrint(
        'Token Saved: YES',
        
      );
      

      debugPrint('============================');

      return true;
    } catch (error) {
      errorMessage =
          error.toString().replaceFirst(
                'Exception: ',
                '',
              );

      debugPrint('============================');
      debugPrint('LOGIN ERROR');
      debugPrint('$error');
      debugPrint('============================');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}