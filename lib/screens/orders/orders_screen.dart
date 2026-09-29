import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api/orders_api.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  final OrdersApi _ordersApi = OrdersApi();

  // داده‌ی فعلی صفحه. برای رفرش‌های خاموش (polling) این مقدار
  // فقط در صورت موفقیت جایگزین می‌شود تا کاربر با فلیکر یا
  // خالی‌شدن لحظه‌ای صفحه مواجه نشود.
  Map<String, dynamic>? _data;

  // فقط بار اول (یا تغییر بازه‌ی زمانی) اسپینر تمام‌صفحه نشان
  // داده می‌شود؛ رفرش‌های خودکار بی‌صدا انجام می‌شوند.
  bool _isLoading = true;

  String? _errorText;

  String _selectedPeriod = 'day';

  Timer? _pollTimer;
  bool _isFetching = false;

  static const Duration _pollInterval =
      Duration(seconds: 8);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    _loadTransactions(showLoading: true);

    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();

    WidgetsBinding.instance
        .removeObserver(this);

    super.dispose();
  }

  /* =========================================================
   * توقف polling وقتی اپ به بک‌گراند می‌رود و از سر گیری آن
   * وقتی کاربر دوباره به اپ برمی‌گردد. مشابه visibilitychange
   * در نسخه‌ی وب.
   * ========================================================= */

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _loadTransactions(showLoading: false);
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(
      _pollInterval,
      (_) {
        _loadTransactions(showLoading: false);
      },
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /* =========================================================
   * بارگذاری تراکنش‌ها
   *
   * showLoading = true  → اسپینر تمام‌صفحه نشان داده می‌شود
   *                       (بار اول یا تغییر بازه‌ی زمانی).
   *
   * showLoading = false → رفرش خاموش (polling یا کشیدن به پایین)؛
   *                       تا وقتی داده‌ی جدید با موفقیت نرسیده،
   *                       محتوای فعلی صفحه دست‌نخورده می‌ماند.
   * ========================================================= */

  Future<void> _loadTransactions({
    required bool showLoading,
  }) async {
    if (_isFetching) {
      return;
    }

    _isFetching = true;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final result = await _ordersApi
          .getVendorTransactions(
        period: _selectedPeriod,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _data = result;
        _isLoading = false;
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        // فقط اگر این یک بارگذاری آشکار (نه polling خاموش) بود
        // پیام خطا نشان داده می‌شود؛ در غیر این صورت داده‌ی قبلی
        // همچنان روی صفحه باقی می‌ماند.
        if (showLoading) {
          _errorText = _safeText(e);
        }
      });
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _refreshTransactions() async {
    await _loadTransactions(showLoading: false);
  }

  void _changePeriod(String period) {
    if (_selectedPeriod == period) {
      return;
    }

    setState(() {
      _selectedPeriod = period;
    });

    _loadTransactions(showLoading: true);
  }

  void _openOrderDetails(
    Map<String, dynamic> order,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrderDetailsScreen(
          order: order,
          onStatusUpdated: () {
            if (!mounted) {
              return;
            }

            _loadTransactions(showLoading: false);
          },
        ),
      ),
    );
  }

  String _safeText(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    return text;
  }

  String _cleanPrice(dynamic value) {
    if (value == null) {
      return '-';
    }

    String text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    /*
     * اگر HTML از نسخه قبلی API باقی مانده باشد
     */
    text = text.replaceAll(
      RegExp(r'<[^>]*>'),
      '',
    );

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'");

    /*
     * اگر JSON string بود
     */
    try {
      if (text.startsWith('"') &&
          text.endsWith('"')) {
        final decoded = jsonDecode(text);

        if (decoded is String) {
          text = decoded;
        }
      }
    } catch (_) {}

    text = text
        .replaceAll(
          '\u00A0',
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();

    return text.isEmpty ? '-' : text;
  }

  String _statusText(dynamic status) {
    final value =
        _safeText(status).toLowerCase();

    switch (value) {
      case 'pending':
        return 'در حال بررسی';

      case 'preparing':
        return 'آماده‌سازی';

      case 'ready_to_ship':
        return 'آماده ارسال';

      case 'shipped':
        return 'ارسال به پست';

      case 'delivered':
        return 'تکمیل';

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

  Color _statusColor(dynamic status) {
    final value =
        _safeText(status).toLowerCase();

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

  /* =========================================================
   * وضعیت هر محصول (نه کل سفارش)
   *
   * از فیلدهای item['vendor_status'] / item['vendor_status_label']
   * که API برمی‌گرداند استفاده می‌شود. مقدار vendor_status_label
   * برای delivered از سمت سرور همین حالا «تکمیل» است، اما
   * is_completed هم به‌عنوان یک بولین صریح و مطمئن (بدون وابستگی
   * به مقایسه‌ی رشته) برای رنگ سبز استفاده می‌شود.
   * ========================================================= */

  bool _isItemCompleted(
    Map<String, dynamic> product,
  ) {
    return product['is_completed'] == true ||
        _safeText(product['vendor_status'])
                .toLowerCase() ==
            'delivered';
  }

  Color _itemStatusColor(
    Map<String, dynamic> product,
  ) {
    if (_isItemCompleted(product)) {
      return Colors.green;
    }

    return _statusColor(
      product['vendor_status'],
    );
  }

  String _itemStatusLabel(
    Map<String, dynamic> product,
  ) {
    if (_isItemCompleted(product)) {
      return 'تکمیل';
    }

    final label =
        product['vendor_status_label'];

    if (label != null &&
        _safeText(label) != '-') {
      return _safeText(label);
    }

    return _statusText(
      product['vendor_status'],
    );
  }

  String _periodTitle() {
    switch (_selectedPeriod) {
      case 'day':
        return 'امروز';

      case 'week':
        return 'این هفته';

      case 'month':
        return 'این ماه';

      case 'all':
        return 'همه تراکنش‌ها';

      default:
        return 'تراکنش‌ها';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xfff5f7fb),
      appBar: AppBar(
        title: const Text(
          'تراکنش‌ها',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor:
            const Color(0xff172033),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _loadTransactions(
                showLoading: true,
              );
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _data == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorText != null &&
        _data == null) {
      return _buildErrorState(_errorText!);
    }

    final data = _data ?? {};

    final orders =
        data['orders'] is List
            ? data['orders'] as List<dynamic>
            : <dynamic>[];

    final count =
        data['count'] ?? orders.length;

    final totalFormatted = _cleanPrice(
      data['total_formatted'],
    );

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshTransactions,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24,
          ),
          children: [
            _buildSummaryCard(
              count: count,
              totalFormatted: totalFormatted,
            ),
            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.5,
              child: _buildEmptyState(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTransactions,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24,
        ),
        children: [
          _buildSummaryCard(
            count: count,
            totalFormatted: totalFormatted,
          ),

          const SizedBox(height: 16),

          Text(
            _periodTitle(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xff172033),
            ),
          ),

          const SizedBox(height: 12),

          ...orders.map(
            (item) {
              if (item
                  is Map<String, dynamic>) {
                return _buildOrderCard(item);
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        14,
      ),
      child: SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,
        child: Row(
          children: [
            _buildPeriodButton(
              value: 'day',
              title: 'امروز',
              icon: Icons.today_outlined,
            ),
            const SizedBox(width: 8),
            _buildPeriodButton(
              value: 'week',
              title: 'این هفته',
              icon:
                  Icons.date_range_outlined,
            ),
            const SizedBox(width: 8),
            _buildPeriodButton(
              value: 'month',
              title: 'این ماه',
              icon: Icons
                  .calendar_month_outlined,
            ),
            const SizedBox(width: 8),
            _buildPeriodButton(
              value: 'all',
              title: 'همه',
              icon: Icons.all_inclusive,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton({
    required String value,
    required String title,
    required IconData icon,
  }) {
    final isSelected =
        _selectedPeriod == value;

    return InkWell(
      onTap: () {
        _changePeriod(value);
      },
      borderRadius:
          BorderRadius.circular(14),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xff2864d7)
              : const Color(0xfff1f4f9),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xff2864d7)
                : const Color(0xffe3e7ee),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : const Color(0xff596579),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : const Color(0xff344054),
                fontWeight:
                    FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required dynamic count,
    required String totalFormatted,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(top: 8),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xff2864d7),
            Color(0xff1749a6),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.08,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'خلاصه ${_periodTitle()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child:
                    _buildSummaryItem(
                  icon:
                      Icons.receipt_long_outlined,
                  title:
                      'تعداد تراکنش',
                  value:
                      _safeText(count),
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white24,
              ),
              Expanded(
                child:
                    _buildSummaryItem(
                  icon: Icons
                      .account_balance_wallet_outlined,
                  title: 'مجموع فروش',
                  value:
                      totalFormatted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 25,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(
                    height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
  ) {
    final status =
        order['status'];

    final statusColor =
        _statusColor(status);

    final items =
        order['items'] is List
            ? order['items'] as List
            : <dynamic>[];

    return InkWell(
      onTap: () {
        _openOrderDetails(order);
      },
      borderRadius:
          BorderRadius.circular(18),
      child: Card(
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        elevation: 0,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      10,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xfffff1df,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .shopping_bag_outlined,
                      color:
                          Color(0xffef8b19),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'سفارش #${_safeText(order['order_number'])}',
                          style:
                              const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                          _safeText(
                            order[
                                'date_created'],
                          ),
                          style: TextStyle(
                            color: Colors
                                .grey
                                .shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color: statusColor
                          .withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Text(
                      _statusText(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),

              _buildInfoRow(
                Icons.person_outline,
                'مشتری',
                _safeText(
                  order['customer_name'],
                ),
              ),

              const SizedBox(height: 8),

              _buildInfoRow(
                Icons.phone_outlined,
                'شماره تماس',
                _safeText(
                  order['customer_phone'],
                ),
              ),

              const SizedBox(height: 8),

              _buildInfoRow(
                Icons.payment_outlined,
                'روش پرداخت',
                _safeText(
                  order['payment_method'],
                ),
              ),

              const SizedBox(height: 14),

              Container(
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xfff3f7ff,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .account_balance_wallet_outlined,
                      color:
                          Color(0xff2864d7),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'مبلغ سهم فروشنده',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _cleanPrice(
                        order[
                            'vendor_total_formatted'],
                      ),
                      style:
                          const TextStyle(
                        color:
                            Color(0xff2864d7),
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              if (items.isNotEmpty) ...[
                const SizedBox(
                    height: 14),
                const Text(
                  'محصولات سفارش',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                ...items.map(
                  (item) {
                    final product =
                        item is Map
                            ? Map<String,
                                dynamic>.from(
                                item,
                              )
                            : <String,
                                dynamic>{};

                    final itemColor =
                        _itemStatusColor(
                      product,
                    );

                    final itemLabel =
                        _itemStatusLabel(
                      product,
                    );

                    return Container(
                      margin:
                          const EdgeInsets.only(
                        bottom: 8,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration:
                          BoxDecoration(
                        // *** بخش جدید ***
                        // اگر محصول توسط مشتری تایید دریافت
                        // شده باشد (is_completed)، پس‌زمینه‌ی
                        // ردیف سبز کم‌رنگ می‌شود.
                        color: itemColor
                            .withValues(
                          alpha: 0.06,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                        border: Border.all(
                          color: itemColor
                              .withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isItemCompleted(
                                  product,
                                )
                                    ? Icons
                                        .check_circle
                                    : Icons
                                        .inventory_2_outlined,
                                size: 18,
                                color:
                                    itemColor,
                              ),
                              const SizedBox(
                                  width: 8),
                              Expanded(
                                child: Text(
                                  '${_safeText(product['product_name'])} × ${_safeText(product['quantity'])}',
                                  style:
                                      const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                _cleanPrice(
                                  product[
                                      'total_formatted'] ??
                                      product[
                                          'line_total_formatted'],
                                ),
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color: Color(
                                      0xff2864d7),
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                              height: 6),

                          // *** بخش جدید ***
                          // چیپ وضعیت هر محصول؛ وقتی مشتری
                          // دریافت را تایید کرده باشد سبز
                          // شده و «تکمیل» نمایش می‌دهد.
                          Align(
                            alignment: Alignment
                                .centerRight,
                            child: Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: itemColor
                                    .withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                itemLabel,
                                style:
                                    TextStyle(
                                  color:
                                      itemColor,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
          size: 18,
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
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons
                .receipt_long_outlined,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 15),
          Text(
            'تراکنشی وجود ندارد',
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    String error,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.red,
            ),
            const SizedBox(height: 15),
            Text(
              error,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                _loadTransactions(
                  showLoading: true,
                );
              },
              icon:
                  const Icon(Icons.refresh),
              label:
                  const Text('تلاش مجدد'),
            ),
          ],
        ),
      ),
    );
  }
}