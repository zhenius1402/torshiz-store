import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api/orders_api.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onStatusUpdated;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    this.onStatusUpdated,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrdersApi _ordersApi = OrdersApi();

  late Map<String, dynamic> _order;

  bool _isUpdatingStatus = false;

  static const List<String> _vendorStatuses = [
    'pending',
    'preparing',
    'ready_to_ship',
    'shipped',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();

    _order = Map<String, dynamic>.from(widget.order);
  }

  // ============================================================
  // متن امن
  // ============================================================

  String _safeText(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    return text.isEmpty ? '-' : text;
  }

  // ============================================================
  // تبدیل قیمت
  // ============================================================

  double _parseMoney(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    String text = value.toString().trim();

    if (text.isEmpty) {
      return 0;
    }

    text = text.replaceAll(
      RegExp(r'<[^>]*>'),
      '',
    );

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('\u00A0', ' ');

    try {
      if (text.startsWith('"') && text.endsWith('"')) {
        final decoded = jsonDecode(text);

        if (decoded is String) {
          text = decoded;
        }
      }
    } catch (_) {}

    const persianNumbers = '۰۱۲۳۴۵۶۷۸۹';
    const arabicNumbers = '٠١٢٣٤٥٦٧٨٩';

    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(
        persianNumbers[i],
        i.toString(),
      );

      text = text.replaceAll(
        arabicNumbers[i],
        i.toString(),
      );
    }

    text = text
        .replaceAll('تومان', '')
        .replaceAll('تومن', '')
        .replaceAll('ریال', '')
        .replaceAll('IRR', '')
        .replaceAll('IRT', '');

    text = text
        .replaceAll(',', '')
        .replaceAll('،', '')
        .replaceAll('٬', '')
        .replaceAll(' ', '')
        .trim();

    return double.tryParse(text) ?? 0;
  }

  // ============================================================
  // نمایش قیمت
  // ============================================================

  String _formatMoney(
    dynamic value, {
    bool showDashWhenZero = true,
  }) {
    final amount = _parseMoney(value);

    if (amount == 0 && showDashWhenZero) {
      return '-';
    }

    final rounded = amount.round();

    final formatted = rounded.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );

    return '$formatted تومان';
  }

  // ============================================================
  // قیمت محصول
  // ============================================================

  String _getItemPrice(
    Map<String, dynamic> product,
  ) {
    final formatted =
        product['total_formatted'] ??
        product['line_total_formatted'];

    if (formatted != null &&
        formatted.toString().trim().isNotEmpty &&
        formatted.toString().trim() != '-') {
      final parsed = _parseMoney(formatted);

      if (parsed > 0) {
        return _formatMoney(parsed);
      }
    }

    final raw =
        product['total'] ??
        product['line_total'] ??
        product['subtotal'];

    return _formatMoney(raw);
  }

  // ============================================================
  // سهم فروشنده
  // ============================================================

  String _getVendorTotal() {
    final raw = _order['vendor_total'];

    final rawAmount = _parseMoney(raw);

    if (rawAmount > 0) {
      return _formatMoney(rawAmount);
    }

    final formatted = _order['vendor_total_formatted'];

    final formattedAmount = _parseMoney(formatted);

    if (formattedAmount > 0) {
      return _formatMoney(formattedAmount);
    }

    final total = _order['total'];

    final totalAmount = _parseMoney(total);

    if (totalAmount > 0) {
      return _formatMoney(totalAmount);
    }

    return '0 تومان';
  }

  // ============================================================
  // Order ID
  // ============================================================

  int? _safeOrderId(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  // ============================================================
  // وضعیت معتبر فروشنده
  // ============================================================

  String _normalizeStatus(dynamic status) {
    final value = _safeText(status).toLowerCase().trim();

    if (_vendorStatuses.contains(value)) {
      return value;
    }

    return '';
  }

  // ============================================================
  // وضعیت واقعی فروشنده
  //
  // اول از آیتم‌های خود فروشنده می‌خوانیم.
  // اگر نبود، از status سفارش استفاده می‌کنیم.
  // ============================================================

  String _getVendorStatus() {
    final items = _order['items'];

    if (items is List && items.isNotEmpty) {
      final statuses = <String>[];

      for (final item in items) {
        if (item is! Map) {
          continue;
        }

        final status = _normalizeStatus(item['status']);

        if (status.isNotEmpty) {
          statuses.add(status);
        }
      }

      if (statuses.isNotEmpty) {
        // اگر چند وضعیت وجود داشت،
        // بالاترین مرحله را به عنوان وضعیت فروشنده نشان می‌دهیم.
        return _getHighestStatus(statuses);
      }
    }

    final orderStatus = _normalizeStatus(_order['status']);

    if (orderStatus.isNotEmpty) {
      return orderStatus;
    }

    // وضعیت‌های استاندارد WooCommerce
    // به معنی وضعیت فروشنده نیستند.
    return 'pending';
  }

  // ============================================================
  // بالاترین مرحله وضعیت
  // ============================================================

  int _statusPriority(String status) {
    switch (status) {
      case 'pending':
        return 1;

      case 'preparing':
        return 2;

      case 'ready_to_ship':
        return 3;

      case 'shipped':
        return 4;

      case 'delivered':
        return 5;

      case 'cancelled':
        return 99;

      default:
        return 0;
    }
  }

  String _getHighestStatus(List<String> statuses) {
    if (statuses.contains('cancelled')) {
      return 'cancelled';
    }

    String highest = 'pending';

    for (final status in statuses) {
      if (_statusPriority(status) > _statusPriority(highest)) {
        highest = status;
      }
    }

    return highest;
  }

  // ============================================================
  // Status text
  // ============================================================

  String _statusText(dynamic status) {
    final value = _safeText(status).toLowerCase();

    switch (value) {
      case 'pending':
        return 'در حال بررسی';

      case 'preparing':
        return 'در حال آماده‌سازی';

      case 'ready_to_ship':
        return 'آماده ارسال';

      case 'shipped':
        return 'ارسال به پست';

      case 'delivered':
        return 'تحویل به مشتری';

      case 'cancelled':
        return 'لغو شده';

      case 'processing':
        return 'در حال پردازش';

      case 'on-hold':
        return 'در انتظار بررسی';

      case 'completed':
        return 'تکمیل شده';

      case 'refunded':
        return 'مبلغ برگشت داده شده';

      case 'failed':
        return 'ناموفق';

      default:
        return _safeText(status);
    }
  }

  // ============================================================
  // Status color
  // ============================================================

  Color _statusColor(dynamic status) {
    final value = _safeText(status).toLowerCase();

    switch (value) {
      case 'delivered':
      case 'completed':
        return Colors.green;

      case 'cancelled':
      case 'failed':
        return Colors.red;

      case 'shipped':
      case 'ready_to_ship':
        return Colors.blue;

      case 'preparing':
        return Colors.indigo;

      case 'pending':
      case 'on-hold':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // مرحله بعدی
  // ============================================================

  String? _getNextStatus(String status) {
    switch (status) {
      case 'pending':
        return 'preparing';

      case 'preparing':
        return 'ready_to_ship';

      case 'ready_to_ship':
        return 'shipped';

      default:
        return null;
    }
  }

  // ============================================================
  // عنوان دکمه
  // ============================================================

  String _getNextStatusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'شروع آماده‌سازی';

      case 'preparing':
        return 'آماده برای ارسال';

      case 'ready_to_ship':
        return 'تحویل به پست';

      default:
        return 'تغییر وضعیت';
    }
  }

  // ============================================================
  // آیکن مرحله
  // ============================================================

  IconData _getNextStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.play_arrow_rounded;

      case 'preparing':
        return Icons.inventory_2_outlined;

      case 'ready_to_ship':
        return Icons.local_shipping_outlined;

      default:
        return Icons.arrow_forward_rounded;
    }
  }

  // ============================================================
  // بروزرسانی وضعیت محلی آیتم‌های فروشنده
  // ============================================================

  void _updateLocalItemsStatus(String newStatus) {
    final items = _order['items'];

    if (items is! List) {
      return;
    }

    final updatedItems = <dynamic>[];

    for (final item in items) {
      if (item is Map) {
        final updatedItem =
            Map<String, dynamic>.from(item);

        updatedItem['status'] = newStatus;
        updatedItem['status_label'] =
            _statusText(newStatus);

        updatedItems.add(updatedItem);
      } else {
        updatedItems.add(item);
      }
    }

    _order['items'] = updatedItems;
  }

  // ============================================================
  // تغییر وضعیت سفارش
  // ============================================================

  Future<void> _changeStatus(String newStatus) async {
    final orderId = _safeOrderId(_order['id']);

    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شناسه سفارش نامعتبر است.'),
        ),
      );

      return;
    }

    if (_isUpdatingStatus) {
      return;
    }

    final currentStatus = _getVendorStatus();

    // ----------------------------------------------------------
    // جلوگیری از پرش مرحله
    // ----------------------------------------------------------

    final expectedNext = _getNextStatus(currentStatus);

    if (expectedNext == null ||
        expectedNext != newStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'امکان رد کردن مراحل سفارش وجود ندارد.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final result =
          await _ordersApi.updateOrderStatus(
        orderId: orderId,
        status: newStatus,
      );

      if (!mounted) {
        return;
      }

      // --------------------------------------------------------
      // وضعیت برگشتی API
      // --------------------------------------------------------

      String updatedStatus = _normalizeStatus(
        result['status'] ??
            result['vendor_status'] ??
            newStatus,
      );

      if (updatedStatus.isEmpty) {
        updatedStatus = newStatus;
      }

      // --------------------------------------------------------
      // اگر API آیتم‌ها را برگرداند،
      // همان‌ها را استفاده می‌کنیم.
      // --------------------------------------------------------

      if (result['items'] is List) {
        _order['items'] = result['items'];
      } else {
        // اگر API آیتم‌ها را برنگرداند،
        // وضعیت آیتم‌های فروشنده را محلی به‌روز می‌کنیم.
        _updateLocalItemsStatus(updatedStatus);
      }

      setState(() {
        _order['status'] = updatedStatus;

        _order['status_label'] =
            result['status_label'] ??
            result['vendor_status_label'] ??
            _statusText(updatedStatus);
      });

      widget.onStatusUpdated?.call();

      String message;

      switch (updatedStatus) {
        case 'preparing':
          message =
              'وضعیت سفارش به «در حال آماده‌سازی» تغییر کرد.';
          break;

        case 'ready_to_ship':
          message =
              'وضعیت سفارش به «آماده ارسال» تغییر کرد.';
          break;

        case 'shipped':
          message =
              'محصول به پست تحویل داده شد.\n'
              'اکنون منتظر تأیید دریافت توسط مشتری باشید.';
          break;

        default:
          message =
              'وضعیت سفارش به «${_statusText(updatedStatus)}» تغییر کرد.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final status = _getVendorStatus();

    final statusColor = _statusColor(status);

    final items =
        _order['items'] is List
            ? _order['items'] as List
            : <dynamic>[];

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        title: Text(
          'سفارش #${_safeText(_order['order_number'])}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff172033),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderHeader(
            status: status,
            statusColor: statusColor,
          ),

          const SizedBox(height: 14),

          _buildStatusActionCard(status),

          const SizedBox(height: 14),

          _buildCustomerCard(),

          const SizedBox(height: 14),

          _buildPaymentCard(),

          const SizedBox(height: 14),

          _buildProductsCard(items),

          const SizedBox(height: 14),

          _buildAddressCard(),

          const SizedBox(height: 14),

          _buildVendorAmountCard(),
        ],
      ),
    );
  }

  // ============================================================
  // Header
  // ============================================================

  Widget _buildOrderHeader({
    required dynamic status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfffff1df),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 34,
              color: Color(0xffef8b19),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'سفارش #${_safeText(_order['order_number'])}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff172033),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _safeText(_order['date_created']),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _statusText(status),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Status action
  // ============================================================

  Widget _buildStatusActionCard(dynamic status) {
    final value = _normalizeStatus(status);

    // ----------------------------------------------------------
    // مراحل قابل تغییر توسط فروشنده
    // ----------------------------------------------------------

    final nextStatus = _getNextStatus(value);

    if (nextStatus != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'مرحله فعلی سفارش',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              _statusText(value),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _statusColor(value),
              ),
            ),

            const SizedBox(height: 14),

            _buildFullStatusProgress(value),

            const SizedBox(height: 18),

            Text(
              'مرحله بعد: ${_statusText(nextStatus)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _changeStatus(
                          nextStatus,
                        ),
                icon: _isUpdatingStatus
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _getNextStatusIcon(value),
                      ),
                label: Text(
                  _getNextStatusTitle(value),
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xff2864d7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 13,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // ارسال شده - منتظر مشتری
    // ----------------------------------------------------------

    if (value == 'shipped') {
      return Column(
        children: [
          _buildFullStatusProgress(value),

          const SizedBox(height: 10),

          _buildInfoBanner(
            icon: Icons.hourglass_top_outlined,
            color: Colors.orange,
            text:
                'محصول به پست تحویل داده شده است. '
                'اکنون منتظر تأیید دریافت توسط مشتری باشید.',
          ),
        ],
      );
    }

    // ----------------------------------------------------------
    // تحویل شده
    // ----------------------------------------------------------

    if (value == 'delivered') {
      return Column(
        children: [
          _buildFullStatusProgress(value),

          const SizedBox(height: 10),

          _buildInfoBanner(
            icon: Icons.check_circle_outline,
            color: Colors.green,
            text:
                'مشتری دریافت محصول را تأیید کرده است و سفارش تحویل شده محسوب می‌شود.',
          ),
        ],
      );
    }

    // ----------------------------------------------------------
    // لغو شده
    // ----------------------------------------------------------

    if (value == 'cancelled') {
      return _buildInfoBanner(
        icon: Icons.cancel_outlined,
        color: Colors.red,
        text: 'این سفارش لغو شده است.',
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // Progress کامل
  // ============================================================

  Widget _buildFullStatusProgress(String status) {
    final steps = <Map<String, dynamic>>[
      {
        'status': 'pending',
        'title': 'بررسی',
        'icon': Icons.visibility_outlined,
      },
      {
        'status': 'preparing',
        'title': 'آماده‌سازی',
        'icon': Icons.inventory_2_outlined,
      },
      {
        'status': 'ready_to_ship',
        'title': 'آماده ارسال',
        'icon': Icons.inventory_outlined,
      },
      {
        'status': 'shipped',
        'title': 'ارسال به پست',
        'icon': Icons.local_shipping_outlined,
      },
      {
        'status': 'delivered',
        'title': 'تحویل',
        'icon': Icons.check_circle_outline,
      },
    ];

    int currentIndex = steps.indexWhere(
      (step) => step['status'] == status,
    );

    if (currentIndex < 0) {
      currentIndex = 0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: List.generate(
          steps.length,
          (index) {
            final step = steps[index];

            final completed =
                index <= currentIndex;
            final active =
                index == currentIndex;

            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 250,
                          ),
                          width: active ? 38 : 32,
                          height: active ? 38 : 32,
                          decoration: BoxDecoration(
                            color: completed
                                ? _statusColor(
                                    step['status'],
                                  )
                                : Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            step['icon'],
                            size: active ? 19 : 16,
                            color: completed
                                ? Colors.white
                                : Colors.grey.shade500,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          step['title'],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: completed
                                ? _statusColor(
                                    step['status'],
                                  )
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (index < steps.length - 1)
                    Container(
                      width: 8,
                      height: 2,
                      color: index < currentIndex
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // Info banner
  // ============================================================

  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Customer
  // ============================================================

  Widget _buildCustomerCard() {
    return _buildSectionCard(
      title: 'اطلاعات مشتری',
      icon: Icons.person_outline,
      children: [
        _buildInfoRow(
          Icons.person_outline,
          'نام مشتری',
          _safeText(_order['customer_name']),
        ),

        const SizedBox(height: 10),

        _buildInfoRow(
          Icons.phone_outlined,
          'شماره تماس',
          _safeText(_order['customer_phone']),
        ),

        const SizedBox(height: 10),

        _buildInfoRow(
          Icons.email_outlined,
          'ایمیل',
          _safeText(_order['customer_email']),
        ),
      ],
    );
  }

  // ============================================================
  // Payment
  // ============================================================

  Widget _buildPaymentCard() {
    return _buildSectionCard(
      title: 'پرداخت و ارسال',
      icon: Icons.payment_outlined,
      children: [
        _buildInfoRow(
          Icons.payment_outlined,
          'روش پرداخت',
          _safeText(_order['payment_method']),
        ),

        const SizedBox(height: 10),

        _buildInfoRow(
          Icons.local_shipping_outlined,
          'روش ارسال',
          _safeText(_order['shipping_method']),
        ),
      ],
    );
  }

  // ============================================================
  // Products
  // ============================================================

  Widget _buildProductsCard(List items) {
    return _buildSectionCard(
      title: 'محصولات سفارش',
      icon: Icons.inventory_2_outlined,
      children: [
        if (items.isEmpty)
          Text(
            'محصولی برای این سفارش ثبت نشده است.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          )
        else
          ...items.map(
            (item) {
              final product =
                  item is Map
                      ? Map<String, dynamic>.from(item)
                      : <String, dynamic>{};

              final productName =
                  _safeText(product['product_name']);

              final quantity =
                  _safeText(product['quantity']);

              final lineTotal =
                  _getItemPrice(product);

              final productStatus =
                  _normalizeStatus(
                product['status'],
              );

              final displayStatus =
                  productStatus.isEmpty
                      ? 'pending'
                      : productStatus;

              return Container(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f9fc),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color:
                            Color(0xff2864d7),
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'تعداد: $quantity',
                            style: TextStyle(
                              color:
                                  Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  _statusColor(
                                displayStatus,
                              ).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(20),
                            ),
                            child: Text(
                              _statusText(
                                displayStatus,
                              ),
                              style: TextStyle(
                                color:
                                    _statusColor(
                                  displayStatus,
                                ),
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    if (lineTotal != '-')
                      Flexible(
                        child: Text(
                          lineTotal,
                          textAlign:
                              TextAlign.end,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Color(0xff2864d7),
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // Address
  // ============================================================

  Widget _buildAddressCard() {
    final billing = _order['billing'];

    if (billing is! Map) {
      return _buildSectionCard(
        title: 'آدرس مشتری',
        icon: Icons.location_on_outlined,
        children: const [
          Text(
            'اطلاعات آدرس موجود نیست.',
          ),
        ],
      );
    }

    final firstName =
        _safeText(billing['first_name']);

    final lastName =
        _safeText(billing['last_name']);

    final address1 =
        _safeText(billing['address_1']);

    final address2 =
        _safeText(billing['address_2']);

    final city =
        _safeText(billing['city']);

    final state =
        _safeText(billing['state']);

    final postcode =
        _safeText(billing['postcode']);

    return _buildSectionCard(
      title: 'آدرس مشتری',
      icon: Icons.location_on_outlined,
      children: [
        _buildInfoRow(
          Icons.person_outline,
          'نام',
          '$firstName $lastName'.trim(),
        ),

        const SizedBox(height: 10),

        _buildInfoRow(
          Icons.location_on_outlined,
          'آدرس',
          address1,
        ),

        if (address2 != '-') ...[
          const SizedBox(height: 10),

          _buildInfoRow(
            Icons.home_outlined,
            'ادامه آدرس',
            address2,
          ),
        ],

        const SizedBox(height: 10),

        _buildInfoRow(
          Icons.location_city_outlined,
          'شهر',
          city,
        ),

        const SizedBox(height: 10),

        _buildInfoRow(
          Icons.map_outlined,
          'استان',
          state,
        ),

        const SizedBox(height: 10),

        _buildInfoRow(
          Icons.mail_outline,
          'کد پستی',
          postcode,
        ),
      ],
    );
  }

  // ============================================================
  // Vendor amount
  // ============================================================

  Widget _buildVendorAmountCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff2864d7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'سهم فروشنده',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'مبلغ دریافتی شما از این سفارش',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Flexible(
            child: Text(
              _getVendorTotal(),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Section card
  // ============================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color:
                      const Color(0xff2864d7),
                  size: 21,
                ),

                const SizedBox(width: 8),

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(),

            const SizedBox(height: 8),

            ...children,
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Info row
  // ============================================================

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.grey.shade600,
        ),

        const SizedBox(width: 8),

        Text(
          '$title:',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}