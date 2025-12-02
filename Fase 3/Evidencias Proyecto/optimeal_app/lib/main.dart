// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/scan_provider.dart';
import 'config.dart';
import 'services/api.service.dart';
import 'views/login_page.dart';
import 'views/scan/scan_form_page.dart';
import 'views/register/register_page.dart';
import 'views/scan/resultado_page.dart';
import 'views/home/home_page.dart';
import 'views/scan/ranking_page.dart'; // ← NUEVO
import './theme/app_theme.dart';

void main() => runApp(const OptiMealApp());

class OptiMealApp extends StatelessWidget {
  const OptiMealApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6));

    // Crear la instancia de AuthService usando la URL desde config.dart
    final authService = AuthService(baseUrl: API_BASE_LOCAL);

    return MultiProvider(
      providers: [
        // Proveemos AuthService
        Provider<AuthService>.value(value: authService),

        // AuthProvider que depende de AuthService
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (ctx) => AuthProvider(authService: authService),
          update: (ctx, authSvc, authProv) {
            if (authProv == null) return AuthProvider(authService: authSvc);
            authProv.updateAuthService(authSvc);
            return authProv;
          },
        ),

        // 🔹 ScanProvider
        ChangeNotifierProvider<ScanProvider>(
          create: (ctx) => ScanProvider(authService: authService),
        ),
      ],
      child: MaterialApp(
        title: 'OptiMeal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginPage(),
          '/scan': (_) => const ScanFormPage(),
          '/register': (_) => const RegisterPage(),
          '/resultado': (_) => const ResultPage(),
          '/home': (_) => const HomePage(),
          '/ranking': (_) =>
              const RankingPage(), // ← NUEVO (misma forma que las demás)
        },
      ),
    );
  }
}
