 import 'package:flutter/material.dart';

import '../../services/api/products_api.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class ProductsTestScreen extends StatefulWidget {
  const ProductsTestScreen({
    super.key,
  });

  @override
  State<ProductsTestScreen> createState() {
    return _ProductsTestScreenState();
  }
}

class _ProductsTestScreenState
    extends State<ProductsTestScreen> {
  final ProductsApi _productsApi = ProductsApi();

  List<dynamic> _products = [];
  List<dynamic> _categories = [];

  bool _isLoading = true;
  bool _isLoadingCategories = false;

  String? _errorMessage;

  String _searchText = '';
  int? _selectedCategoryId;

  final TextEditingController _searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    _loadProducts();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // دریافت محصولات
  // =========================================================

  Future<void> _loadProducts() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<dynamic> products =
          await _productsApi.getProducts();

      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  // =========================================================
  // دریافت دسته‌بندی‌ها
  // =========================================================

  Future<void> _loadCategories() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final List<dynamic> categories =
          await _productsApi.getCategories();

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  // =========================================================
  // افزودن محصول
  // =========================================================

  Future<void> _addProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const AddProductScreen();
        },
      ),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  // =========================================================
  // ویرایش محصول
  // =========================================================

  Future<void> _editProduct(
    dynamic product,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return EditProductScreen(
            product: product,
          );
        },
      ),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  // =========================================================
  // حذف محصول
  // =========================================================

  Future<void> _deleteProduct(
    dynamic product,
  ) async {
    final int? productId = _toInt(
      product['id'],
    );

    if (productId == null) {
      _showMessage(
        'شناسه محصول پیدا نشد.',
      );

      return;
    }

    final String productName =
        _getProductName(product);

    final bool? confirmed =
        await showDialog<bool>(
 context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'حذف محصول',
          ),
          content: Text(
            'آیا مطمئن هستید که می‌خواهید '
            '«$productName» را حذف کنید؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'انصراف',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'حذف',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _productsApi.deleteProduct(
        productId: productId,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'محصول با موفقیت حذف شد.',
      );

      await _loadProducts();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'حذف محصول با خطا مواجه شد:\n$error',
      );
    }
  }

  // =========================================================
  // تبدیل به int
  // =========================================================

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  // =========================================================
  // نام محصول
  // =========================================================

  String _getProductName(
    dynamic product,
  ) {
    final dynamic name = product['name'];

    if (name == null ||
        name.toString().trim().isEmpty) {
      return 'بدون نام';
    }

    return name.toString();
  }

  // =========================================================
  // قیمت محصول
  // =========================================================

  String _getProductPrice(
    dynamic product,
  ) {
    dynamic price = product['price'];

    if (price == null ||
        price.toString().trim().isEmpty) {
      price = product['regular_price'];
    }

    if (price == null ||
        price.toString().trim().isEmpty) {
      return 'قیمت ثبت نشده';
    }

    final String priceText =
        price.toString();

    return '${_formatNumber(priceText)} تومان';
  }

  // =========================================================
  // فرمت قیمت
  // =========================================================

  String _formatNumber(
    String value,
  ) {
    final String cleanValue =
        value.replaceAll(',', '').trim();

    final double? number =
        double.tryParse(cleanValue);

    if (number == null) {
      return value;
    }

    final String integerValue =
        number.round().toString();

    final StringBuffer result =
        StringBuffer();

    for (int i = 0;
        i < integerValue.length;
        i++) {
      if (i > 0 &&
          (integerValue.length - i) % 3 == 0) {
        result.write(',');
      }

      result.write(integerValue[i]);
    }

    return result.toString();
  }

  // =========================================================
  // موجودی محصول
  // =========================================================

  String _getProductStock(
    dynamic product,
  ) {
    final dynamic stockQuantity =
        product['stock_quantity'];

    if (stockQuantity != null) {
      return 'موجودی: ${stockQuantity.toString()}';
    }

    final dynamic stockStatus =
        product['stock_status'];

    if (stockStatus != null) {
      switch (stockStatus.toString()) {
        case 'instock':
          return 'موجود';

        case 'outofstock':
          return 'ناموجود';
 case 'onbackorder':
          return 'پیش‌فروش';

        default:
          return stockStatus.toString();
      }
    }

    return 'موجودی نامشخص';
  }

  // =========================================================
  // وضعیت محصول
  // =========================================================

  String _getProductStatus(
    dynamic product,
  ) {
    final dynamic status =
        product['status'];

    if (status == null) {
      return 'نامشخص';
    }

    switch (status.toString()) {
      case 'publish':
        return 'منتشر شده';

      case 'pending':
        return 'در انتظار بررسی';

      case 'draft':
        return 'پیش‌نویس';

      case 'private':
        return 'خصوصی';

      default:
        return status.toString();
    }
  }

  // =========================================================
  // رنگ وضعیت
  // =========================================================

  Color _getStatusColor(
    dynamic product,
  ) {
    final dynamic status =
        product['status'];

    switch (status?.toString()) {
      case 'publish':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'draft':
        return Colors.grey;

      case 'private':
        return Colors.blueGrey;

      default:
        return Colors.blue;
    }
  }

  // =========================================================
  // تصویر محصول
  // =========================================================

  String? _getProductImage(
    dynamic product,
  ) {
    final dynamic images =
        product['images'];

    if (images is List &&
        images.isNotEmpty) {
      final dynamic firstImage =
          images.first;

      if (firstImage is Map) {
        final dynamic src =
            firstImage['src'];

        if (src != null &&
            src.toString().isNotEmpty) {
          return src.toString();
        }
      }
    }

    final dynamic image =
        product['image'];

    if (image is String &&
        image.isNotEmpty) {
      return image;
    }

    if (image is Map) {
      final dynamic src =
          image['src'];

      if (src != null &&
          src.toString().isNotEmpty) {
        return src.toString();
      }
    }

    return null;
  }

  // =========================================================
  // نام دسته‌بندی محصول
  // =========================================================

  String _getProductCategoryName(
    dynamic product,
  ) {
    final dynamic categories =
        product['categories'];

    if (categories is List &&
        categories.isNotEmpty) {
      final dynamic firstCategory =
          categories.first;

      if (firstCategory is Map) {
        final dynamic name =
            firstCategory['name'];

        if (name != null &&
            name.toString().isNotEmpty) {
          return name.toString();
        }
      }
    }

    return 'بدون دسته‌بندی';
  }

  // =========================================================
  // آیا محصول در دسته انتخاب شده است؟
  // =========================================================

  bool _productHasCategory(
    dynamic product,
    int categoryId,
  ) {
    final dynamic categories =
        product['categories'];

    if (categories is! List) {
      return false;
    }

    for (final dynamic category
        in categories) {
      if (category is Map) {
        final int? id =
            _toInt(category['id']);

        if (id == categoryId) {
          return true;
        }
      }
    }

    return false;
  }

  // =========================================================
  // محصولات فیلتر شده
  // =========================================================

  List<dynamic> _getFilteredProducts() {
    final String search =
        _searchText.trim().toLowerCase();

    return _products.where(
      (dynamic product) {
        bool matchesSearch = true;
        bool matchesCategory = true;

        // جستجو
        if (search.isNotEmpty) {
          final String name =
              _getProductName(product)
                  .toLowerCase();
 final String id =
              product['id']?.toString() ?? '';

          matchesSearch =
              name.contains(search) ||
              id.contains(search);
        }

        // دسته‌بندی
        if (_selectedCategoryId != null) {
          matchesCategory =
              _productHasCategory(
            product,
            _selectedCategoryId!,
          );
        }

        return matchesSearch &&
            matchesCategory;
      },
    ).toList();
  }

  // =========================================================
  // پیام
  // =========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        duration:
            const Duration(seconds: 4),
      ),
    );
  }

  // =========================================================
  // کارت محصول
  // =========================================================

  Widget _buildProductCard(
    dynamic product,
  ) {
    final String name =
        _getProductName(product);

    final String price =
        _getProductPrice(product);

    final String stock =
        _getProductStock(product);

    final String status =
        _getProductStatus(product);

    final String category =
        _getProductCategoryName(product);

    final Color statusColor =
        _getStatusColor(product);

    final String? imageUrl =
        _getProductImage(product);

    final int? productId =
        _toInt(product['id']);

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // =================================================
            // تصویر
            // =================================================

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(12),
              child: Container(
                width: 90,
                height: 90,
                color:
                    Colors.grey.shade100,
                child:
                    imageUrl != null &&
                            imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Icon(
                                Icons
                                    .image_not_supported_outlined,
                                size: 36,
                                color: Colors
                                    .grey
                                    .shade500,
                              );
                            },
                          )
                        : Icon(
                            Icons
                                .image_outlined,
                            size: 36,
                            color: Colors
                                .grey
                                .shade500,
                          ),
              ),
            ),

            const SizedBox(width: 12),

            // =================================================
            // اطلاعات
            // =================================================
 Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Row(
                    children: [
                      Icon(
                        Icons
                            .payments_outlined,
                        size: 16,
                        color:
                            Colors.blue.shade700,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Expanded(
                        child: Text(
                          price,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                            color: Colors
                                .blue
                                .shade700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Icon(
                        Icons
                            .inventory_2_outlined,
                        size: 16,
                        color: Colors
                            .grey
                            .shade700,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Expanded(
                        child: Text(
                          stock,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey
                                .shade700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration:
                            BoxDecoration(
                          color: statusColor
                              .withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(8),
                        ),
                        child: Text(
                          status,
                          style:
                              TextStyle(
                            fontSize: 11,
                            color:
                                statusColor,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 6,
                      ),
 Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
 overflow:
                              TextOverflow.ellipsis,
                          style:
                              TextStyle(
                            fontSize: 11,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (productId != null) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'ID: $productId',
                      style:
                          TextStyle(
                        fontSize: 10,
                        color: Colors
                            .grey
                            .shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // =================================================
            // منوی سه‌نقطه
            // =================================================

            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editProduct(product);
                }

                if (value == 'delete') {
                  _deleteProduct(product);
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'ویرایش محصول',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .delete_outline,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'حذف محصول',
                          style:
                              TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // فیلترها
  // =========================================================

  Widget _buildFilters() {
    final List<dynamic> filteredProducts =
        _getFilteredProducts();

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        4,
      ),
      child: Column(
        children: [
          // =================================================
          // جستجو
          // =================================================

          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
            decoration:
                InputDecoration(
              hintText:
                  'جستجوی نام یا شناسه محصول...',
              prefixIcon:
                  const Icon(
                Icons.search,
              ),
              suffixIcon:
                  _searchText.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController
                                .clear();
 setState(() {
                              _searchText = '';
                            });
                          },
                          icon:
                              const Icon(
                            Icons.clear,
                          ),
                        )
                      : null,
              filled: true,
              fillColor:
                  Colors.grey.shade100,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // =================================================
          // دسته‌بندی
          // =================================================

          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade100,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child:
                      DropdownButtonHideUnderline(
                    child:
                        DropdownButton<int?>(
                      value:
                          _selectedCategoryId,
                      isExpanded: true,
                      hint: const Text(
                        'همه دسته‌بندی‌ها',
                      ),
                      items: [
                        const DropdownMenuItem<
                            int?>(
                          value: null,
                          child: Text(
                            'همه دسته‌بندی‌ها',
                          ),
                        ),
                        ..._categories
                            .map(
                          (category) {
                            final int? id =
                                _toInt(
                              category['id'],
                            );

                            final String name =
                                category['name']
                                        ?.toString() ??
                                    'بدون نام';

                            return DropdownMenuItem<
                                int?>(
                              value: id,
                              child: Text(
                                name,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
                      onChanged:
                          (value) {
                        setState(() {
                          _selectedCategoryId =
                              value;
                        });
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.blue.shade50,
 borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Text(
                  '${filteredProducts.length} محصول',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // صفحه
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'محصولات من',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed:
                _isLoading
                    ? null
                    : () async {
                        await _loadProducts();
                        await _loadCategories();
                      },
            icon:
                const Icon(
              Icons.refresh,
            ),
            tooltip:
                'بروزرسانی محصولات',
          ),
        ],
      ),

      // =================================================
      // افزودن محصول
      // =================================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _isLoading
                ? null
                : _addProduct,
        icon:
            const Icon(
          Icons.add,
        ),
        label:
            const Text(
          'افزودن محصول',
        ),
      ),

      // =================================================
      // بدنه
      // =================================================

      body:
          RefreshIndicator(
        onRefresh: () async {
          await _loadProducts();
          await _loadCategories();
        },
        child:
            _buildBody(),
      ),
    );
  }

  // =========================================================
  // ساخت بدنه
  // =========================================================

  Widget _buildBody() {
    if (_isLoading &&
        _products.isEmpty) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    // =================================================
    // خطا
    // =================================================

    if (_errorMessage != null &&
        _products.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 100,
          ),
          Icon(
            Icons.error_outline,
            size: 64,
            color:
                Colors.red.shade400,
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'دریافت محصولات با خطا مواجه شد.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            _errorMessage!,
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton.icon(
            onPressed:
                _loadProducts,
            icon:
                const Icon(
              Icons.refresh,
            ),
            label:
                const Text(
              'تلاش دوباره',
            ),
          ),
        ],
      );
    }
 final List<dynamic>
        filteredProducts =
        _getFilteredProducts();

    // =================================================
    // نتیجه‌ای برای فیلتر وجود ندارد
    // =================================================

    if (filteredProducts.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 70,
          ),
          Icon(
            _products.isEmpty
                ? Icons.inventory_2_outlined
                : Icons.search_off_outlined,
            size: 80,
            color:
                Colors.grey.shade400,
          ),
          const SizedBox(
            height: 20,
          ),
          Text(
            _products.isEmpty
                ? 'هنوز محصولی ثبت نشده است.'
                : 'محصولی پیدا نشد.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            _products.isEmpty
                ? 'برای شروع، اولین محصول خود را اضافه کنید.'
                : 'عبارت جستجو یا فیلتر دسته‌بندی را تغییر دهید.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.grey.shade600,
            ),
          ),
          if (_products.isEmpty) ...[
            const SizedBox(
              height: 24,
            ),
            ElevatedButton.icon(
              onPressed:
                  _addProduct,
              icon:
                  const Icon(
                Icons.add,
              ),
              label:
                  const Text(
                'افزودن محصول',
              ),
            ),
          ],
        ],
      );
    }

    // =================================================
    // لیست محصولات
    // =================================================

    return Stack(
      children: [
        ListView.builder(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            100,
          ),
          itemCount:
              filteredProducts.length + 1,
          itemBuilder:
              (context, index) {
            if (index == 0) {
              return _buildFilters();
            }

            final dynamic product =
                filteredProducts[
                    index - 1];

            return _buildProductCard(
              product,
            );
          },
        ),

        // =================================================
        // لودینگ هنگام بروزرسانی
        // =================================================
if (_isLoading &&
            _products.isNotEmpty)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child:
                LinearProgressIndicator(),
          ),

        // =================================================
        // لودینگ دسته‌بندی
        // =================================================

        if (_isLoadingCategories)
          const Positioned(
            top: 0,
            right: 0,
            child:
                Padding(
              padding:
                  EdgeInsets.all(8),
              child:
                  SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}