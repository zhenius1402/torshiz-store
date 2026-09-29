import 'package:flutter/material.dart';

import 'login_controller.dart';
import 'vendor_registration_screen.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final LoginController _loginController = LoginController();

  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _loginController.addListener(_controllerListener);
  }

  void _controllerListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    _loginController.removeListener(_controllerListener);
    _loginController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await _loginController.login(
      username: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _loginController.errorMessage ??
                'ورود ناموفق بود',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VendorRegistrationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 430,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 25),

                      // =====================================================
                      // لوگوی موقت
                      // =====================================================

                      const Icon(
                        Icons.storefront,
                        size: 85,
                        color: Colors.blue,
                      ),

                      const SizedBox(height: 20),

                      // =====================================================
                      // نام فروشگاه
                      // =====================================================

                      const Text(
                        'ترشیز استور',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'ورود فروشندگان به پنل مدیریت',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // =====================================================
                      // ایمیل / نام کاربری
                      // =====================================================

                      TextFormField(
                        controller: _emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'ایمیل یا نام کاربری',
                          hintText:
                              'ایمیل فروشنده را وارد کنید',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'ایمیل یا نام کاربری را وارد کنید';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // =====================================================
                      // رمز عبور
                      // =====================================================

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction:
                            TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_loginController.isLoading) {
                            _login();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'رمز عبور',
                          hintText:
                              'رمز عبور را وارد کنید',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          border:
                              const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'رمز عبور را وارد کنید';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // =====================================================
                      // مرا به خاطر بسپار
                      // =====================================================

                      CheckboxListTile(
                        value: _rememberMe,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity:
                            ListTileControlAffinity.leading,
                        title: const Text(
                          'مرا به خاطر بسپار',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _rememberMe =
                                value ?? false;
                          });
                        },
                      ),

                      const SizedBox(height: 18),

                      // =====================================================
                      // دکمه ورود
                      // =====================================================

                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              _loginController.isLoading
                                  ? null
                                  : _login,
                          child:
                              _loginController.isLoading
                                  ? const SizedBox(
                                      width: 25,
                                      height: 25,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'ورود به پنل فروشنده',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =====================================================
                      // ثبت نام فروشنده
                      // =====================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Text(
                            'حساب فروشندگی ندارید؟',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),

                          TextButton(
                            onPressed: _openRegistration,
                            child: const Text(
                              'ثبت‌نام کنید',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff1565c0),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}