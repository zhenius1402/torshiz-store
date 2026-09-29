import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api/vendor_api.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final VendorApi _vendorApi = VendorApi();
  final ImagePicker _picker = ImagePicker();

  // پالت رنگی
  static const Color _primary = Color(0xff1565c0);
  static const Color _primaryDark = Color(0xff0d47a1);
  static const Color _accentGold = Color(0xffc9a227);
  static const Color _bg = Color(0xfff5f7fb);

  Map<String, dynamic>? _profile;
  int? _productCount;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUploadingLogo = false;
  bool _isUploadingBanner = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _vendorApi.getVendorProfile();

      // تعداد محصولات را جدا می‌گیریم تا اگر خطا داد، کل صفحه
      // از کار نیفتد — فقط بلوک آمار خالی می‌ماند.
      int? productCount;
      try {
        productCount = await _vendorApi.getVendorProductCount();
      } catch (_) {
        productCount = null;
      }

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _productCount = productCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _getValue(
    String key, {
    String defaultValue = 'ثبت نشده',
  }) {
    final value = _profile?[key];

    if (value == null) {
      return defaultValue;
    }

    final text = value.toString().trim();

    if (text.isEmpty ||
        text == 'null' ||
        text == '0' ||
        text == 'false' ||
        text == 'inactive' ||
        text == 'disabled' ||
        text == 'closed') {
      return defaultValue;
    }

    return text;
  }

  bool _isStoreOffline() {
    final value = _profile?['is_store_offline'];

    if (value == null) {
      return false;
    }

    final text = value.toString().toLowerCase().trim();

    return text == 'yes' ||
        text == 'true' ||
        text == '1' ||
        text == 'offline' ||
        text == 'closed';
  }

  String _getStoreName() {
    final shopName = _profile?['vendor_shop_name'];

    if (shopName != null && shopName.toString().trim().isNotEmpty) {
      return shopName.toString().trim();
    }

    final displayName = _profile?['vendor_display_name'];

    if (displayName != null &&
        displayName.toString().trim().isNotEmpty) {
      return displayName.toString().trim();
    }

    return 'فروشگاه من';
  }

  String _getDisplayName() {
    final displayName = _profile?['vendor_display_name'];

    if (displayName != null &&
        displayName.toString().trim().isNotEmpty) {
      return displayName.toString().trim();
    }

    return 'فروشنده';
  }

  String _getEmail() {
    final email = _profile?['vendor_email'];

    if (email != null && email.toString().trim().isNotEmpty) {
      return email.toString().trim();
    }

    return 'ثبت نشده';
  }

  String _getLogo() {
    final logo = _profile?['vendor_shop_logo'];

    if (logo == null) {
      return '';
    }

    return logo.toString().trim();
  }

  String _getBanner() {
    final banner = _profile?['vendor_banner'];

    if (banner == null) {
      return '';
    }

    return banner.toString().trim();
  }

  Future<void> _pickAndUploadLogo() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      _isUploadingLogo = true;
    });

    try {
      final newUrl = await _vendorApi.uploadVendorLogo(picked);

      if (!mounted) return;

      setState(() {
        _profile ??= {};
        _profile!['vendor_shop_logo'] = newUrl;
        _isUploadingLogo = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploadingLogo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری عکس فروشگاه: $e')),
      );
    }
  }

  Future<void> _pickAndUploadBanner() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      _isUploadingBanner = true;
    });

    try {
      final newUrl = await _vendorApi.uploadVendorBanner(picked);

      if (!mounted) return;

      setState(() {
        _profile ??= {};
        _profile!['vendor_banner'] = newUrl;
        _isUploadingBanner = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploadingBanner = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری بنر فروشگاه: $e')),
      );
    }
  }

  Future<void> _openEditProfile() async {
    if (_profile == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return EditProfileScreen(
            initialData: {
              'user_name': _getDisplayName(),
              'email': _getEmail(),
              'store_name': _getStoreName(),
              'phone': _getValue('phone'),
              'address': _getValue('store_address'),
              'city': _getValue('store_city'),
              'state': _getValue('store_state'),
            },
          );
        },
      ),
    );

    if (!mounted) return;

    await _loadProfile();
  }

  Future<void> _openChangePassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const ChangePasswordScreen();
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // هدر: بنر فروشگاه (تار شده) + گرادینت + آواتار + وضعیت
  // -------------------------------------------------------------------
  Widget _buildStoreHeader() {
    final logoUrl = _getLogo();
    final bannerUrl = _getBanner();
    final storeName = _getStoreName();
    final displayName = _getDisplayName();
    final isOffline = _isStoreOffline();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          // بنر پس‌زمینه (اگر موجود باشد) با پوشش گرادینت روی آن
          if (bannerUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                bannerUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: bannerUrl.isNotEmpty
                      ? [
                          _primaryDark.withValues(alpha: 0.88),
                          _primary.withValues(alpha: 0.82),
                        ]
                      : const [_primary, _primaryDark],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: _isUploadingLogo
                            ? const CircularProgressIndicator(
                                color: _primary,
                                strokeWidth: 2.5,
                              )
                            : logoUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      logoUrl,
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Icon(
                                          Icons.store,
                                          size: 42,
                                          color: _primary,
                                        );
                                      },
                                    ),
                                  )
                                : const Icon(
                                    Icons.store,
                                    size: 42,
                                    color: _primary,
                                  ),
                      ),
                    ),
                    // نشان دوربین برای تغییر عکس فروشگاه
                    Positioned(
                      bottom: -2,
                      left: -2,
                      child: GestureDetector(
                        onTap: _isUploadingLogo
                            ? null
                            : _pickAndUploadLogo,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accentGold,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  storeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isOffline
                        ? Colors.red.withValues(alpha: 0.18)
                        : Colors.green.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isOffline
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOffline
                            ? Icons.store_mall_directory_outlined
                            : Icons.check_circle,
                        color: isOffline
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOffline
                            ? 'فروشگاه بسته است'
                            : 'فروشگاه فعال است',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // دکمه‌ی تغییر بنر — گوشه‌ی بالای کارت
          Positioned(
            top: 10,
            left: 10,
            child: GestureDetector(
              onTap: _isUploadingBanner ? null : _pickAndUploadBanner,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isUploadingBanner
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                    const SizedBox(width: 5),
                    const Text(
                      'تغییر بنر',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

  // -------------------------------------------------------------------
  // بلوک آمار: تعداد محصولات — تنها جای جسارت رنگی طلایی در صفحه
  // -------------------------------------------------------------------
  Widget _buildProductCountStat() {
    final hasCount = _productCount != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _accentGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _accentGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'تعداد محصولات فروشگاه',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasCount ? '$_productCount محصول' : 'در حال بارگذاری...',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // لیست اطلاعات به‌شکل تنظیمات، با آیکون‌های رنگی متفاوت
  // -------------------------------------------------------------------
  Widget _buildInfoList() {
    final rows = <_InfoRowData>[
      _InfoRowData(
        icon: Icons.person_outline,
        color: _primary,
        title: 'نام فروشنده',
        value: _getDisplayName(),
      ),
      _InfoRowData(
        icon: Icons.email_outlined,
        color: const Color(0xff8e24aa),
        title: 'ایمیل',
        value: _getEmail(),
      ),
      _InfoRowData(
        icon: Icons.phone_outlined,
        color: const Color(0xff2e7d32),
        title: 'شماره تماس',
        value: _getValue('phone'),
      ),
      _InfoRowData(
        icon: Icons.map_outlined,
        color: const Color(0xffef6c00),
        title: 'استان',
        value: _getValue('store_state'),
      ),
      _InfoRowData(
        icon: Icons.location_city_outlined,
        color: const Color(0xffef6c00),
        title: 'شهر',
        value: _getValue('store_city'),
      ),
      _InfoRowData(
        icon: Icons.location_on_outlined,
        color: const Color(0xffd84315),
        title: 'آدرس',
        value: _getValue('store_address'),
      ),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Column(
              children: [
                _buildInfoRow(rows[i]),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    endIndent: 60,
                    color: Colors.grey.shade100,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(_InfoRowData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              data.icon,
              color: data.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data.title,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onPressed,
    Color color = _primary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
        ),
        label: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: color.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStoreHeader(),
            _buildProductCountStat(),
            _buildInfoList(),
            const SizedBox(height: 20),
            _buildActionButton(
              icon: Icons.edit_outlined,
              title: 'ویرایش اطلاعات فروشگاه',
              onPressed: _openEditProfile,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.lock_outline,
              title: 'تغییر رمز عبور',
              onPressed: _openChangePassword,
              color: const Color(0xffef6c00),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'حساب من',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: _primary,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 55,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'دریافت اطلاعات حساب انجام نشد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          child: const Text('تلاش دوباره'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildProfileContent(),
    );
  }
}

class _InfoRowData {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  _InfoRowData({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });
}
