import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../services/api/products_api.dart';

class EditProductScreen extends StatefulWidget {
  final dynamic product;

  const EditProductScreen({
    super.key,
    required this.product,
  });

  @override
  State<EditProductScreen> createState() {
    return _EditProductScreenState();
  }
}

class _EditProductScreenState
    extends State<EditProductScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final ImagePicker _imagePicker =
      ImagePicker();

  final ProductsApi _productsApi =
      ProductsApi();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController
      _descriptionController =
      TextEditingController();

  final TextEditingController _priceController =
      TextEditingController();

  final TextEditingController
      _salePriceController =
      TextEditingController();

  final TextEditingController _stockController =
      TextEditingController();

  bool _isLoading = false;
  bool _isLoadingCategories = true;

  String? _categoryError;

  List<dynamic> _categories = [];

  int? _selectedCategoryId;

  bool _isVirtual = false;
  bool _isDownloadable = false;

  Uint8List? _selectedImageBytes;

  String? _currentImageUrl;

  int? _productId;

  @override
  void initState() {
    super.initState();

    _loadProductData();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();

    super.dispose();
  }

  // =========================================================
  // دریافت اطلاعات محصول
  // =========================================================

  void _loadProductData() {
    final dynamic product = widget.product;

    print('====================================');
    print('EDIT PRODUCT DATA');
    print('PRODUCT: $product');
    print(
      'PRODUCT CATEGORY ID: '
      '${product['category_id']}',
    );
    print(
      'PRODUCT CATEGORIES: '
      '${product['categories']}',
    );
    print('====================================');

    _productId = _toInt(
      product['id'],
    );

    _nameController.text =
        product['name']?.toString() ?? '';

    _descriptionController.text =
        product['description']?.toString() ?? '';

    final String price =
        product['regular_price']
                    ?.toString()
                    .isNotEmpty ==
                true
            ? product['regular_price']
                .toString()
            : product['price']
                    ?.toString() ??
                '';

    _priceController.text = price;

    _salePriceController.text =
        product['sale_price']
                ?.toString() ??
            '';

    _stockController.text =
        product['stock_quantity']
                ?.toString() ??
            '';

    _isVirtual =
        _toBool(product['virtual']);

    _isDownloadable =
        _toBool(
      product['downloadable'],
    );

    _currentImageUrl =
        _getProductImageUrl(product);

    // دریافت دسته‌بندی محصول
    _selectedCategoryId =
        _getProductCategoryId(product);

    print(
      'SELECTED CATEGORY ID: '
      '$_selectedCategoryId',
    );

    if (mounted) {
      setState(() {});
    }
  }

  // =========================================================
  // دریافت دسته‌بندی‌ها
  // =========================================================

  Future<void> _loadCategories() async {
    try {
      final List<dynamic> categories =
          await _productsApi.getCategories();

      print('====================================');
      print('EDIT CATEGORIES');
      print(categories);
      print(
        'CURRENT CATEGORY: '
        '$_selectedCategoryId',
      );
      print('====================================');

      if (!mounted) return;
 setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        _categoryError = null;
      });

      final bool exists =
          _categories.any(
        (category) {
          return _toInt(
                category['id'],
              ) ==
              _selectedCategoryId;
        },
      );

      if (!exists) {
        print(
          'SELECTED CATEGORY NOT FOUND',
        );

        setState(() {
          _selectedCategoryId = null;
        });
      }
    } catch (error) {
      print(
        'LOAD CATEGORIES ERROR: $error',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingCategories = false;
        _categoryError =
            error.toString();
      });
    }
  }

  // =========================================================
  // انتخاب تصویر
  // =========================================================

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return;
      }

      final Uint8List originalBytes =
          await pickedFile.readAsBytes();

      final img.Image? originalImage =
          img.decodeImage(
        originalBytes,
      );

      if (originalImage == null) {
        _showMessage(
          'تصویر قابل خواندن نیست',
        );
        return;
      }

      final int width =
          originalImage.width;

      final int height =
          originalImage.height;

      if (width < 500 || height < 500) {
        _showMessage(
          'حداقل ابعاد تصویر باید 500×500 باشد',
        );
        return;
      }

      img.Image resizedImage =
          originalImage;

      if (width > 1200 ||
          height > 1200) {
        if (width >= height) {
          resizedImage =
              img.copyResize(
            originalImage,
            width: 1200,
          );
        } else {
          resizedImage =
              img.copyResize(
            originalImage,
            height: 1200,
          );
        }
      }

      int quality = 82;

      Uint8List compressedBytes =
          Uint8List.fromList(
        img.encodeJpg(
          resizedImage,
          quality: quality,
        ),
      );

      while (
          compressedBytes.length >
              500 * 1024 &&
          quality > 30) {
        quality -= 5;

        compressedBytes =
            Uint8List.fromList(
          img.encodeJpg(
            resizedImage,
            quality: quality,
          ),
        );
      }

      if (compressedBytes.length >
          500 * 1024) {
        _showMessage(
          'حجم تصویر بعد از فشرده‌سازی هنوز بیشتر از 500KB است',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImageBytes =
            compressedBytes;
      });

      print(
        'EDIT IMAGE SIZE: '
        '${compressedBytes.length} bytes',
      );
    } catch (error) {
      _showMessage(
        'خطا در انتخاب تصویر:\n$error',
      );
    }
  }

  // =========================================================
  // ویرایش محصول
  // =========================================================

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_productId == null) {
      _showMessage(
        'شناسه محصول پیدا نشد',
      );
      return;
    }

    if (_selectedCategoryId == null) {
      _showMessage(
        'لطفاً دسته‌بندی محصول را انتخاب کنید',
      );
      return;
    }

    final double? regularPrice =
        double.tryParse(
      _priceController.text
          .trim()
          .replaceAll(',', ''),
    );

    if (regularPrice == null) {
      _showMessage(
        'قیمت محصول معتبر نیست',
      );
      return;
    }

    double? salePrice;

    if (_salePriceController.text
        .trim()
        .isNotEmpty) {
      salePrice = double.tryParse(
        _salePriceController.text
            .trim()
            .replaceAll(',', ''),
      );
 if (salePrice == null) {
        _showMessage(
          'قیمت ویژه معتبر نیست',
        );
        return;
      }
    }

    final int? stockQuantity =
        int.tryParse(
      _stockController.text.trim(),
    );

    if (stockQuantity == null) {
      _showMessage(
        'موجودی محصول معتبر نیست',
      );
      return;
    }

    print('====================================');
    print('FINAL EDIT DATA');
    print(
      'PRODUCT ID: $_productId',
    );
    print(
      'CATEGORY ID SENT: '
      '$_selectedCategoryId',
    );
    print(
      'NAME: '
      '${_nameController.text.trim()}',
    );
    print(
      'PRICE: $regularPrice',
    );
    print(
      'SALE PRICE: $salePrice',
    );
    print(
      'STOCK: $stockQuantity',
    );
    print('====================================');

    setState(() {
      _isLoading = true;
    });

    try {
      int? newImageId;

      // =====================================================
      // اگر عکس جدید انتخاب شده باشد
      // =====================================================

      if (_selectedImageBytes != null) {
        print(
          'UPLOADING NEW EDIT PRODUCT IMAGE...',
        );

        newImageId =
            await _productsApi
                .uploadProductImage(
          imageBytes:
              _selectedImageBytes!,
          fileName:
              'product_edit_${_productId!}.jpg',
          mimeType: 'image/jpeg',
        );

        print(
          'NEW IMAGE ID: $newImageId',
        );
      }

      // =====================================================
      // ارسال اطلاعات ویرایش
      // =====================================================

      print(
        '====================================',
      );

      print(
        'SENDING UPDATE',
      );

      print(
        'CATEGORY ID SENT TO API: '
        '$_selectedCategoryId',
      );

      print(
        '====================================',
      );

      final Map<String, dynamic>
          result =
          await _productsApi
              .updateProduct(
        productId: _productId!,
        name:
            _nameController.text.trim(),
        description:
            _descriptionController.text
                .trim(),
        regularPrice: regularPrice,
        salePrice: salePrice,
        stockQuantity: stockQuantity,
        categoryId:
            _selectedCategoryId!,
        imageId: newImageId,
        virtualProduct: _isVirtual,
        downloadableProduct:
            _isDownloadable,
      );

      // =====================================================
      // نتیجه
      // =====================================================

      print(
        '====================================',
      );

      print(
        'UPDATE SUCCESS',
      );

      print(
        'UPDATE RESULT: $result',
      );

      print(
        'CATEGORY AFTER UPDATE: '
        '${result['categories']}',
      );

      print(
        '====================================',
      );

      if (!mounted) return;

      _showMessage(
        'محصول با موفقیت ویرایش شد',
      );

      await Future.delayed(
        const Duration(
          seconds: 1,
        ),
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      print(
        '====================================',
      );

      print(
        'UPDATE PRODUCT ERROR',
      );

      print(error);

      print(
        '====================================',
      );

      if (!mounted) return;

      _showMessage(
        'ویرایش محصول با خطا مواجه شد:\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // پیدا کردن دسته‌بندی محصول
  // =========================================================

  int? _getProductCategoryId(
    dynamic product,
  ) {
    // اول category_id
    final dynamic directCategoryId =
        product['category_id'];
 final int? directId =
        _toInt(
      directCategoryId,
    );

    if (directId != null) {
      print(
        'CATEGORY FROM category_id: '
        '$directId',
      );

      return directId;
    }

    // بعد categories
    final dynamic categories =
        product['categories'];

    if (categories is List &&
        categories.isNotEmpty) {
      for (
        final dynamic category
        in categories
      ) {
        if (category is Map) {
          final int? id =
              _toInt(
            category['id'],
          );

          if (id != null) {
            print(
              'CATEGORY FROM categories: '
              '$id',
            );

            return id;
          }
        }
      }
    }

    return null;
  }

  // =========================================================
  // تصویر محصول
  // =========================================================

  String? _getProductImageUrl(
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
  // تبدیل به bool
  // =========================================================

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final String text =
        value?.toString().toLowerCase() ??
            '';

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  // =========================================================
  // پیام
  // =========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ویرایش محصول',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
                const EdgeInsets.all(16),
            children: [
              _buildImageSection(),

              const SizedBox(
                height: 20,
              ),

              TextFormField(
                controller:
                    _nameController,
                enabled: !_isLoading,
                decoration:
                    _inputDecoration(
                  label: 'نام محصول',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'نام محصول را وارد کنید';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),
 TextFormField(
                controller:
                    _descriptionController,
                enabled: !_isLoading,
                maxLines: 5,
                decoration:
                    _inputDecoration(
                  label: 'توضیحات محصول',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'توضیحات را وارد کنید';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              _buildCategoryDropdown(),

              const SizedBox(
                height: 16,
              ),

              TextFormField(
                controller:
                    _priceController,
                enabled: !_isLoading,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    _inputDecoration(
                  label: 'قیمت',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'قیمت را وارد کنید';
                  }

                  if (double.tryParse(
                        value
                            .trim()
                            .replaceAll(
                              ',',
                              '',
                            ),
                      ) ==
                      null) {
                    return 'قیمت معتبر نیست';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              TextFormField(
                controller:
                    _salePriceController,
                enabled: !_isLoading,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    _inputDecoration(
                  label: 'قیمت ویژه',
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              TextFormField(
                controller:
                    _stockController,
                enabled: !_isLoading,
                keyboardType:
                    TextInputType.number,
                decoration:
                    _inputDecoration(
                  label: 'موجودی',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'موجودی را وارد کنید';
                  }

                  if (int.tryParse(
                        value.trim(),
                      ) ==
                      null) {
                    return 'موجودی معتبر نیست';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 12,
              ),

              SwitchListTile(
                value: _isVirtual,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _isVirtual =
                              value;
                        });
                      },
                title: const Text(
                  'محصول مجازی',
                ),
              ),
 SwitchListTile(
                value:
                    _isDownloadable,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _isDownloadable =
                              value;
                        });
                      },
                title: const Text(
                  'محصول دانلودی',
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              SizedBox(
                height: 52,
                child:
                    ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _updateProduct,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'ذخیره تغییرات',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // بخش تصویر
  // =========================================================

  Widget _buildImageSection() {
    Widget imageWidget;

    if (_selectedImageBytes !=
        null) {
      imageWidget =
          Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
      );
    } else if (_currentImageUrl !=
            null &&
        _currentImageUrl!.isNotEmpty) {
      imageWidget =
          Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        errorBuilder:
            (
          context,
          error,
          stackTrace,
        ) {
          return const Icon(
            Icons.image_not_supported,
            size: 60,
          );
        },
      );
    } else {
      imageWidget = const Icon(
        Icons.image,
        size: 60,
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 220,
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color:
                  Colors.grey.shade300,
            ),
          ),
          clipBehavior:
              Clip.antiAlias,
          child: imageWidget,
        ),

        const SizedBox(
          height: 12,
        ),

        OutlinedButton.icon(
          onPressed: _isLoading
              ? null
              : _pickImage,
          icon: const Icon(
            Icons.photo_library,
          ),
          label: const Text(
            'تغییر تصویر محصول',
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        const Text(
          'حداقل 500×500 و حداکثر 500KB',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // دسته‌بندی
  // =========================================================

  Widget _buildCategoryDropdown() {
    if (_isLoadingCategories) {
      return InputDecorator(
        decoration:
            _inputDecoration(
          label:
              'دسته‌بندی محصول',
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(
              width: 12,
            ),
            Text(
              'در حال دریافت دسته‌بندی‌ها...',
            ),
          ],
        ),
      );
    }
 if (_categoryError != null) {
      return InputDecorator(
        decoration:
            _inputDecoration(
          label:
              'دسته‌بندی محصول',
        ),
        child: Text(
          'خطا در دریافت دسته‌بندی‌ها',
          style: TextStyle(
            color:
                Colors.red.shade700,
          ),
        ),
      );
    }

    final bool
        selectedCategoryExists =
        _categories.any(
      (category) {
        return _toInt(
              category['id'],
            ) ==
            _selectedCategoryId;
      },
    );

    final int? dropdownValue =
        selectedCategoryExists
            ? _selectedCategoryId
            : null;

    return DropdownButtonFormField<int>(
      initialValue: dropdownValue,
      decoration:
          _inputDecoration(
        label:
            'دسته‌بندی محصول',
      ),
      items: _categories
          .map<
              DropdownMenuItem<int>?>(
        (category) {
          final int? categoryId =
              _toInt(
            category['id'],
          );

          if (categoryId == null) {
            return null;
          }

          return DropdownMenuItem<int>(
            value: categoryId,
            child: Text(
              category['name']
                      ?.toString() ??
                  'بدون نام',
            ),
          );
        },
      )
          .whereType<
              DropdownMenuItem<int>>()
          .toList(),
      onChanged: _isLoading
          ? null
          : (value) {
              print(
                'CATEGORY CHANGED BY USER: '
                '$value',
              );

              setState(() {
                _selectedCategoryId =
                    value;
              });
            },
      validator: (value) {
        if (value == null) {
          return 'دسته‌بندی را انتخاب کنید';
        }

        return null;
      },
    );
  }

  // =========================================================
  // ظاهر فیلدها
  // =========================================================

  InputDecoration _inputDecoration({
    required String label,
  }) {
    return InputDecoration(
      labelText: label,
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
    );
  }
}