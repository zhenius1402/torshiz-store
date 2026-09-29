 import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../services/api/products_api.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({
    super.key,
  });

  @override
  State<AddProductScreen> createState() {
    return _AddProductScreenState();
  }
}

class _AddProductScreenState
    extends State<AddProductScreen> {
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

  XFile? _selectedImage;

  Uint8List? _selectedImageBytes;

  List<dynamic> _categories = [];

  bool _isLoadingCategories = true;

  String? _categoryError;

  int? _selectedCategoryId;

  bool _isVirtual = false;

  bool _isDownloadable = false;

  @override
  void initState() {
    super.initState();

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
  // دریافت دسته‌بندی‌ها
  // =========================================================

  Future<void> _loadCategories() async {
    try {
      final List<dynamic> categories =
          await _productsApi.getCategories();

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        _categoryError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCategories = false;
        _categoryError = error.toString();
      });
    }
  }

  // =========================================================
  // انتخاب و فشرده‌سازی تصویر
  // =========================================================

  Future<void> _pickProductImage() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final Uint8List originalBytes =
          await image.readAsBytes();

      final img.Image? decodedImage =
          img.decodeImage(originalBytes);

      if (decodedImage == null) {
        _showMessage(
          'تصویر قابل خواندن نیست.',
        );

        return;
      }

      final int width =
          decodedImage.width;

      final int height =
          decodedImage.height;

      // حداقل اندازه تصویر
      if (width < 500 || height < 500) {
        _showMessage(
          'اندازه تصویر خیلی کوچک است. '
          'لطفاً تصویری حداقل ۵۰۰ در ۵۰۰ انتخاب کنید.',
        );

        return;
      }

      // تغییر اندازه به 1200 × 1200
      final img.Image resizedImage =
          img.copyResize(
        decodedImage,
        width: 1200,
        height: 1200,
      );

      // تبدیل به JPG
      final Uint8List compressedBytes =
          Uint8List.fromList(
        img.encodeJpg(
          resizedImage,
          quality: 82,
        ),
      );

      // حداکثر 500KB
      if (compressedBytes.length >
          500 * 1024) {
        _showMessage(
          'حجم تصویر بیشتر از ۵۰۰ کیلوبایت است. '
          'لطفاً تصویر ساده‌تری انتخاب کنید.',
        );

        return;
      }

      if (!mounted) {
        return;
      }
 setState(() {
        _selectedImage = image;
        _selectedImageBytes = compressedBytes;
      });
    } catch (error) {
      _showMessage(
        'انتخاب تصویر با خطا مواجه شد:\n$error',
      );
    }
  }

  // =========================================================
  // حذف تصویر انتخاب‌شده
  // =========================================================

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  // =========================================================
  // ثبت محصول
  // =========================================================

  Future<void> _submitProduct() async {
    // بررسی فرم
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // بررسی تصویر
    if (_selectedImageBytes == null) {
      _showMessage(
        'لطفاً تصویر محصول را انتخاب کنید.',
      );

      return;
    }

    // بررسی دسته‌بندی
    if (_selectedCategoryId == null) {
      _showMessage(
        'لطفاً دسته‌بندی محصول را انتخاب کنید.',
      );

      return;
    }

    // قیمت اصلی
    final double? regularPrice =
        double.tryParse(
      _priceController.text.trim(),
    );

    if (regularPrice == null) {
      _showMessage(
        'قیمت محصول صحیح نیست.',
      );

      return;
    }

    // قیمت فروش ویژه
    double? salePrice;

    if (_salePriceController.text
        .trim()
        .isNotEmpty) {
      salePrice = double.tryParse(
        _salePriceController.text.trim(),
      );

      if (salePrice == null) {
        _showMessage(
          'قیمت فروش ویژه صحیح نیست.',
        );

        return;
      }
    }

    // موجودی
    final int? stockQuantity =
        int.tryParse(
      _stockController.text.trim(),
    );

    if (stockQuantity == null) {
      _showMessage(
        'موجودی محصول صحیح نیست.',
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // -----------------------------------------------------
      // مرحله 1: آپلود تصویر
      // -----------------------------------------------------

      final int imageId =
          await _productsApi.uploadProductImage(
        imageBytes: _selectedImageBytes!,
        fileName:
            'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
      );

      // -----------------------------------------------------
      // مرحله 2: ثبت محصول
      // -----------------------------------------------------

      await _productsApi.createProduct(
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim(),
        regularPrice: regularPrice,
        salePrice: salePrice,
        stockQuantity: stockQuantity,
        categoryId: _selectedCategoryId!,
        imageId: imageId,
        virtualProduct: _isVirtual,
        downloadableProduct: _isDownloadable,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'محصول با موفقیت در سایت ثبت شد.',
      );

      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (mounted) {
        // true به صفحه محصولات من برمی‌گردد
        // تا لیست محصولات دوباره دریافت شود.
        Navigator.pop(context, true);
      }
    } catch (error) {
      _showMessage(
        'ثبت محصول با خطا مواجه شد:\n$error',
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
  // نمایش پیام
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }
 // =========================================================
  // استایل فیلدها
  // =========================================================

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.blue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  // =========================================================
  // انتخاب تصویر
  // =========================================================

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _isLoading
              ? null
              : _pickProductImage,
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            clipBehavior:
                Clip.antiAlias,
            child: _selectedImageBytes == null
                ? Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons
                            .add_photo_alternate_outlined,
                        size: 56,
                        color:
                            Colors.grey.shade600,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      const Text(
                        'انتخاب تصویر محصول',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        '۱۲۰۰×۱۲۰۰ پیکسل - حداکثر ۵۰۰ کیلوبایت',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Image.memory(
                    _selectedImageBytes!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        if (_selectedImageBytes != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
 onPressed: _isLoading
                ? null
                : _removeSelectedImage,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            label: const Text(
              'حذف تصویر',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================
  // دسته‌بندی
  // =========================================================

  Widget _buildCategoryField() {
    if (_isLoadingCategories) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_categoryError != null) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Text(
            'دریافت دسته‌بندی‌ها ناموفق بود.',
            style: TextStyle(
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadCategories,
            child: const Text(
              'تلاش دوباره',
            ),
          ),
        ],
      );
    }

    if (_categories.isEmpty) {
      return const Text(
        'هیچ دسته‌بندی‌ای در وردپرس پیدا نشد.',
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCategoryId,
      decoration: _inputDecoration(
        label: 'دسته‌بندی محصول',
      ),
      items: _categories.map(
        (category) {
          return DropdownMenuItem<int>(
            value: category['id'] as int,
            child: Text(
              category['name']?.toString() ??
                  'بدون نام',
            ),
          );
        },
      ).toList(),
      onChanged: _isLoading
          ? null
          : (value) {
              setState(() {
                _selectedCategoryId = value;
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
  // رابط کاربری
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'افزودن محصول',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'افزودن محصول جدید',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'اطلاعات محصول را وارد کنید.',
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 24),

                // تصویر
                _buildImagePicker(),

                const SizedBox(height: 24),

                // نام محصول
                TextFormField(
                  controller:
                      _nameController,
                  enabled: !_isLoading,
                  decoration:
                      _inputDecoration(
                    label: 'نام محصول',
 hint:
                        'مثلاً آموزش طراحی سایت',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'نام محصول را وارد کنید';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // توضیحات
                TextFormField(
                  controller:
                      _descriptionController,
                  enabled: !_isLoading,
                  maxLines: 5,
                  decoration:
                      _inputDecoration(
                    label: 'توضیحات محصول',
                    hint:
                        'توضیحات کامل محصول',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'توضیحات را وارد کنید';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // قیمت
                TextFormField(
                  controller:
                      _priceController,
                  enabled: !_isLoading,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      _inputDecoration(
                    label: 'قیمت محصول',
                    hint: 'قیمت به تومان',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'قیمت را وارد کنید';
                    }

                    if (double.tryParse(
                          value.trim(),
                        ) ==
                        null) {
                      return 'قیمت باید عددی باشد';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // قیمت فروش ویژه
                TextFormField(
                  controller:
                      _salePriceController,
                  enabled: !_isLoading,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      _inputDecoration(
                    label: 'قیمت فروش ویژه',
                    hint: 'اختیاری',
                  ),
                ),

                const SizedBox(height: 16),

                // موجودی
                TextFormField(
                  controller:
                      _stockController,
                  enabled: !_isLoading,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      _inputDecoration(
                    label: 'موجودی محصول',
                    hint: 'مثلاً 10',
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
                      return 'موجودی باید عدد صحیح باشد';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // دسته‌بندی
                _buildCategoryField(),

                const SizedBox(height: 12),

                // محصول مجازی
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
 title: const Text(
                    'محصول مجازی است',
                  ),
                  subtitle: const Text(
                    'برای خدمات و محصولات غیر فیزیکی',
                  ),
                  value: _isVirtual,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _isVirtual = value;
                          });
                        },
                ),

                // محصول دانلودی
SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  title: const Text(
                    'محصول دانلودی است',
                  ),
                  subtitle: const Text(
                    'برای فایل‌های قابل دانلود',
                  ),
                  value: _isDownloadable,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _isDownloadable =
                                value;
                          });
                        },
                ),

                const SizedBox(height: 24),

                // دکمه ثبت
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : _submitProduct,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .add_shopping_cart,
                          ),
                    label: Text(
                      _isLoading
                          ? 'در حال ثبت محصول...'
                          : 'ثبت نهایی محصول',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.blue,
                      foregroundColor:
                          Colors.white,
                      disabledBackgroundColor:
                          Colors.blue.shade200,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}