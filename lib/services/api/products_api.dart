 import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProductsApi {
  static const String baseUrl = 'https://torshizstore.com';

  // =========================================================
  // دریافت توکن
  // =========================================================

  Future<String?> _getToken() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    return prefs.getString('jwt_token');
  }

  // =========================================================
  // Header
  // =========================================================

  Future<Map<String, String>> _headers() async {
    final String? token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'توکن ورود پیدا نشد. لطفاً دوباره وارد شوید.',
      );
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
  }

  // =========================================================
  // دریافت محصولات فروشنده
  // =========================================================

  Future<List<dynamic>> getProducts() async {
    final Map<String, String> headers = await _headers();

    final int timestamp =
        DateTime.now().millisecondsSinceEpoch;

    final Uri url = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/products?per_page=100&page=1&_ts=$timestamp',
    );

    print('====================================');
    print('GET PRODUCTS');
    print('GET PRODUCTS URL: $url');
    print('GET PRODUCTS REQUEST STARTED');
    print('====================================');

    final http.Response response = await http.get(
      url,
      headers: headers,
    );

    print('====================================');
    print('GET PRODUCTS STATUS: ${response.statusCode}');
    print('GET PRODUCTS RESPONSE: ${response.body}');
    print('====================================');

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);

      if (data is List) {
        print(
          'GET PRODUCTS COUNT: ${data.length}',
        );

        return data;
      }

      if (data is Map<String, dynamic>) {
        final dynamic products = data['products'];

        if (products is List) {
          print(
            'GET PRODUCTS COUNT: ${products.length}',
          );

          return products;
        }
      }

      print('GET PRODUCTS: EMPTY RESPONSE');

      return [];
    }

    throw Exception(
      'خطا در دریافت محصولات:\n'
      '${response.statusCode}\n'
      '${response.body}',
    );
  }

  // =========================================================
  // دریافت دسته‌بندی‌ها
  // =========================================================

  Future<List<dynamic>> getCategories() async {
    final String? token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'توکن ورود پیدا نشد. لطفاً دوباره وارد شوید.',
      );
    }

    final Uri url = Uri.parse(
      '$baseUrl/wp-json/wp/v2/product_cat?per_page=100',
    );

    final http.Response response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    print('====================================');
    print('GET CATEGORIES');
    print('GET CATEGORIES URL: $url');
    print(
      'GET CATEGORIES STATUS: ${response.statusCode}',
    );
    print(
      'GET CATEGORIES RESPONSE: ${response.body}',
    );
    print('====================================');

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);

      if (data is List) {
        return data;
      }

      return [];
    }

    throw Exception(
      'خطا در دریافت دسته‌بندی‌ها:\n'
      '${response.statusCode}\n'
      '${response.body}',
    );
  }
 // =========================================================
  // آپلود تصویر محصول
  // =========================================================

  Future<int> uploadProductImage({
    required Uint8List imageBytes,
    required String fileName,
    required String mimeType,
  }) async {
    final String? token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'توکن ورود پیدا نشد. لطفاً دوباره وارد شوید.',
      );
    }

    final Uri url = Uri.parse(
      '$baseUrl/wp-json/wp/v2/media',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      url,
    );

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ),
    );

    final http.StreamedResponse response =
        await request.send();

    final String responseBody =
        await response.stream.bytesToString();

    print('====================================');
    print('UPLOAD PRODUCT IMAGE');
    print('UPLOAD IMAGE URL: $url');
    print(
      'UPLOAD IMAGE STATUS: ${response.statusCode}',
    );
    print(
      'UPLOAD IMAGE RESPONSE: $responseBody',
    );
    print('====================================');

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      final dynamic data = jsonDecode(responseBody);

      final dynamic imageId = data['id'];

      if (imageId is int) {
        return imageId;
      }

      throw Exception(
        'تصویر آپلود شد اما شناسه تصویر دریافت نشد.',
      );
    }

    throw Exception(
      'خطا در آپلود تصویر:\n'
      'Status: ${response.statusCode}\n'
      '$responseBody',
    );
  }

  // =========================================================
  // ثبت محصول جدید
  // =========================================================

  Future<Map<String, dynamic>> createProduct({
    required String name,
    required String description,
    required double regularPrice,
    double? salePrice,
    required int stockQuantity,
    required int categoryId,
    required int imageId,
    required bool virtualProduct,
    required bool downloadableProduct,
  }) async {
    final Map<String, String> headers = await _headers();

    final Uri url = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/products',
    );

    final Map<String, dynamic> body = {
      'name': name,
      'type': 'simple',
      'description': description,
      'short_description': description,
      'regular_price': regularPrice.toString(),
      'stock_quantity': stockQuantity,
      'manage_stock': true,
      'in_stock': stockQuantity > 0,
      'status': 'publish',
      'virtual': virtualProduct,
      'downloadable': downloadableProduct,

      // دسته‌بندی محصول جدید
      'categories': [
        {
          'id': categoryId,
        },
      ],

      // تصویر شاخص
      'featured_image': {
        'id': imageId,
      },
    };

    if (salePrice != null) {
      body['sale_price'] = salePrice.toString();
    }

    print('====================================');
    print('CREATE PRODUCT');
    print('CREATE PRODUCT URL: $url');
    print('CREATE PRODUCT BODY');
    print(jsonEncode(body));
    print('====================================');

    final http.Response response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    print(
      'CREATE PRODUCT STATUS: ${response.statusCode}',
    );

    print(
      'CREATE PRODUCT RESPONSE: ${response.body}',
    );

    print('====================================');

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      final dynamic data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        return data;
      }

      return {
        'success': true,
      };
    }

    throw Exception(
      'خطا در ثبت محصول:\n'
      'Status: ${response.statusCode}\n'
      '${response.body}',
    );
  }
 // =========================================================
  // حذف محصول
  // =========================================================

  Future<void> deleteProduct({
    required int productId,
  }) async {
    final Map<String, String> headers = await _headers();

    final Uri url = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/products/$productId',
    );

    print('====================================');
    print('DELETE PRODUCT');
    print('PRODUCT ID: $productId');
    print('DELETE URL: $url');
    print('====================================');

    final http.Response response = await http.delete(
      url,
      headers: headers,
    );

    print(
      'DELETE PRODUCT STATUS: ${response.statusCode}',
    );

    print(
      'DELETE PRODUCT RESPONSE: ${response.body}',
    );

    print('====================================');

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 204) {
      return;
    }

    throw Exception(
      'خطا در حذف محصول:\n'
      'Status: ${response.statusCode}\n'
      '${response.body}',
    );
  }

  // =========================================================
  // ویرایش محصول
  // =========================================================

  Future<Map<String, dynamic>> updateProduct({
    required int productId,
    required String name,
    required String description,
    required double regularPrice,
    double? salePrice,
    required int stockQuantity,
    required int categoryId,
    int? imageId,
    required bool virtualProduct,
    required bool downloadableProduct,
  }) async {
    final Map<String, String> headers = await _headers();

    final Uri url = Uri.parse(
      '$baseUrl/wp-json/wcfmmp/v1/products/$productId',
    );

    final Map<String, dynamic> body = {
      'name': name,
      'type': 'simple',
      'description': description,
      'short_description': description,
      'regular_price': regularPrice.toString(),
      'stock_quantity': stockQuantity,
      'manage_stock': true,
      'in_stock': stockQuantity > 0,
      'status': 'publish',
      'virtual': virtualProduct,
      'downloadable': downloadableProduct,

      // دسته‌بندی به روش استاندارد ووکامرس
      'categories': [
        {
          'id': categoryId,
        },
      ],

      // ارسال مستقیم دسته‌بندی برای کد سفارشی وردپرس
      'category_id': categoryId,
    };

    // قیمت ویژه
    if (salePrice != null) {
      body['sale_price'] = salePrice.toString();
    } else {
      body['sale_price'] = '';
    }

    // تصویر جدید
    if (imageId != null) {
      body['featured_image'] = {
        'id': imageId,
      };
    }

    print('====================================');
    print('UPDATE PRODUCT');
    print('PRODUCT ID: $productId');
    print('CATEGORY ID SENT: $categoryId');
    print('UPDATE PRODUCT URL: $url');
    print('UPDATE PRODUCT BODY');
    print(jsonEncode(body));
    print('====================================');

    final http.Response response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    print(
      'UPDATE PRODUCT STATUS: ${response.statusCode}',
    );

    print(
      'UPDATE PRODUCT RESPONSE: ${response.body}',
    );

    print('====================================');

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      final dynamic data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        return data;
      }

      return {
        'success': true,
      };
    }

    throw Exception(
      'خطا در ویرایش محصول:\n'
      'Status: ${response.statusCode}\n'
      '${response.body}',
    );
  }
}