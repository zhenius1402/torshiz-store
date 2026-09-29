import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrdersApi {
  static const String baseUrl =
      'https://torshizstore.com';

  // ============================================================
  // Vendor API
  // ============================================================

  static const String vendorOrdersEndpoint =
      '$baseUrl/wp-json/torshiz/v1/vendor-orders';

  static const String updateOrderStatusEndpoint =
      '$baseUrl/wp-json/torshiz/v1/update-order-status';

  // ============================================================
  // Customer API
  // ============================================================

  static const String customerOrdersEndpoint =
      '$baseUrl/wp-json/torshiz/v1/customer-orders';

  // ============================================================
  // Headers
  // ============================================================

  Future<Map<String, String>> _getHeaders() async {
    final prefs =
        await SharedPreferences.getInstance();

    /*
     * اول JWT اصلی
     */
    String? token =
        prefs.getString('jwt_token');

    /*
     * اگر نبود، token قدیمی/سازگاری
     */
    if (token == null ||
        token.trim().isEmpty) {
      token = prefs.getString('token');
    }

    final cookie =
        prefs.getString('cookie');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',

      // جلوگیری از دریافت پاسخ کش‌شده
      'Cache-Control': 'no-cache, no-store, max-age=0',
      'Pragma': 'no-cache',
    };

    if (token != null &&
        token.trim().isNotEmpty) {
      headers['Authorization'] =
          'Bearer ${token.trim()}';
    }

    if (cookie != null &&
        cookie.trim().isNotEmpty) {
      headers['Cookie'] =
          cookie.trim();
    }

    return headers;
  }

  // ============================================================
  // Decode Response
  // ============================================================

  dynamic _decodeResponse(
    http.Response response,
  ) {
    final body =
        response.body.trim();

    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      throw Exception(
        'پاسخ سرور قابل پردازش نیست. '
        'کد وضعیت: ${response.statusCode}',
      );
    }
  }

  // ============================================================
  // Check Response
  // ============================================================

  void _checkResponse(
    http.Response response,
  ) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    dynamic data;

    try {
      data = jsonDecode(
        response.body,
      );
    } catch (_) {
      data = null;
    }

    String message =
        'خطا در ارتباط با سرور.';

    if (data is Map) {
      if (data['message'] != null) {
        message =
            data['message'].toString();
      } else if (data['data'] is Map &&
          data['data']['message'] != null) {
        message =
            data['data']['message'].toString();
      }
    }

    throw Exception(message);
  }

  // ============================================================
  // Convert to Map
  // ============================================================

  Map<String, dynamic> _asMap(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  // ============================================================
  // Extract Orders
  // ============================================================

  List<dynamic> _extractOrders(
    dynamic decoded,
  ) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map) {
      final map =
          _asMap(decoded);

      if (map['orders'] is List) {
        return map['orders']
            as List<dynamic>;
      }

      if (map['data'] is List) {
        return map['data']
            as List<dynamic>;
      }

      if (map['data'] is Map) {
        final dataMap =
            _asMap(
          map['data'],
        );

        if (dataMap['orders']
            is List) {
          return dataMap['orders']
              as List<dynamic>;
        }
      }
    }

    return <dynamic>[];
  }

  // ============================================================
  // Extract Response Map
  // ============================================================

  Map<String, dynamic>
      _extractResponseMap(
    dynamic decoded,
  ) {
    if (decoded is Map) {
      final map =
          _asMap(decoded);

      if (map['orders'] is List) {
        return map;
      }

      if (map['data'] is Map) {
        final dataMap =
            _asMap(
          map['data'],
        );

        if (dataMap['orders']
            is List) {
          return dataMap;
        }
      }

      return map;
    }

    if (decoded is List) {
      return <String, dynamic>{
        'success': true,
        'orders': decoded,
        'count': decoded.length,
      };
    }

    return <String, dynamic>{
      'success': false,
      'orders': <dynamic>[],
      'count': 0,
      'total': 0,
      'total_formatted': '0 تومان',
    };
  }

  // ============================================================
  // ============================================================
  // VENDOR ORDERS
  // ============================================================
  // ============================================================

  Future<List<dynamic>> getVendorOrders({
    String period = 'all',
  }) async {
    final response =
        await getVendorOrdersResponse(
      period: period,
    );

    final orders =
        response['orders'];

    if (orders is List) {
      return orders;
    }

    return <dynamic>[];
  }

  Future<Map<String, dynamic>>
      getVendorOrdersResponse({
    String period = 'all',
  }) async {
    final headers =
        await _getHeaders();

    final uri = Uri.parse(
      vendorOrdersEndpoint,
    ).replace(
      queryParameters: {
        'period': period,

        // جلوگیری از cache
        '_t': DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
      },
    );

    final response =
        await http.get(
      uri,
      headers: headers,
    );

    _checkResponse(response);

    final decoded =
        _decodeResponse(response);

    final result =
        _extractResponseMap(
      decoded,
    );

    /*
     * اگر orders وجود نداشت،
     * دوباره استخراج می‌کنیم.
     */
    if (result['orders'] is! List) {
      result['orders'] =
          _extractOrders(decoded);
    }

    /*
     * count
     */
    if (result['count'] == null) {
      final orders =
          result['orders'];

      result['count'] =
          orders is List
              ? orders.length
              : 0;
    }

    return result;
  }

  Future<Map<String, dynamic>>
      getVendorTransactions({
    String period = 'all',
  }) async {
    return getVendorOrdersResponse(
      period: period,
    );
  }

  // ============================================================
  // Update Vendor Order Status
  // ============================================================

  Future<Map<String, dynamic>>
      updateOrderStatus({
    required int orderId,
    String? status,
    String? newStatus,
  }) async {
    final finalStatus =
        (status ?? newStatus ?? '')
            .trim();

    if (finalStatus.isEmpty) {
      throw Exception(
        'وضعیت سفارش مشخص نشده است.',
      );
    }

    final headers =
        await _getHeaders();

    final response =
        await http.post(
      Uri.parse(
        updateOrderStatusEndpoint,
      ),
      headers: headers,
      body: jsonEncode({
        'order_id': orderId,
        'status': finalStatus,
      }),
    );

    _checkResponse(response);

    final decoded =
        _decodeResponse(response);

    final map =
        _asMap(decoded);

    if (map.isEmpty) {
      throw Exception(
        'پاسخ تغییر وضعیت سفارش خالی است.',
      );
    }

    if (map['success'] == false) {
      String message =
          'تغییر وضعیت انجام نشد.';

      if (map['message'] != null) {
        message =
            map['message'].toString();
      } else if (map['data'] is Map &&
          map['data']['message'] != null) {
        message =
            map['data']['message']
                .toString();
      }

      throw Exception(message);
    }

    return map;
  }

  // ============================================================
  // Update Vendor Status + Refresh
  // ============================================================

  Future<List<dynamic>>
      updateStatusAndRefreshOrders({
    required int orderId,
    required String status,
    String period = 'all',
  }) async {
    await updateOrderStatus(
      orderId: orderId,
      status: status,
    );

    return getVendorOrders(
      period: period,
    );
  }

  // ============================================================
  // Get Vendor Order By ID
  // ============================================================

  Future<Map<String, dynamic>?>
      getVendorOrderById(
    int orderId, {
    String period = 'all',
  }) async {
    final orders =
        await getVendorOrders(
      period: period,
    );

    for (final item in orders) {
      if (item is! Map) {
        continue;
      }

      final order =
          _asMap(item);

      final id =
          order['id'];

      if (id is int &&
          id == orderId) {
        return order;
      }

      if (id is String &&
          int.tryParse(id) == orderId) {
        return order;
      }

      final orderNumber =
          order['order_number'];

      if (orderNumber is String &&
          int.tryParse(
                orderNumber,
              ) ==
              orderId) {
        return order;
      }

      if (orderNumber is int &&
          orderNumber == orderId) {
        return order;
      }
    }

    return null;
  }

  // ============================================================
  // Refresh Vendor Orders
  // ============================================================

  Future<List<dynamic>>
      refreshVendorOrders({
    String period = 'all',
  }) async {
    return getVendorOrders(
      period: period,
    );
  }

  // ============================================================
  // ============================================================
  // CUSTOMER ORDERS
  // ============================================================
  // ============================================================

  /// دریافت تمام سفارش‌های مشتری واردشده
  ///
  /// این متد فقط سفارش‌های کاربر فعلی را
  /// از API مشتری دریافت می‌کند.
  Future<Map<String, dynamic>>
      getCustomerOrders() async {
    final headers =
        await _getHeaders();

    final uri = Uri.parse(
      customerOrdersEndpoint,
    ).replace(
      queryParameters: {
        // جلوگیری از cache شدن پاسخ
        '_t': DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
      },
    );

    final response =
        await http.get(
      uri,
      headers: headers,
    );

    _checkResponse(response);

    final decoded =
        _decodeResponse(response);

    final result =
        _extractResponseMap(
      decoded,
    );

    /*
     * اگر orders مستقیماً در پاسخ نبود،
     * از ساختارهای مختلف پاسخ استخراج می‌کنیم.
     */
    if (result['orders'] is! List) {
      result['orders'] =
          _extractOrders(decoded);
    }

    /*
     * count
     */
    if (result['count'] == null) {
      final orders =
          result['orders'];

      result['count'] =
          orders is List
              ? orders.length
              : 0;
    }

    return result;
  }

  // ============================================================
  // Get Customer Orders List
  // ============================================================

  Future<List<dynamic>>
      getCustomerOrdersList() async {
    final response =
        await getCustomerOrders();

    final orders =
        response['orders'];

    if (orders is List) {
      return orders;
    }

    return <dynamic>[];
  }

  // ============================================================
  // Refresh Customer Orders
  // ============================================================

  /// استفاده برای دکمه Refresh صفحه سفارشات مشتری
  Future<Map<String, dynamic>>
      refreshCustomerOrders() async {
    return getCustomerOrders();
  }

  // ============================================================
  // Get Customer Order By ID
  // ============================================================

  Future<Map<String, dynamic>?>
      getCustomerOrderById(
    int orderId,
  ) async {
    final orders =
        await getCustomerOrdersList();

    for (final item in orders) {
      if (item is! Map) {
        continue;
      }

      final order =
          _asMap(item);

      final id =
          order['id'];

      if (id is int &&
          id == orderId) {
        return order;
      }

      if (id is String &&
          int.tryParse(id) == orderId) {
        return order;
      }

      final orderNumber =
          order['order_number'];

      if (orderNumber is int &&
          orderNumber == orderId) {
        return order;
      }

      if (orderNumber is String &&
          int.tryParse(orderNumber) == orderId) {
        return order;
      }
    }

    return null;
  }
}