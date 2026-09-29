import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/login/login_screen.dart';

class TashizStoreApp extends StatelessWidget {
  const TashizStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ترشیز استور',
      theme: AppTheme.lightTheme,
      locale: const Locale('fa'),
      home: const LoginScreen(),
    );
  }
}