import 'package:flutter/material.dart';

import '../../services/api/auth_api.dart';

class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState
    extends State<VendorRegistrationScreen> {
  // =========================================================
  // رنگ‌ها
  // =========================================================

  static const Color primary = Color(0xff1565c0);
  static const Color primaryDark = Color(0xff0d47a1);
  static const Color accent = Color(0xffc9a227);
  static const Color background = Color(0xfff5f7fb);
  static const Color textDark = Color(0xff172033);
  static const Color textGrey = Color(0xff737d8c);
  static const Color borderColor = Color(0xffe1e7ef);

  // =========================================================
  // Form
  // =========================================================

  final _formKey = GlobalKey<FormState>();

  // =========================================================
  // اطلاعات شخصی
  // =========================================================

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();

  // =========================================================
  // اطلاعات فروشگاه
  // =========================================================

  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();

  // =========================================================
  // توضیحات
  // =========================================================

  final _descriptionController = TextEditingController();

  // =========================================================
  // رمز عبور
  // =========================================================

  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  // =========================================================
  // API
  // =========================================================

  final WordPressAuthService _authService =
      WordPressAuthService();

  // =========================================================
  // مرحله
  // =========================================================

  int _currentStep = 0;

  bool _isLoading = false;
  bool _loadingRegistrationData = true;

  // =========================================================
  // نمایش رمز
  // =========================================================

  bool _showPassword = false;
  bool _showRepeatPassword = false;

  // =========================================================
  // شهرها
  // =========================================================

  final List<String> _cities = [
    'کاشمر',
    'خلیل‌آباد',
    'بردسکن',
  ];

  String? _selectedCity;

  // =========================================================
  // دسته‌بندی
  // =========================================================

  int? _selectedCategoryId;
  int? _selectedSubcategoryId;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subcategories = [];

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _loadRegistrationData();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();

    _storeNameController.dispose();
    _addressController.dispose();

    _descriptionController.dispose();

    _passwordController.dispose();
    _repeatPasswordController.dispose();

    super.dispose();
  }

  // =========================================================
  // تبدیل امن ID
  // =========================================================

  int? _parseId(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return int.tryParse(text);
  }

  // =========================================================
  // تبدیل Map
  // =========================================================

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  // =========================================================
  // نام آیتم
  // =========================================================

  String _getItemName(Map<String, dynamic> item) {
    final possibleNames = [
      item['name'],
      item['title'],
      item['label'],
      item['term_name'],
    ];

    for (final value in possibleNames) {
      if (value != null) {
        final text = value.toString().trim();

        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    return '';
  }

  // =========================================================
  // استخراج لیست از یک کلید
  // =========================================================

  List<Map<String, dynamic>> _extractList(
    dynamic raw,
  ) {
    final result = <Map<String, dynamic>>[];

    if (raw is! List) {
      return result;
    }

    for (final item in raw) {
      final map = _toMap(item);

      if (map == null) {
        continue;
      }

      final id = _parseId(map['id']);
      final name = _getItemName(map);

      if (id == null || name.isEmpty) {
        continue;
      }

      result.add({
        ...map,
        'id': id,
        'name': name,
      });
    }

    return result;
  }

  // =========================================================
  // استخراج زیر دسته از دسته
  // =========================================================

  List<Map<String, dynamic>> _extractSubcategories(
    Map<String, dynamic> category,
  ) {
    /*
     * اول children
     */
    final children = _extractList(
      category['children'],
    );

    if (children.isNotEmpty) {
      return children;
    }

    /*
     * سپس subcategories
     */
    final subcategories = _extractList(
      category['subcategories'],
    );

    if (subcategories.isNotEmpty) {
      return subcategories;
    }

    /*
     * سپس items
     */
    final items = _extractList(
      category['items'],
    );

    if (items.isNotEmpty) {
      return items;
    }

    /*
     * سپس childs
     */
    final childs = _extractList(
      category['childs'],
    );

    if (childs.isNotEmpty) {
      return childs;
    }

    return [];
  }

  // =========================================================
  // دریافت اطلاعات ثبت‌نام
  // =========================================================

  Future<void> _loadRegistrationData() async {
    try {
      final result =
          await _authService.getVendorRegistrationData();

      if (!mounted) return;

      debugPrint('============================');
      debugPrint('REGISTRATION DATA RESULT');
      debugPrint(result.toString());
      debugPrint('============================');

      final categories =
          _extractCategoriesFromResponse(result);

      debugPrint('============================');
      debugPrint(
        'NORMALIZED CATEGORIES: ${categories.length}',
      );

      for (final category in categories) {
        final children =
            _extractSubcategories(category);

        debugPrint(
          'CATEGORY => '
          '${category['id']} | '
          '${category['name']} | '
          'SUBCATEGORIES => ${children.length}',
        );

        for (final child in children) {
          debugPrint(
            '   SUB => '
            '${child['id']} | '
            '${child['name']}',
          );
        }
      }

      debugPrint('============================');

      setState(() {
        _categories = categories;
        _loadingRegistrationData = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingRegistrationData = false;
      });

      _showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // =========================================================
  // استخراج دسته‌ها از پاسخ API
  // =========================================================

  List<Map<String, dynamic>> _extractCategoriesFromResponse(
    Map<String, dynamic> response,
  ) {
    /*
     * حالت اول:
     *
     * {
     *   categories: [...]
     * }
     */

    final rawCategories = response['categories'];

    final categories =
        _extractList(rawCategories);

    if (categories.isNotEmpty) {
      return categories.map((category) {
        final subcategories =
            _extractSubcategories(category);

        return {
          ...category,
          'children': subcategories,
        };
      }).toList();
    }

    /*
     * حالت دوم:
     *
     * ممکن است API اطلاعات را داخل data برگرداند.
     */

    final data = _toMap(
      response['data'],
    );

    if (data != null) {
      final dataCategories =
          _extractList(
        data['categories'],
      );

      if (dataCategories.isNotEmpty) {
        return dataCategories.map((category) {
          final subcategories =
              _extractSubcategories(category);

          return {
            ...category,
            'children': subcategories,
          };
        }).toList();
      }
    }

    return [];
  }

  // =========================================================
  // انتخاب دسته‌بندی
  // =========================================================

  void _onCategoryChanged(int? categoryId) {
    debugPrint('============================');
    debugPrint(
      'CATEGORY CHANGED: $categoryId',
    );

    if (categoryId == null) {
      setState(() {
        _selectedCategoryId = null;
        _selectedSubcategoryId = null;
        _subcategories = [];
      });

      debugPrint(
        'CATEGORY CLEARED',
      );
      debugPrint('============================');

      return;
    }

    Map<String, dynamic>? selectedCategory;

    for (final category in _categories) {
      final id = _parseId(
        category['id'],
      );

      if (id == categoryId) {
        selectedCategory = category;
        break;
      }
    }

    if (selectedCategory == null) {
      setState(() {
        _selectedCategoryId = categoryId;
        _selectedSubcategoryId = null;
        _subcategories = [];
      });

      debugPrint(
        'CATEGORY NOT FOUND',
      );
      debugPrint('============================');

      return;
    }

    final children =
        _extractSubcategories(
      selectedCategory,
    );

    debugPrint(
      'SELECTED CATEGORY: '
      '${selectedCategory['name']}',
    );

    debugPrint(
      'SUBCATEGORIES COUNT: ${children.length}',
    );

    for (final child in children) {
      debugPrint(
        'SUBCATEGORY: '
        '${child['id']} - ${child['name']}',
      );
    }

    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryId = null;
      _subcategories = children;
    });

    debugPrint('============================');
  }

  // =========================================================
  // انتخاب زیر دسته
  // =========================================================

  void _onSubcategoryChanged(
    int? subcategoryId,
  ) {
    setState(() {
      _selectedSubcategoryId =
          subcategoryId;
    });

    debugPrint(
      'SELECTED SUBCATEGORY: '
      '$subcategoryId',
    );
  }

  // =========================================================
  // نام دسته انتخاب‌شده
  // =========================================================

  String _selectedCategoryName() {
    if (_selectedCategoryId == null) {
      return '';
    }

    for (final category in _categories) {
      final id = _parseId(
        category['id'],
      );

      if (id == _selectedCategoryId) {
        return _getItemName(category);
      }
    }

    return '';
  }

  // =========================================================
  // نام زیر دسته انتخاب‌شده
  // =========================================================

  String _selectedSubcategoryName() {
    if (_selectedSubcategoryId == null) {
      return '';
    }

    for (final subcategory
        in _subcategories) {
      final id = _parseId(
        subcategory['id'],
      );

      if (id == _selectedSubcategoryId) {
        return _getItemName(
          subcategory,
        );
      }
    }

    return '';
  }

  // =========================================================
  // اعتبارسنجی مرحله
  // =========================================================

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _validatePersonalInfo();

      case 1:
        return _validateStoreInfo();

      case 2:
        return _validateContactInfo();

      case 3:
        return _validatePassword();

      default:
        return true;
    }
  }

  // =========================================================
  // اعتبارسنجی اطلاعات شخصی
  // =========================================================

  bool _validatePersonalInfo() {
    if (_firstNameController.text.trim().isEmpty) {
      _showMessage('نام را وارد کنید.');
      return false;
    }

    if (_lastNameController.text.trim().isEmpty) {
      _showMessage('نام خانوادگی را وارد کنید.');
      return false;
    }

    if (_emailController.text.trim().isEmpty) {
      _showMessage('ایمیل را وارد کنید.');
      return false;
    }

    final email =
        _emailController.text.trim();

    if (!email.contains('@') ||
        !email.contains('.')) {
      _showMessage(
        'ایمیل معتبر وارد کنید.',
      );
      return false;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showMessage(
        'شماره موبایل را وارد کنید.',
      );
      return false;
    }

    if (_usernameController.text.trim().isEmpty) {
      _showMessage(
        'نام کاربری را وارد کنید.',
      );
      return false;
    }

    return true;
  }

  // =========================================================
  // اعتبارسنجی اطلاعات فروشگاه
  // =========================================================

  bool _validateStoreInfo() {
    if (_storeNameController.text.trim().isEmpty) {
      _showMessage(
        'نام فروشگاه را وارد کنید.',
      );
      return false;
    }

    if (_selectedCity == null ||
        _selectedCity!.trim().isEmpty) {
      _showMessage(
        'شهر را انتخاب کنید.',
      );
      return false;
    }

    if (_selectedCategoryId == null) {
      _showMessage(
        'دسته‌بندی فعالیت را انتخاب کنید.',
      );
      return false;
    }

    if (_subcategories.isEmpty) {
      _showMessage(
        'برای این دسته‌بندی زیر‌دسته‌ای پیدا نشد.',
      );
      return false;
    }

    if (_selectedSubcategoryId == null) {
      _showMessage(
        'زیر‌دسته‌بندی را انتخاب کنید.',
      );
      return false;
    }

    if (_addressController.text.trim().isEmpty) {
      _showMessage(
        'آدرس فروشگاه را وارد کنید.',
      );
      return false;
    }

    return true;
  }

  // =========================================================
  // اعتبارسنجی اطلاعات تماس
  // =========================================================

  bool _validateContactInfo() {
    if (_phoneController.text.trim().isEmpty) {
      _showMessage(
        'شماره موبایل را وارد کنید.',
      );
      return false;
    }

    return true;
  }

  // =========================================================
  // اعتبارسنجی رمز
  // =========================================================

  bool _validatePassword() {
    if (_passwordController.text.isEmpty) {
      _showMessage(
        'رمز عبور را وارد کنید.',
      );
      return false;
    }

    if (_passwordController.text.length < 6) {
      _showMessage(
        'رمز عبور باید حداقل ۶ کاراکتر باشد.',
      );
      return false;
    }

    if (_repeatPasswordController.text.isEmpty) {
      _showMessage(
        'تکرار رمز عبور را وارد کنید.',
      );
      return false;
    }

    if (_passwordController.text !=
        _repeatPasswordController.text) {
      _showMessage(
        'رمز عبور و تکرار آن یکسان نیستند.',
      );
      return false;
    }

    return true;
  }

  // =========================================================
  // مرحله بعد
  // =========================================================

  void _nextStep() {
    if (!_validateCurrentStep()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      if (_currentStep < 3) {
        _currentStep++;
      }
    });
  }

  // =========================================================
  // مرحله قبل
  // =========================================================

  void _previousStep() {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _currentStep--;
    });
  }

  // =========================================================
  // ثبت نهایی
  // =========================================================

  Future<void> _submitRegistration() async {
    if (_isLoading) {
      return;
    }

    if (!_validateCurrentStep()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('============================');
      debugPrint(
        'START VENDOR REGISTRATION',
      );
      debugPrint(
        'CITY: $_selectedCity',
      );
      debugPrint(
        'CATEGORY ID: $_selectedCategoryId',
      );
      debugPrint(
        'SUBCATEGORY ID: $_selectedSubcategoryId',
      );
      debugPrint(
        'CATEGORY NAME: ${_selectedCategoryName()}',
      );
      debugPrint(
        'SUBCATEGORY NAME: ${_selectedSubcategoryName()}',
      );
      debugPrint(
        'STORE NAME: ${_storeNameController.text}',
      );
      debugPrint(
        'PHONE: ${_phoneController.text}',
      );
      debugPrint(
        'ADDRESS: ${_addressController.text}',
      );
      debugPrint('============================');

      final result =
          await _authService.registerVendor(
        firstName:
            _firstNameController.text.trim(),

        lastName:
            _lastNameController.text.trim(),

        email:
            _emailController.text.trim(),

        username:
            _usernameController.text.trim(),

        password:
            _passwordController.text,

        phone:
            _phoneController.text.trim(),

        storeName:
            _storeNameController.text.trim(),

        city:
            _selectedCity!,

        categoryId:
            _selectedCategoryId!,

        subcategoryId:
            _selectedSubcategoryId!,

        address:
            _addressController.text.trim(),

        description:
            _descriptionController.text.trim(),

        /*
         * تلفن فروشگاه جداگانه نداریم.
         * همان شماره اصلی استفاده می‌شود.
         */
        storePhone:
            _phoneController.text.trim(),
      );

      if (!mounted) return;

      debugPrint('============================');
      debugPrint(
        'VENDOR REGISTRATION SUCCESS',
      );
      debugPrint(
        result.toString(),
      );
      debugPrint('============================');

      final status =
          result['status']?.toString();

      if (status == 'pending') {
        await _showPendingDialog();
      } else {
        _showMessage(
          result['message']?.toString() ??
              'درخواست ثبت‌نام ارسال شد.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================================================
  // پیام
  // =========================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  // =========================================================
  // دیالوگ ثبت موفق
  // =========================================================

  Future<void> _showPendingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection:
              TextDirection.rtl,
          child: Dialog(
            backgroundColor:
                Colors.transparent,
            insetPadding:
                const EdgeInsets.all(24),
            child: Container(
              padding:
                  const EdgeInsets.all(24),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(.12),
                    blurRadius: 30,
                    offset:
                        const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color: primary
                          .withOpacity(.10),
                    ),
                    child: const Icon(
                      Icons
                          .hourglass_top_rounded,
                      color: primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'درخواست ثبت شد',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  const Text(
                    'درخواست فروشندگی شما با موفقیت ثبت شد و در انتظار تأیید مدیر است.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.8,
                      color: textGrey,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Text(
                    'پس از تأیید مدیر، می‌توانید با همان نام کاربری و رمز عبوری که هنگام ثبت‌نام انتخاب کردید وارد حساب فروشندگی شوید.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.8,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,
                    child:
                        ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop();

                        Navigator.of(
                          context,
                        ).pop();
                      },
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            primary,
                        foregroundColor:
                            Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),
                      child:
                          const Text(
                        'متوجه شدم',
                        style:
                            TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // عنوان مرحله
  // =========================================================

  String _stepTitle() {
    switch (_currentStep) {
      case 0:
        return 'اطلاعات شخصی';

      case 1:
        return 'اطلاعات فروشگاه';

      case 2:
        return 'اطلاعات تماس';

      case 3:
        return 'تکمیل ثبت‌نام';

      default:
        return 'ثبت‌نام فروشنده';
    }
  }

  // =========================================================
  // توضیح مرحله
  // =========================================================

  String _stepDescription() {
    switch (_currentStep) {
      case 0:
        return 'مشخصات حساب کاربری خود را وارد کنید.';

      case 1:
        return 'اطلاعات و زمینه فعالیت فروشگاه را مشخص کنید.';

      case 2:
        return 'اطلاعات تکمیلی فروشگاه را وارد کنید.';

      case 3:
        return 'رمز عبور خود را تعیین و ثبت‌نام را تکمیل کنید.';

      default:
        return '';
    }
  }

  // =========================================================
  // آیکون مرحله
  // =========================================================

  IconData _stepIcon(int index) {
    switch (index) {
      case 0:
        return Icons.person_outline_rounded;

      case 1:
        return Icons.storefront_outlined;

      case 2:
        return Icons.contact_phone_outlined;

      case 3:
        return Icons.lock_outline_rounded;

      default:
        return Icons.circle_outlined;
    }
  }

  // =========================================================
  // نوار مراحل
  // =========================================================

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(
        4,
        (index) {
          final isActive =
              index == _currentStep;

          final isCompleted =
              index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds: 250,
                        ),
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              isActive ||
                                      isCompleted
                                  ? primary
                                  : Colors.white,
                          border:
                              Border.all(
                            color:
                                isActive ||
                                        isCompleted
                                    ? primary
                                    : borderColor,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons
                                  .check_rounded
                              : _stepIcon(
                                  index,
                                ),
                          size: 19,
                          color:
                              isActive ||
                                      isCompleted
                                  ? Colors.white
                                  : textGrey,
                        ),
                      ),
                      const SizedBox(
                        height: 7,
                      ),
                      Text(
                        _stepShortTitle(
                          index,
                        ),
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive
                                  ? FontWeight
                                      .w800
                                  : FontWeight
                                      .w500,
                          color:
                              isActive
                                  ? primary
                                  : textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < 3)
                  Container(
                    width: 20,
                    height: 2,
                    margin:
                        const EdgeInsets.only(
                      bottom: 23,
                    ),
                    color:
                        index < _currentStep
                            ? primary
                            : borderColor,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // عنوان کوتاه مراحل
  // =========================================================

  String _stepShortTitle(int index) {
    switch (index) {
      case 0:
        return 'شخصی';

      case 1:
        return 'فروشگاه';

      case 2:
        return 'تماس';

      case 3:
        return 'امنیت';

      default:
        return '';
    }
  }

  // =========================================================
  // Header
  // =========================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        20,
      ),
      decoration:
          const BoxDecoration(
        gradient: LinearGradient(
          begin:
              Alignment.topRight,
          end:
              Alignment.bottomLeft,
          colors: [
            primaryDark,
            primary,
          ],
        ),
        borderRadius:
            BorderRadius.only(
          bottomLeft:
              Radius.circular(28),
          bottomRight:
              Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(.15),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color: Colors.white
                        .withOpacity(.18),
                  ),
                ),
                child: const Icon(
                  Icons
                      .storefront_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'ترشیز استور',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(
                      height: 3,
                    ),
                    Text(
                      'ثبت‌نام فروشنده',
                      style: TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          Text(
            _stepTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            _stepDescription(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Input Decoration
  // =========================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: primary,
        size: 21,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),
        borderSide:
            const BorderSide(
          color: borderColor,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),
        borderSide:
            const BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),
        borderSide:
            const BorderSide(
          color: primary,
          width: 1.5,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),
        borderSide:
            const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),
        borderSide:
            const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
      labelStyle:
          const TextStyle(
        color: textGrey,
        fontSize: 13,
      ),
    );
  }

  // =========================================================
  // عنوان بخش
  // =========================================================

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              color:
                  primary.withOpacity(.09),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: primary,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color: textGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // مرحله اول
  // =========================================================

  Widget _buildPersonalInfo() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon:
              Icons.person_outline_rounded,
          title: 'اطلاعات حساب',
          subtitle:
              'اطلاعات شخصی و ورود به حساب',
        ),
        const SizedBox(
          height: 15,
        ),
        TextFormField(
          controller:
              _firstNameController,
          textInputAction:
              TextInputAction.next,
          decoration:
              _inputDecoration(
            label: 'نام',
            icon:
                Icons.person_outline,
            hint: 'مثلاً علی',
          ),
        ),
        const SizedBox(
          height: 13,
        ),
        TextFormField(
          controller:
              _lastNameController,
          textInputAction:
              TextInputAction.next,
          decoration:
              _inputDecoration(
            label: 'نام خانوادگی',
            icon:
                Icons.person_outline,
            hint: 'مثلاً احمدی',
          ),
        ),
        const SizedBox(
          height: 13,
        ),
        TextFormField(
          controller:
              _emailController,
          keyboardType:
              TextInputType.emailAddress,
          textInputAction:
              TextInputAction.next,
          decoration:
              _inputDecoration(
            label: 'ایمیل',
            icon:
                Icons.email_outlined,
            hint:
                'example@email.com',
          ),
        ),
        const SizedBox(
          height: 13,
        ),
        TextFormField(
          controller:
              _phoneController,
          keyboardType:
              TextInputType.phone,
          textInputAction:
              TextInputAction.next,
          decoration:
              _inputDecoration(
            label: 'شماره موبایل',
            icon:
                Icons.phone_android_outlined,
            hint:
                '09xxxxxxxxx',
          ),
        ),
        const SizedBox(
          height: 13,
        ),
        TextFormField(
          controller:
              _usernameController,
          textInputAction:
              TextInputAction.done,
          decoration:
              _inputDecoration(
            label: 'نام کاربری',
            icon:
                Icons.account_circle_outlined,
            hint:
                'نام کاربری ورود',
          ),
        ),
      ],
    );
  }

  // =========================================================
  // مرحله دوم
  // =========================================================

  Widget _buildStoreInfo() {
    if (_loadingRegistrationData) {
      return const Padding(
        padding:
            EdgeInsets.only(
          top: 80,
        ),
        child: Center(
          child:
              CircularProgressIndicator(
            color: primary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon:
              Icons.storefront_outlined,
          title:
              'مشخصات فروشگاه',
          subtitle:
              'شهر، دسته‌بندی و آدرس فروشگاه',
        ),
        const SizedBox(
          height: 15,
        ),

        // =====================================================
        // نام فروشگاه
        // =====================================================

        TextFormField(
          controller:
              _storeNameController,
          textInputAction:
              TextInputAction.next,
          decoration:
              _inputDecoration(
            label: 'نام فروشگاه',
            icon:
                Icons.store_outlined,
            hint:
                'نام فروشگاه شما',
          ),
        ),

        const SizedBox(
          height: 13,
        ),

        // =====================================================
        // شهر
        // =====================================================

        DropdownButtonFormField<String>(
          value: _selectedCity,
          isExpanded: true,
          decoration:
              _inputDecoration(
            label: 'شهر',
            icon:
                Icons.location_city_outlined,
          ),
          items:
              _cities.map(
            (city) {
              return DropdownMenuItem<
                  String>(
                value: city,
                child: Text(
                  city,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    color: textDark,
                  ),
                ),
              );
            },
          ).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCity =
                  value;
            });

            debugPrint(
              'SELECTED CITY: $_selectedCity',
            );
          },
        ),

        const SizedBox(
          height: 13,
        ),

        // =====================================================
        // دسته‌بندی
        // =====================================================

        DropdownButtonFormField<int>(
          value: _selectedCategoryId,
          isExpanded: true,
          decoration:
              _inputDecoration(
            label:
                'دسته‌بندی فعالیت',
            icon:
                Icons.category_outlined,
          ),
          items: _categories
              .map(
                (category) {
                  final id =
                      _parseId(
                    category['id'],
                  );

                  final name =
                      _getItemName(
                    category,
                  );

                  if (id == null ||
                      name.isEmpty) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int>(
                    value: id,
                    child: Text(
                      name,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        color:
                            textDark,
                      ),
                    ),
                  );
                },
              )
              .whereType<
                  DropdownMenuItem<int>>()
              .toList(),
          onChanged:
              _categories.isEmpty
                  ? null
                  : _onCategoryChanged,
        ),

        const SizedBox(
          height: 13,
        ),

        // =====================================================
        // زیر دسته‌بندی
        // =====================================================

        DropdownButtonFormField<int>(
          value:
              _selectedSubcategoryId,
          isExpanded: true,
          decoration:
              _inputDecoration(
            label:
                'زیر‌دسته‌بندی',
            icon:
                Icons
                    .account_tree_outlined,
            hint:
                _selectedCategoryId ==
                        null
                    ? 'ابتدا دسته‌بندی را انتخاب کنید'
                    : _subcategories.isEmpty
                        ? 'برای این دسته زیر‌دسته‌ای وجود ندارد'
                        : 'زیر‌دسته را انتخاب کنید',
          ),
          items: _subcategories
              .map(
                (subcategory) {
                  final id =
                      _parseId(
                    subcategory['id'],
                  );

                  final name =
                      _getItemName(
                    subcategory,
                  );

                  if (id == null ||
                      name.isEmpty) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int>(
                    value: id,
                    child: Text(
                      name,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        color:
                            textDark,
                      ),
                    ),
                  );
                },
              )
              .whereType<
                  DropdownMenuItem<int>>()
              .toList(),
          onChanged:
              _subcategories.isEmpty
                  ? null
                  : _onSubcategoryChanged,
        ),

        const SizedBox(
          height: 8,
        ),

        // =====================================================
        // وضعیت زیر دسته
        // =====================================================

        if (_selectedCategoryId !=
            null)
          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 5,
            ),
            child: Row(
              children: [
                Icon(
                  _subcategories.isEmpty
                      ? Icons
                          .info_outline_rounded
                      : Icons
                          .check_circle_outline_rounded,
                  size: 17,
                  color:
                      _subcategories.isEmpty
                          ? Colors.orange
                          : Colors.green,
                ),
                const SizedBox(
                  width: 7,
                ),
                Expanded(
                  child: Text(
                    _subcategories.isEmpty
                        ? 'برای دسته انتخاب‌شده زیر‌دسته‌ای از API دریافت نشد.'
                        : '${_subcategories.length} زیر‌دسته برای این دسته موجود است.',
                    style:
                        TextStyle(
                      fontSize: 11,
                      color:
                          _subcategories.isEmpty
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(
          height: 13,
        ),

        // =====================================================
        // آدرس
        // =====================================================

        TextFormField(
          controller:
              _addressController,
          maxLines: 3,
          textInputAction:
              TextInputAction.newline,
          decoration:
              _inputDecoration(
            label:
                'آدرس فروشگاه',
            icon:
                Icons
                    .location_on_outlined,
            hint:
                'آدرس کامل فروشگاه',
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        // =====================================================
        // نکته
        // =====================================================

        Container(
          padding:
              const EdgeInsets.all(14),
          decoration:
              BoxDecoration(
            color:
                primary.withOpacity(.06),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color:
                  primary.withOpacity(.12),
            ),
          ),
          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons
                    .info_outline_rounded,
                color: primary,
                size: 20,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  'فروشنده بر اساس شهر و دسته‌بندی فعالیت در ترشیز استور نمایش داده خواهد شد.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textDark,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // مرحله سوم
  // =========================================================

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon:
              Icons.contact_phone_outlined,
          title:
              'اطلاعات تکمیلی',
          subtitle:
              'توضیحات بیشتری درباره فروشگاه خود بنویسید',
        ),
        const SizedBox(
          height: 15,
        ),

        Container(
          padding:
              const EdgeInsets.all(15),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: Colors.green
                      .withOpacity(.09),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons
                      .phone_android_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'شماره تماس',
                      style:
                          TextStyle(
                        fontSize: 12,
                        color:
                            textGrey,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      _phoneController
                              .text
                              .trim()
                              .isEmpty
                          ? 'شماره موبایل وارد نشده'
                          : _phoneController
                              .text
                              .trim(),
                      style:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 21,
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        TextFormField(
          controller:
              _descriptionController,
          maxLines: 7,
          textInputAction:
              TextInputAction.newline,
          decoration:
              _inputDecoration(
            label:
                'توضیحات فروشگاه',
            icon:
                Icons.description_outlined,
            hint:
                'مثلاً درباره محصولات، خدمات یا سابقه فروشگاه بنویسید...',
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        Container(
          padding:
              const EdgeInsets.all(14),
          decoration:
              BoxDecoration(
            color:
                const Color(0xfffffbef),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color:
                  accent.withOpacity(.25),
            ),
          ),
          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons
                    .lightbulb_outline_rounded,
                color: accent,
                size: 21,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  'شماره موبایلی که در مرحله قبل وارد کردید به عنوان شماره تماس فروشنده استفاده می‌شود و نیازی به شماره تلفن فروشگاه جداگانه نیست.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // مرحله چهارم
  // =========================================================

  Widget _buildFinalStep() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Container(
          padding:
              const EdgeInsets.all(20),
          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              colors: [
                primaryDark,
                primary,
              ],
            ),
            borderRadius:
                BorderRadius.circular(
              22,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(.14),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .verified_user_outlined,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              const Text(
                'تقریباً تمام شد!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              const Text(
                'رمز عبور خود را تعیین کنید تا درخواست فروشندگی ارسال شود.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        TextFormField(
          controller:
              _passwordController,
          obscureText:
              !_showPassword,
          decoration:
              _inputDecoration(
            label:
                'رمز عبور',
            icon:
                Icons.lock_outline,
            hint:
                'حداقل ۶ کاراکتر',
            suffixIcon:
                IconButton(
              onPressed: () {
                setState(() {
                  _showPassword =
                      !_showPassword;
                });
              },
              icon: Icon(
                _showPassword
                    ? Icons
                        .visibility_off_outlined
                    : Icons
                        .visibility_outlined,
                color: textGrey,
              ),
              tooltip:
                  _showPassword
                      ? 'مخفی کردن رمز'
                      : 'نمایش رمز',
            ),
          ),
        ),

        const SizedBox(
          height: 13,
        ),

        TextFormField(
          controller:
              _repeatPasswordController,
          obscureText:
              !_showRepeatPassword,
          decoration:
              _inputDecoration(
            label:
                'تکرار رمز عبور',
            icon:
                Icons.lock_reset_outlined,
            hint:
                'رمز عبور را دوباره وارد کنید',
            suffixIcon:
                IconButton(
              onPressed: () {
                setState(() {
                  _showRepeatPassword =
                      !_showRepeatPassword;
                });
              },
              icon: Icon(
                _showRepeatPassword
                    ? Icons
                        .visibility_off_outlined
                    : Icons
                        .visibility_outlined,
                color: textGrey,
              ),
              tooltip:
                  _showRepeatPassword
                      ? 'مخفی کردن رمز'
                      : 'نمایش رمز',
            ),
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        _buildSummaryCard(),

        const SizedBox(
          height: 15,
        ),

        Container(
          padding:
              const EdgeInsets.all(14),
          decoration:
              BoxDecoration(
            color:
                const Color(0xfff5f7fb),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: primary,
                size: 21,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  'پس از ارسال، درخواست شما برای بررسی مدیر ارسال می‌شود. پس از تأیید، حساب فروشندگی شما فعال خواهد شد.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textDark,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // خلاصه اطلاعات
  // =========================================================

  Widget _buildSummaryCard() {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .assignment_outlined,
                color: primary,
                size: 20,
              ),
              SizedBox(
                width: 8,
              ),
              Text(
                'خلاصه اطلاعات',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 13,
          ),
          _summaryRow(
            'فروشگاه',
            _storeNameController
                .text
                .trim(),
            Icons.store_outlined,
          ),
          _summaryRow(
            'شهر',
            _selectedCity ?? '',
            Icons.location_city_outlined,
          ),
          _summaryRow(
            'دسته',
            _selectedCategoryName(),
            Icons.category_outlined,
          ),
          _summaryRow(
            'زیر‌دسته',
            _selectedSubcategoryName(),
            Icons.account_tree_outlined,
          ),
          _summaryRow(
            'تماس',
            _phoneController
                .text
                .trim(),
            Icons.phone_outlined,
            last: true,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ردیف خلاصه
  // =========================================================

  Widget _summaryRow(
    String title,
    String value,
    IconData icon, {
    bool last = false,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(
                  color: borderColor,
                ),
              ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: textGrey,
          ),
          const SizedBox(
            width: 9,
          ),
          SizedBox(
            width: 70,
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 11,
                color: textGrey,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              value.isEmpty
                  ? '-'
                  : value,
              textAlign:
                  TextAlign.right,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // محتوای مرحله
  // =========================================================

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfo();

      case 1:
        return _buildStoreInfo();

      case 2:
        return _buildContactInfo();

      case 3:
        return _buildFinalStep();

      default:
        return const SizedBox();
    }
  }

  // =========================================================
  // دکمه پایین
  // =========================================================

  Widget _buildBottomButtons() {
    final isLastStep =
        _currentStep == 3;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        18,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .06,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 54,
                child:
                    OutlinedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _previousStep,
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        primary,
                    side:
                        const BorderSide(
                      color: borderColor,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                  ),
                  child:
                      const Text(
                    'قبلی',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                ),
              ),
            ),

          if (_currentStep > 0)
            const SizedBox(
              width: 10,
            ),

          Expanded(
            flex:
                _currentStep > 0
                    ? 2
                    : 1,
            child: SizedBox(
              height: 54,
              child:
                  ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : (isLastStep
                            ? _submitRegistration
                            : _nextStep),
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      primary,
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      15,
                    ),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2.5,
                          color:
                              Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Text(
                            isLastStep
                                ? 'ارسال درخواست'
                                : 'ادامه',
                            style:
                                const TextStyle(
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Icon(
                            isLastStep
                                ? Icons
                                    .send_rounded
                                : Icons
                                    .arrow_back_ios_new_rounded,
                            size: 17,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            background,
        appBar: AppBar(
          title: Text(
            _stepTitle(),
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color: textDark,
            ),
          ),
          centerTitle: true,
          backgroundColor:
              Colors.white,
          foregroundColor:
              textDark,
          elevation: 0,
          surfaceTintColor:
              Colors.white,
          leading:
              IconButton(
            icon: const Icon(
              Icons
                  .arrow_forward_ios_rounded,
              size: 19,
            ),
            onPressed:
                _isLoading
                    ? null
                    : _previousStep,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child:
                    SingleChildScrollView(
                  physics:
                      const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    25,
                  ),
                  child:
                      Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildStepIndicator(),
                        const SizedBox(
                          height: 20,
                        ),
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(
                            maxWidth: 620,
                          ),
                          child:
                              _buildCurrentStep(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }
}