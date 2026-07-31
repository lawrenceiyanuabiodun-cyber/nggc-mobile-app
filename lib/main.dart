import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'config/app_config.dart';
import 'theme/app_theme.dart';

void main() async {
  // Ensure Flutter engine is initialized before any async work
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar to transparent with light icons
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive for offline storage
  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);

  runApp(
    const ProviderScope(
      child: NGGCApp(),
    ),
  );
}

class NGGCApp extends ConsumerWidget {
  const NGGCApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConfig.appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashPlaceholder(),
    );
  }
}

/// Temporary splash shown at Stage 15.1
/// Will be replaced by real SplashScreen + auth routing in Stage 15.2
class SplashPlaceholder extends StatelessWidget {
  const SplashPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with fallback
              Image.asset(
                'assets/images/nggc-logo.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.church,
                      size: 64,
                      color: Colors.white,
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // App name
              const Text(
                'NGGC',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),

              const SizedBox(height: 8),

              // Full church name
              const Text(
                'New Generation Gospel Church',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // Tagline
              const Text(
                'Sunday School',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFFFD700),
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 80),

              // Loading spinner
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
              ),

              const SizedBox(height: 32),

              // Stage indicator — remove in production
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Stage 15.1 — Initialized ✓',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}