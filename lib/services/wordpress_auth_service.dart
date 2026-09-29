import 'dart:convert';
import 'package:http/http.dart' as http;

class WordPressAuthService {
  static const String baseUrl = 'https://torshizstore.com';

  static Future<void> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/jwt-auth/v1/token',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('==============================');
      print('JWT LOGIN');
      print('URL: $url');
      print('STATUS: ${response.statusCode}');
      print('RESPONSE: ${response.body}');
      print('==============================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['token'] == null) {
          throw Exception('WordPress توکن ارسال نکرد.');
        }

        print('LOGIN SUCCESS');
        print('USER EMAIL: ${data['user_email']}');
        print('USER DISPLAY NAME: ${data['user_display_name']}');
      } else {
        String message = 'خطا در ارتباط با WordPress';

        try {
          final data = jsonDecode(response.body);

          if (data['message'] != null) {
            message = data['message'].toString();
          }
        } catch (_) {
          if (response.body.isNotEmpty) {
            message = response.body;
          }
        }

        throw Exception(
          '$message (HTTP ${response.statusCode})',
        );
      }
    } catch (e) {
      print('JWT ERROR: $e');
      rethrow;
    }
  }
}