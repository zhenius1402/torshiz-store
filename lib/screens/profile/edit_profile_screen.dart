import 'package:flutter/material.dart';
import '../../services/api/vendor_account_api.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const EditProfileScreen({
    super.key,
    required this.initialData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final VendorAccountApi _accountApi = VendorAccountApi();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _userNameController;
  late TextEditingController _emailController;
  late TextEditingController _storeNameController;
  late TextEditingController _phoneController;
  late TextEditingController _stateController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  bool _isLoadingHours = true;
  bool _isSavingHours = false;

  // ============================================================
  // دسته بندی و زیر دسته بندی
  // ============================================================

  bool _isLoadingCategories = true;

  // بعد از تایید مدیر، دسته و زیر دسته قفل می‌شوند.
  bool _categoryLocked = true;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subcategories = [];

  int? _selectedCategoryId;
  int? _selectedSubcategoryId;

  String _apiCategoryName = '';
  String _apiSubcategoryName = '';

  // ============================================================
  // ساعت کاری
  // ============================================================

  bool _hoursEnabled = true;

  final List<String> _dayNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  final List<String> _dayKeys = [
    'saturday',
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  late List<bool> _dayEnabled;
  late List<TimeOfDay?> _startTimes;
  late List<TimeOfDay?> _endTimes;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _userNameController = TextEditingController(
      text: widget.initialData['user_name']?.toString() ??
          widget.initialData['username']?.toString() ??
          '',
    );

    _emailController = TextEditingController(
      text: widget.initialData['email']?.toString() ?? '',
    );

    _storeNameController = TextEditingController(
      text: widget.initialData['store_name']?.toString() ??
          widget.initialData['store_name_en']?.toString() ??
          '',
    );

    _phoneController = TextEditingController(
      text: widget.initialData['phone']?.toString() ?? '',
    );

    _stateController = TextEditingController(
      text: widget.initialData['state']?.toString() ?? '',
    );

    _cityController = TextEditingController(
      text: widget.initialData['city']?.toString() ?? '',
    );

    _addressController = TextEditingController(
      text: widget.initialData['address']?.toString() ?? '',
    );

    // ==========================================================
    // دسته بندی اولیه
    // ==========================================================

    _selectedCategoryId = _parseInt(
      widget.initialData['category_id'],
    );

    _selectedSubcategoryId = _parseInt(
      widget.initialData['subcategory_id'],
    );

    _apiCategoryName =
        widget.initialData['category_name']?.toString().trim() ?? '';

    _apiSubcategoryName =
        widget.initialData['subcategory_name']?.toString().trim() ?? '';

    if (widget.initialData.containsKey('category_locked')) {
      _categoryLocked = _parseBool(
        widget.initialData['category_locked'],
        defaultValue: true,
      );
    } else {
      _categoryLocked = true;
    }

    // ==========================================================
    // ساعت پیش فرض
    // ==========================================================

    _dayEnabled = List<bool>.filled(7, true);

    _startTimes = List<TimeOfDay?>.filled(
      7,
      const TimeOfDay(
        hour: 9,
        minute: 0,
      ),
    );

    _endTimes = List<TimeOfDay?>.filled(
      7,
      const TimeOfDay(
        hour: 21,
        minute: 0,
      ),
    );

    _loadBusinessHours();
    _loadCategories();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _emailController.dispose();
    _storeNameController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  // ============================================================
  // PARSE INT
  // ============================================================

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value > 0 ? value : null;
    }

    if (value is double) {
      final result = value.toInt();
      return result > 0 ? result : null;
    }

    final result = int.tryParse(
      value.toString(),
    );

    return result != null && result > 0 ? result : null;
  }

  // ============================================================
  // PARSE BOOL
  // ============================================================

  bool _parseBool(
    dynamic value, {
    bool defaultValue = false,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    if (value is String) {
      final v = value.toLowerCase().trim();

      if (v == 'yes' ||
          v == 'true' ||
          v == '1' ||
          v == 'on') {
        return true;
      }

      if (v == 'no' ||
          v == 'false' ||
          v == '0' ||
          v == 'off') {
        return false;
      }
    }

    return defaultValue;
  }

  // ============================================================
  // دریافت دسته بندی ها و اطلاعات فعلی
  // ============================================================

  Future<void> _loadCategories() async {
    try {
      // ----------------------------------------------------------
      // اطلاعات جدید پروفایل
      // ----------------------------------------------------------

      try {
        final profileResponse =
            await _accountApi.getVendorProfile();

        if (profileResponse.isNotEmpty) {
          final categoryId = _parseInt(
            profileResponse['category_id'],
          );

          final subcategoryId = _parseInt(
            profileResponse['subcategory_id'],
          );

          if (categoryId != null) {
            _selectedCategoryId = categoryId;
          }

          if (subcategoryId != null) {
            _selectedSubcategoryId = subcategoryId;
          }

          final categoryName =
              profileResponse['category_name']
                  ?.toString()
                  .trim();

          final subcategoryName =
              profileResponse['subcategory_name']
                  ?.toString()
                  .trim();

          if (categoryName != null &&
              categoryName.isNotEmpty) {
            _apiCategoryName = categoryName;
          }

          if (subcategoryName != null &&
              subcategoryName.isNotEmpty) {
            _apiSubcategoryName = subcategoryName;
          }

          if (profileResponse.containsKey(
            'category_locked',
          )) {
            _categoryLocked = _parseBool(
              profileResponse['category_locked'],
              defaultValue: true,
            );
          }
        }
      } catch (e) {
        debugPrint(
          'Error loading vendor profile: $e',
        );
      }

      // ----------------------------------------------------------
      // دریافت لیست دسته بندی ها
      // ----------------------------------------------------------

      final response =
          await _accountApi.getVendorCategories();

      if (response.isNotEmpty) {
        if (response.containsKey('category_locked')) {
          _categoryLocked = _parseBool(
            response['category_locked'],
            defaultValue: true,
          );
        }

        final responseCategoryName =
            response['category_name']
                ?.toString()
                .trim();

        final responseSubcategoryName =
            response['subcategory_name']
                ?.toString()
                .trim();

        if (responseCategoryName != null &&
            responseCategoryName.isNotEmpty) {
          _apiCategoryName = responseCategoryName;
        }

        if (responseSubcategoryName != null &&
            responseSubcategoryName.isNotEmpty) {
          _apiSubcategoryName = responseSubcategoryName;
        }

        final dynamic rawCategories =
            response['categories'] ??
            response['data'] ??
            response['items'];

        final parsedCategories =
            _parseCategoryList(rawCategories);

        if (parsedCategories.isNotEmpty) {
          _categories = parsedCategories;
          _prepareSubcategories();
        }
      }
    } catch (e) {
      debugPrint(
        'Error loading vendor categories: $e',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingCategories = false;
    });
  }

  // ============================================================
  // PARSE CATEGORY LIST
  // ============================================================

  List<Map<String, dynamic>> _parseCategoryList(
    dynamic value,
  ) {
    final List<Map<String, dynamic>> result = [];

    if (value is! List) {
      return result;
    }

    for (final item in value) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);

        final id = _parseInt(
          map['id'] ??
              map['term_id'] ??
              map['category_id'],
        );

        final name =
            map['name']?.toString() ??
            map['title']?.toString() ??
            map['label']?.toString();

        if (id != null &&
            name != null &&
            name.trim().isNotEmpty) {
          result.add({
            ...map,
            'id': id,
            'name': name.trim(),
          });
        }
      }
    }

    return result;
  }

  // ============================================================
  // آماده سازی زیر دسته ها
  // ============================================================

  void _prepareSubcategories() {
    _subcategories = [];

    if (_selectedCategoryId == null) {
      return;
    }

    Map<String, dynamic>? selectedCategory;

    for (final category in _categories) {
      final categoryId = _parseInt(
        category['id'],
      );

      if (categoryId == _selectedCategoryId) {
        selectedCategory = category;
        break;
      }
    }

    if (selectedCategory == null) {
      return;
    }

    final dynamic rawSubcategories =
        selectedCategory['subcategories'] ??
        selectedCategory['children'] ??
        selectedCategory['sub_categories'] ??
        selectedCategory['subCategories'];

    _subcategories =
        _parseCategoryList(rawSubcategories);

    if (!_categoryLocked &&
        _selectedSubcategoryId != null) {
      final exists = _subcategories.any(
        (item) =>
            _parseInt(item['id']) ==
            _selectedSubcategoryId,
      );

      if (!exists) {
        _selectedSubcategoryId = null;
      }
    }
  }

  // ============================================================
  // تغییر دسته بندی
  // ============================================================

  void _onCategoryChanged(int? categoryId) {
    if (_categoryLocked) {
      return;
    }

    if (categoryId == null) {
      return;
    }

    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryId = null;

      _prepareSubcategories();
    });
  }

  // ============================================================
  // BUSINESS HOURS
  // ============================================================

  Future<void> _loadBusinessHours() async {
    try {
      final response =
          await _accountApi.getVendorBusinessHours();

      if (!mounted) return;

      if (response is Map) {
        final dynamic storeHours =
            response['store_hours'];

        if (storeHours is Map) {
          _hoursEnabled = _parseBool(
            storeHours['enable'],
            defaultValue: true,
          );

          _loadOffDays(
            storeHours['off_days'],
          );

          _loadDayTimes(
            storeHours['day_times'],
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Error loading business hours: $e',
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoadingHours = false;
    });
  }

  // ============================================================
  // OFF DAYS
  // ============================================================

  void _loadOffDays(dynamic offDays) {
    if (offDays is! List) {
      return;
    }

    for (int i = 0; i < _dayKeys.length; i++) {
      final key = _dayKeys[i];

      bool isOff = false;

      for (final item in offDays) {
        final value =
            item.toString().toLowerCase().trim();

        if (value == key ||
            value == i.toString() ||
            value == _dayNames[i].toLowerCase()) {
          isOff = true;
          break;
        }
      }

      _dayEnabled[i] = !isOff;
    }
  }

  // ============================================================
  // DAY TIMES
  // ============================================================

  void _loadDayTimes(dynamic dayTimes) {
    if (dayTimes is Map) {
      for (int i = 0;
          i < _dayKeys.length;
          i++) {
        final key = _dayKeys[i];

        dynamic value;

        if (dayTimes.containsKey(key)) {
          value = dayTimes[key];
        } else if (dayTimes.containsKey(i.toString())) {
          value = dayTimes[i.toString()];
        } else if (dayTimes.containsKey(i)) {
          value = dayTimes[i];
        } else if (dayTimes.containsKey(_dayNames[i])) {
          value = dayTimes[_dayNames[i]];
        }

        _setDayTimeFromValue(
          i,
          value,
        );
      }
    } else if (dayTimes is List) {
      for (
        int i = 0;
        i < dayTimes.length && i < 7;
        i++
      ) {
        _setDayTimeFromValue(
          i,
          dayTimes[i],
        );
      }
    }
  }

  // ============================================================
  // SET DAY TIME
  // ============================================================

  void _setDayTimeFromValue(
    int index,
    dynamic value,
  ) {
    if (value == null) {
      return;
    }

    if (value is List && value.length >= 2) {
      final start = _parseTime(value[0]);
      final end = _parseTime(value[1]);

      if (start != null) {
        _startTimes[index] = start;
      }

      if (end != null) {
        _endTimes[index] = end;
      }

      return;
    }

    if (value is Map) {
      final startValue =
          value['start'] ??
          value['start_time'] ??
          value['from'] ??
          value['open'];

      final endValue =
          value['end'] ??
          value['end_time'] ??
          value['to'] ??
          value['close'];

      final start = _parseTime(startValue);
      final end = _parseTime(endValue);

      if (start != null) {
        _startTimes[index] = start;
      }

      if (end != null) {
        _endTimes[index] = end;
      }
    }
  }

  // ============================================================
  // PARSE TIME
  // ============================================================

  TimeOfDay? _parseTime(dynamic value) {
    if (value == null) {
      return null;
    }

    String text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final lowerText = text.toLowerCase();

    final isPm = lowerText.contains('pm');
    final isAm = lowerText.contains('am');

    text = text
        .replaceAll(
          RegExp(
            r'\s*am\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*pm\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    final parts = text.split(':');

    if (parts.length < 2) {
      return null;
    }

    int? hour = int.tryParse(
      parts[0].replaceAll(
        RegExp(r'[^0-9]'),
        '',
      ),
    );

    int? minute = int.tryParse(
      parts[1].replaceAll(
        RegExp(r'[^0-9]'),
        '',
      ),
    );

    if (hour == null || minute == null) {
      return null;
    }

    if (isPm && hour < 12) {
      hour += 12;
    }

    if (isAm && hour == 12) {
      hour = 0;
    }

    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  // ============================================================
  // SELECT TIME
  // ============================================================

  Future<void> _selectTime(
    int index,
    bool isStart,
  ) async {
    final currentTime = isStart
        ? _startTimes[index]
        : _endTimes[index];

    final selected = await showTimePicker(
      context: context,
      initialTime: currentTime ??
          const TimeOfDay(
            hour: 9,
            minute: 0,
          ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _startTimes[index] = selected;
      } else {
        _endTimes[index] = selected;
      }
    });
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return '09:00';
    }

    final hour = time.hour
        .toString()
        .padLeft(2, '0');

    final minute = time.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }

  // ============================================================
  // CATEGORY NAME
  // ============================================================

  String _getSelectedCategoryName() {
    for (final category in _categories) {
      if (_parseInt(category['id']) ==
          _selectedCategoryId) {
        final name =
            category['name']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    return _apiCategoryName;
  }

  // ============================================================
  // SUBCATEGORY NAME
  // ============================================================

  String _getSelectedSubcategoryName() {
    for (final item in _subcategories) {
      if (_parseInt(item['id']) ==
          _selectedSubcategoryId) {
        final name =
            item['name']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    return _apiSubcategoryName;
  }

  // ============================================================
  // LOCKED FIELD
  // ============================================================

  Widget _buildLockedCategoryField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xff1565c0),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.isNotEmpty
                      ? value
                      : 'ثبت نشده',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 19,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY SECTION
  // ============================================================

  Widget _buildCategorySection() {
    if (_isLoadingCategories) {
      return Container(
        margin: const EdgeInsets.only(
          bottom: 16,
        ),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ==========================================================
    // LOCKED
    // ==========================================================

    if (_categoryLocked) {
      final categoryName =
          _getSelectedCategoryName();

      final subcategoryName =
          _getSelectedSubcategoryName();

      return Container(
        margin: const EdgeInsets.only(
          bottom: 16,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xff1565c0,
                    ).withOpacity(0.10),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color:
                        Color(0xff1565c0),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'زمینه فعالیت فروشگاه',
                    textAlign:
                        TextAlign.right,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade100,
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color:
                            Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'قفل',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Colors.grey.shade700,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _buildLockedCategoryField(
              label: 'دسته‌بندی فعالیت',
              value: categoryName,
              icon:
                  Icons.category_outlined,
            ),

            _buildLockedCategoryField(
              label: 'زیر‌دسته‌بندی فعالیت',
              value: subcategoryName,
              icon:
                  Icons.account_tree_outlined,
            ),

            const SizedBox(height: 2),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: Colors.orange
                    .withOpacity(0.07),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 19,
                    color:
                        Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'دسته‌بندی و زیر‌دسته‌بندی پس از تأیید مدیر قابل تغییر نیست.',
                      textAlign:
                          TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            Color(0xff7a4b00),
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xff1565c0,
                ).withOpacity(0.06),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .check_circle_outline_rounded,
                    size: 18,
                    color:
                        Color(0xff1565c0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subcategoryName.isNotEmpty
                          ? 'فعالیت: $categoryName ← $subcategoryName'
                          : 'فعالیت: $categoryName',
                      textAlign:
                          TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color:
                            Color(0xff0d47a1),
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // UNLOCKED
    // ==========================================================

    if (_categories.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(
          bottom: 16,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'دسته‌بندی فعالیتی برای فروشندگان پیدا نشد.',
                textAlign:
                    TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(
                    0xff1565c0,
                  ).withOpacity(0.10),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color:
                      Color(0xff1565c0),
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'زمینه فعالیت فروشگاه',
                  textAlign:
                      TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          DropdownButtonFormField<int>(
            value: _categories.any(
              (item) =>
                  _parseInt(item['id']) ==
                  _selectedCategoryId,
            )
                ? _selectedCategoryId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText:
                  'دسته‌بندی فعالیت',
              hintText:
                  'دسته‌بندی فعالیت خود را انتخاب کنید',
              prefixIcon: const Icon(
                Icons.category_outlined,
                color:
                    Color(0xff1565c0),
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xff1565c0),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _categories.map(
              (category) {
                final id =
                    _parseInt(category['id']);

                final name =
                    category['name']
                            ?.toString() ??
                        '';

                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(
                    name,
                    textAlign:
                        TextAlign.right,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                );
              },
            ).toList(),
            onChanged:
                _onCategoryChanged,
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            value: _subcategories.any(
              (item) =>
                  _parseInt(item['id']) ==
                  _selectedSubcategoryId,
            )
                ? _selectedSubcategoryId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText:
                  'زیر‌دسته‌بندی فعالیت',
              hintText:
                  _selectedCategoryId == null
                      ? 'ابتدا دسته‌بندی را انتخاب کنید'
                      : _subcategories.isEmpty
                          ? 'برای این دسته زیر‌دسته‌ای وجود ندارد'
                          : 'زیر‌دسته‌بندی را انتخاب کنید',
              prefixIcon: const Icon(
                Icons.account_tree_outlined,
                color:
                    Color(0xff1565c0),
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xff1565c0),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _subcategories.map(
              (subcategory) {
                final id =
                    _parseInt(
                  subcategory['id'],
                );

                final name =
                    subcategory['name']
                            ?.toString() ??
                        '';

                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(
                    name,
                    textAlign:
                        TextAlign.right,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                );
              },
            ).toList(),
            onChanged:
                _selectedCategoryId == null ||
                        _subcategories.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedSubcategoryId =
                              value;
                        });
                      },
          ),

          if (_selectedCategoryId != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xff1565c0,
                ).withOpacity(0.06),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .check_circle_outline_rounded,
                    size: 18,
                    color:
                        Color(0xff1565c0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedSubcategoryId !=
                                  null &&
                              _getSelectedSubcategoryName()
                                  .isNotEmpty
                          ? 'فعالیت: ${_getSelectedCategoryName()} ← ${_getSelectedSubcategoryName()}'
                          : 'فعالیت: ${_getSelectedCategoryName()}',
                      textAlign:
                          TextAlign.right,
                      style:
                          const TextStyle(
                        fontSize: 12.5,
                        color:
                            Color(0xff0d47a1),
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _accountApi.updateVendorProfile(
        userName:
            _userNameController.text.trim(),
        email:
            _emailController.text.trim(),
        storeName:
            _storeNameController.text.trim(),
        phone:
            _phoneController.text.trim(),
        state:
            _stateController.text.trim(),
        city:
            _cityController.text.trim(),
        address:
            _addressController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اطلاعات پروفایل با موفقیت ذخیره شد.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا در ذخیره پروفایل: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE BUSINESS HOURS
  // ============================================================

  Future<void> _saveBusinessHours() async {
    if (_isSavingHours) {
      return;
    }

    setState(() {
      _isSavingHours = true;
    });

    try {
      final List<String> offDays = [];

      for (int i = 0; i < 7; i++) {
        if (!_dayEnabled[i]) {
          offDays.add(
            _dayKeys[i],
          );
        }
      }

      final Map<String, dynamic> dayTimes = {};

      for (int i = 0; i < 7; i++) {
        dayTimes[_dayKeys[i]] = [
          _formatTime(
            _startTimes[i],
          ),
          _formatTime(
            _endTimes[i],
          ),
        ];
      }

      final Map<String, dynamic> storeHours = {
        'enable': _hoursEnabled,
        'disable_purchase': false,
        'off_days': offDays,
        'day_times': dayTimes,
      };

      await _accountApi.updateVendorBusinessHours(
        storeHours: storeHours,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ساعت کاری با موفقیت ذخیره شد.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا در ذخیره ساعت کاری: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingHours = false;
        });
      }
    }
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint:
              maxLines > 1,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xff1565c0),
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // ============================================================
  // BUSINESS HOURS SECTION
  // ============================================================

  Widget _buildBusinessHoursSection() {
    if (_isLoadingHours) {
      return Container(
        margin: const EdgeInsets.only(
          top: 8,
        ),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(
        top: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(
                    0xff1565c0,
                  ).withOpacity(0.10),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color:
                      Color(0xff1565c0),
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ساعت کاری فروشگاه',
                  textAlign:
                      TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _hoursEnabled,
                activeColor:
                    const Color(0xff1565c0),
                onChanged: (value) {
                  setState(() {
                    _hoursEnabled = value;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: _hoursEnabled
                  ? Colors.green
                      .withOpacity(0.07)
                  : Colors.red
                      .withOpacity(0.07),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _hoursEnabled
                      ? Icons
                          .check_circle_outline_rounded
                      : Icons
                          .cancel_outlined,
                  size: 19,
                  color: _hoursEnabled
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hoursEnabled
                        ? 'فروشگاه طبق ساعات زیر باز است.'
                        : 'ساعت کاری فروشگاه غیرفعال است.',
                    textAlign:
                        TextAlign.right,
                    style: TextStyle(
                      color: _hoursEnabled
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if (_hoursEnabled)
            ...List.generate(
              7,
              (index) =>
                  _buildDayRow(index),
            ),

          const SizedBox(height: 8),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSavingHours
                  ? null
                  : _saveBusinessHours,
              icon: _isSavingHours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.save_rounded,
                    ),
              label: Text(
                _isSavingHours
                    ? 'در حال ذخیره...'
                    : 'ذخیره ساعت کاری',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xff1565c0),
                foregroundColor:
                    Colors.white,
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

  // ============================================================
  // DAY ROW
  // ============================================================

  Widget _buildDayRow(int index) {
    final bool enabled =
        _dayEnabled[index];

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: enabled
            ? Colors.grey.shade100
            : Colors.grey.shade200,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? Colors.grey.shade200
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Switch(
                value: enabled,
                activeColor:
                    const Color(0xff1565c0),
                onChanged: (value) {
                  setState(() {
                    _dayEnabled[index] =
                        value;
                  });
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _dayNames[index],
                  textAlign:
                      TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                    color: enabled
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              if (!enabled)
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      8,
                    ),
                  ),
                  child: Text(
                    'تعطیل',
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          if (enabled)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 5,
                right: 8,
                left: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildTimeButton(
                      label: 'شروع',
                      time:
                          _startTimes[index],
                      onTap: () {
                        _selectTime(
                          index,
                          true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        _buildTimeButton(
                      label: 'پایان',
                      time:
                          _endTimes[index],
                      onTap: () {
                        _selectTime(
                          index,
                          false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TIME BUTTON
  // ============================================================

  Widget _buildTimeButton({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade400,
          ),
          borderRadius:
              BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label: ${_formatTime(time)}',
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            const Color(0xfff5f7fb),
        appBar: AppBar(
          title: const Text(
            'ویرایش پروفایل',
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding:
                  const EdgeInsets.all(16),
              children: [
                // ==================================================
                // اطلاعات پروفایل
                // ==================================================

                _buildTextField(
                  label: 'نام کاربری',
                  controller:
                      _userNameController,
                ),

                _buildTextField(
                  label: 'ایمیل',
                  controller:
                      _emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                ),

                _buildTextField(
                  label: 'نام فروشگاه',
                  controller:
                      _storeNameController,
                ),

                _buildTextField(
                  label: 'شماره تماس',
                  controller:
                      _phoneController,
                  keyboardType:
                      TextInputType.phone,
                ),

                _buildTextField(
                  label: 'استان',
                  controller:
                      _stateController,
                ),

                _buildTextField(
                  label: 'شهر',
                  controller:
                      _cityController,
                ),

                _buildTextField(
                  label: 'آدرس',
                  controller:
                      _addressController,
                  maxLines: 3,
                ),

                const SizedBox(height: 4),

                // ==================================================
                // دسته بندی
                // ==================================================

                _buildCategorySection(),

                const SizedBox(height: 4),

                // ==================================================
                // ساعت کاری
                // ==================================================

                _buildBusinessHoursSection(),

                const SizedBox(height: 20),

                // ==================================================
                // ذخیره پروفایل
                // ==================================================

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : _saveProfile,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xff1565c0,
                      ),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'ذخیره اطلاعات پروفایل',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
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