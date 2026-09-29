import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';
import '../../services/api/products_api.dart';
import '../../services/api/orders_api.dart';
import '../products/add_product_screen.dart';
import '../products/products_test_screen.dart';
import '../orders/orders_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
  });

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  final ProductsApi _productsApi =
      ProductsApi();

  final OrdersApi _ordersApi =
      OrdersApi();

  bool _isLoadingStats = true;

  int _productsCount = 0;
  int _ordersCount = 0;
  int _salesCount = 0;

  double _income = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    if (mounted) {
      setState(() {
        _isLoadingStats = true;
      });
    }

    try {
      final results =
          await Future.wait<dynamic>([
        _productsApi.getProducts(),
        _ordersApi.getVendorOrdersResponse(
          period: 'all',
        ),
      ]);

      // -----------------------------
      // محصولات
      // -----------------------------

      final products =
          results[0] is List
              ? results[0] as List<dynamic>
              : <dynamic>[];

      // -----------------------------
      // سفارش‌ها
      // -----------------------------

      List<dynamic> orders = [];

      if (results[1] is List) {
        orders =
            results[1] as List<dynamic>;
      } else if (results[1] is Map) {
        final response =
            results[1] as Map;

        final responseOrders =
            response['orders'];

        if (responseOrders is List) {
          orders =
              responseOrders;
        }
      }

      int salesCount = 0;

      // درآمد اصلی فروشنده را مستقیماً از total پاسخ API می‌گیریم.
      // این همان مقداری است که در صفحه سفارشات نیز استفاده می‌شود.
      double income = 0;

      if (results[1] is Map) {
        final response = results[1] as Map;
        final totalValue = response['total'];

        if (totalValue is num) {
          income = totalValue.toDouble();
        } else if (totalValue != null) {
          income = double.tryParse(
                totalValue
                    .toString()
                    .replaceAll(',', '')
                    .replaceAll('تومان', '')
                    .replaceAll('ریال', '')
                    .trim(),
              ) ??
              0;
        }
      }

      // -----------------------------
      // محاسبه آمار
      // -----------------------------

      for (final order in orders) {
        if (order is! Map) {
          continue;
        }

        final status =
            order['status']
                    ?.toString()
                    .toLowerCase()
                    .trim() ??
                '';

        // سفارش‌های لغوشده،
        // ناموفق و مرجوعی محاسبه نشوند.
        if (status == 'cancelled' ||
            status == 'failed' ||
            status == 'refunded') {
          continue;
        }

        // ---------------------------
        // درآمد فروشنده
        // ---------------------------

        double vendorTotal = 0;

        final vendorTotalValue =
            order['vendor_total'];

        if (vendorTotalValue is num) {
          vendorTotal =
              vendorTotalValue.toDouble();
        } else if (vendorTotalValue != null) {
          vendorTotal =
              double.tryParse(
                    vendorTotalValue
                        .toString()
                        .replaceAll(',', '')
                        .replaceAll('تومان', '')
                        .replaceAll('ریال', '')
                        .trim(),
                  ) ??
                  0;
        }

        // اگر vendor_total وجود نداشت،
        // مبلغ line_total محصولات را حساب می‌کنیم.
        if (vendorTotal <= 0) {
          final items =
              order['items'];

          if (items is List) {
            double itemsTotal = 0;

            for (final item in items) {
              if (item is! Map) {
                continue;
              }

              final lineTotalValue =
                  item['line_total'];

              double lineTotal = 0;

              if (lineTotalValue is num) {
                lineTotal =
                    lineTotalValue.toDouble();
              } else if (lineTotalValue != null) {
                lineTotal =
                    double.tryParse(
                          lineTotalValue
                              .toString()
                              .replaceAll(',', '')
                              .replaceAll('تومان', '')
                              .replaceAll('ریال', '')
                              .trim(),
                        ) ??
                        0;
              }

              itemsTotal += lineTotal;
            }

            vendorTotal =
                itemsTotal;
          }
        }

        // ---------------------------
        // تعداد فروش
        // ---------------------------

        final items =
            order['items'];

        if (items is List) {
          for (final item in items) {
            if (item is! Map) {
              continue;
            }

            final quantityValue =
                item['quantity'];

            int quantity = 1;

            if (quantityValue is num) {
              quantity =
                  quantityValue.toInt();
            } else if (quantityValue != null) {
              quantity =
                  int.tryParse(
                        quantityValue
                            .toString(),
                      ) ??
                      1;
            }

            if (quantity > 0) {
              salesCount += quantity;
            }
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _productsCount =
            products.length;

        _ordersCount =
            orders.length;

        _salesCount =
            salesCount;

        _income =
            income;

        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint(
        'DASHBOARD STATS ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _productsCount = 0;
        _ordersCount = 0;
        _salesCount = 0;
        _income = 0;
        _isLoadingStats = false;
      });
    }
  }

  String _formatNumber(
    int number,
  ) {
    return number
        .toString()
        .replaceAllMapped(
          RegExp(
            r'\B(?=(\d{3})+(?!\d))',
          ),
          (match) => ',',
        );
  }

  String _formatMoney(
    double amount,
  ) {
    final rounded =
        amount.round();

    return '${_formatNumber(rounded)} تومان';
  }

  Future<void> _openAddProduct() async {
    final result =
        await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const AddProductScreen(),
      ),
    );

    if (result == true) {
      await _loadDashboardStats();
    }
  }

  Future<void> _openProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const ProductsTestScreen(),
      ),
    );

    await _loadDashboardStats();
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const OrdersScreen(),
      ),
    );

    await _loadDashboardStats();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const ProfileScreen(),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF5F7FB),

        // --------------------------------
        // AppBar
        // --------------------------------

        appBar: AppBar(
          backgroundColor:
              Colors.white,
          elevation: 0,
          centerTitle: false,

          title: const Text(
            'ترشیز استور',
            style: TextStyle(
              color:
                  Color(0xFF1565C0),
              fontSize: 21,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          actions: [
            IconButton(
              onPressed:
                  _loadDashboardStats,
              icon: const Icon(
                Icons.refresh_rounded,
                color:
                    Colors.black87,
              ),
              tooltip:
                  'بروزرسانی',
            ),

            IconButton(
              onPressed: () {
                ScaffoldMessenger
                    .of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'فعلاً اعلان جدیدی وجود ندارد',
                    ),
                    behavior:
                        SnackBarBehavior
                            .floating,
                  ),
                );
              },
              icon: const Icon(
                Icons
                    .notifications_none_rounded,
                color:
                    Colors.black87,
              ),
            ),

            const SizedBox(
              width: 8,
            ),
          ],
        ),

        // --------------------------------
        // Body
        // --------------------------------

        body: RefreshIndicator(
          onRefresh:
              _loadDashboardStats,

          child:
              SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),

            padding:
                const EdgeInsets.all(
              18,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,

              children: [
                // --------------------------------
                // Welcome Banner
                // --------------------------------

                Container(
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),

                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(
                          0xFF1565C0,
                        ),
                        Color(
                          0xFF1976D2,
                        ),
                      ],
                      begin:
                          Alignment
                              .topRight,
                      end:
                          Alignment
                              .bottomLeft,
                    ),

                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .blue
                            .withOpacity(
                          0.18,
                        ),
                        blurRadius:
                            15,
                        offset:
                            const Offset(
                          0,
                          7,
                        ),
                      ),
                    ],
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,

                        decoration:
                            BoxDecoration(
                          color: Colors
                              .white
                              .withOpacity(
                            0.18,
                          ),
                          shape:
                              BoxShape
                                  .circle,
                        ),

                        child:
                            const Icon(
                          Icons
                              .storefront_rounded,
                          color:
                              Colors.white,
                          size: 31,
                        ),
                      ),

                      const SizedBox(
                        width: 15,
                      ),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Text(
                              'سلام، فروشنده عزیز 👋',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            SizedBox(
                              height: 6,
                            ),

                            Text(
                              'به پنل مدیریت فروشگاه خوش آمدید',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white70,
                                fontSize:
                                    13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                // --------------------------------
                // عنوان خلاصه
                // --------------------------------

                const Text(
                  'خلاصه فروشگاه',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF202124),
                  ),
                ),

                const SizedBox(
                  height: 13,
                ),

                // --------------------------------
                // کارت‌های آمار
                // --------------------------------

                GridView(
                  shrinkWrap: true,

                  physics:
                      const NeverScrollableScrollPhysics(),

                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,

                    // ارتفاع ثابت کارت
                    mainAxisExtent: 145,
                  ),

                  children: [
                    _statCard(
                      icon:
                          Icons
                              .payments_rounded,
                      title:
                          'درآمد',
                      value:
                          _isLoadingStats
                              ? 'در حال بارگذاری...'
                              : _formatMoney(
                                  _income,
                                ),
                      iconColor:
                          const Color(
                        0xFFFF8F00,
                      ),
                    ),

                    _statCard(
                      icon:
                          Icons
                              .shopping_bag_rounded,
                      title:
                          'فروش',
                      value:
                          _isLoadingStats
                              ? '...'
                              : _formatNumber(
                                  _salesCount,
                                ),
                      iconColor:
                          const Color(
                        0xFF1565C0,
                      ),
                    ),

                    _statCard(
                      icon:
                          Icons
                              .inventory_2_rounded,
                      title:
                          'محصولات',
                      value:
                          _isLoadingStats
                              ? '...'
                              : _formatNumber(
                                  _productsCount,
                                ),
                      iconColor:
                          const Color(
                        0xFF00897B,
                      ),
                    ),

                    _statCard(
                      icon:
                          Icons
                              .receipt_long_rounded,
                      title:
                          'سفارش‌ها',
                      value:
                          _isLoadingStats
                              ? '...'
                              : _formatNumber(
                                  _ordersCount,
                                ),
                      iconColor:
                          const Color(
                        0xFFE53935,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                // --------------------------------
                // دسترسی سریع
                // --------------------------------

                const Text(
                  'دسترسی سریع',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF202124),
                  ),
                ),

                const SizedBox(
                  height: 13,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          _actionButton(
                        icon:
                            Icons
                                .add_box_rounded,
                        title:
                            'افزودن محصول',
                        color:
                            const Color(
                          0xFF1565C0,
                        ),
                        onTap:
                            _openAddProduct,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child:
                          _actionButton(
                        icon:
                            Icons
                                .inventory_2_rounded,
                        title:
                            'محصولات',
                        color:
                            const Color(
                          0xFF00897B,
                        ),
                        onTap:
                            _openProducts,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                // --------------------------------
                // سفارش‌های اخیر
                // --------------------------------

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,

                  children: [
                    const Text(
                      'سفارش‌های اخیر',
                      style:
                          TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight
                                .bold,
                        color:
                            Color(
                          0xFF202124,
                        ),
                      ),
                    ),

                    TextButton(
                      onPressed:
                          _openOrders,

                      child:
                          const Text(
                        'مشاهده همه',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFF1565C0,
                          ),
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 5,
                ),

                InkWell(
                  onTap:
                      _openOrders,

                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),

                  child:
                      Container(
                    width:
                        double.infinity,

                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,

                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),

                      border:
                          Border.all(
                        color: Colors
                            .grey
                            .shade200,
                      ),
                    ),

                    child:
                        Column(
                      children: [
                        Icon(
                          Icons
                              .receipt_long_outlined,
                          size: 55,
                          color: Colors
                              .grey
                              .shade400,
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Text(
                          _ordersCount ==
                                  0
                              ? 'هنوز سفارشی ثبت نشده است'
                              : 'مشاهده سفارش‌ها',

                          style:
                              TextStyle(
                            color: Colors
                                .grey
                                .shade700,
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          _ordersCount ==
                                  0
                              ? 'وقتی سفارشی برای محصولات فروشگاه ثبت شود، اینجا نمایش داده می‌شود.'
                              : 'برای مشاهده سفارش‌های فروشگاه اینجا بزنید.',

                          textAlign:
                              TextAlign
                                  .center,

                          style:
                              TextStyle(
                            color: Colors
                                .grey
                                .shade500,
                            fontSize:
                                12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 25,
                ),
              ],
            ),
          ),
        ),

        // --------------------------------
        // Bottom Navigation
        // --------------------------------

        bottomNavigationBar:
            BottomNavigationBar(
          currentIndex: 0,

          type:
              BottomNavigationBarType
                  .fixed,

          selectedItemColor:
              const Color(
            0xFF1565C0,
          ),

          unselectedItemColor:
              Colors.grey,

          backgroundColor:
              Colors.white,

          onTap: (index) {
            if (index == 0) {
              return;
            }

            if (index == 1) {
              _openProducts();
              return;
            }

            if (index == 2) {
              _openOrders();
              return;
            }

            if (index == 3) {
              _openProfile();
              return;
            }
          },

          items: const [
            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .dashboard_rounded,
              ),
              label: 'خانه',
            ),

            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .inventory_2_outlined,
              ),
              label: 'محصولات',
            ),

            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .shopping_cart_outlined,
              ),
              label: 'سفارش‌ها',
            ),

            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .person_outline_rounded,
              ),
              label: 'حساب',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // کارت آمار
  // ==========================================

  static Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(
              0.03,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          // آیکن
          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color: iconColor
                  .withOpacity(
                0.10,
              ),

              borderRadius:
                  BorderRadius
                      .circular(
                12,
              ),
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 23,
            ),
          ),

          const Spacer(),

          // عنوان
          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,

            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 12,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          // مقدار
          SizedBox(
            width:
                double.infinity,

            child: FittedBox(
              alignment:
                  Alignment.centerRight,

              fit:
                  BoxFit.scaleDown,

              child: Text(
                value,
                maxLines: 1,

                style:
                    const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF202124),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // دکمه‌های دسترسی سریع
  // ==========================================

  static Widget _actionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(
        17,
      ),

      child: Container(
        height: 105,

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            17,
          ),

          border:
              Border.all(
            color:
                Colors.grey.shade200,
          ),
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,

          children: [
            Icon(
              icon,
              size: 34,
              color: color,
            ),

            const SizedBox(
              height: 9,
            ),

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



