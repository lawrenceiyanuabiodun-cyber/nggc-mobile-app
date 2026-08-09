import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/battery_optimization_service.dart';
import 'services/bible_loader_service.dart';
import 'services/manuals_loader_service.dart';
import 'services/daily_verse_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock - mobile only (web ignores this gracefully)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Background FCM handler - mobile only (web has no background process)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Hive init - path_provider only needed on mobile
  // On web, Hive uses IndexedDB automatically (no path needed)
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);
  }

  await Hive.openBox(AppConfig.settingsBoxName);
  await Hive.openBox(AppConfig.verseBoxName);
  await Hive.openBox(AppConfig.progressBoxName);
  await Hive.openBox(AppConfig.notesBoxName);
  await Hive.openBox(AppConfig.favoritesBoxName);

  // Notifications - mobile only (no local notifications on web)
  if (!kIsWeb) {
    await NotificationService.initialize();
  }

  await DailyVerseService.ensureInitialized();

  // Firebase + FCM - works on both mobile and web
  FcmService.initialize().catchError((e) {
    debugPrint("FCM init failed but app will continue: ");
  });

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
      themeMode: ref.watch(themeProvider),
      home: const AppRouter(),
    );
  }
}

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  bool _splashDone = false;
  bool _onboardingComplete = false;
  bool _batteryPromptShown = false;
  String _statusText = "Loading...";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() => _statusText = "Preparing Bible...");
    await BibleLoaderService.ensureBiblesLoaded();

    setState(() => _statusText = "Preparing manuals...");
    await ManualsLoaderService.ensureManualsLoaded();

    setState(() => _statusText = "Syncing daily verses...");
    DailyVerseService.syncIfNeeded().then((success) {
      if (success && !kIsWeb) {
        NotificationService.scheduleDailyVerseNotifications();
      }
    });

    final onboardingDone = await OnboardingHelper.isComplete();

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _statusText = "Ready";
      _onboardingComplete = onboardingDone;
      _splashDone = true;
    });
  }

  // Show battery optimization prompt after successful login
  // Mobile only - web has no battery optimization concept
  Future<void> _maybeShowBatteryPrompt() async {
    if (kIsWeb) return;
    if (_batteryPromptShown) return;
    _batteryPromptShown = true;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await BatteryOptimizationService.showFirstTimePromptIfNeeded(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return _SplashBody(statusText: _statusText);
    }

    if (!_onboardingComplete) {
      return OnboardingScreen(
        onComplete: () {
          setState(() => _onboardingComplete = true);
        },
      );
    }

    final authState = ref.watch(authProvider);

    if (authState.isUnknown) {
      return const _SplashBody(statusText: "Checking session...");
    }

    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowBatteryPrompt();
      });
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}

class _SplashBody extends StatelessWidget {
  final String statusText;

  const _SplashBody({required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/images/nggc-logo.png",
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
                  const Text(
                    "NGGC",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "New Generation Gospel Church",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Sunday School",
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFFFFD700),
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 16,
              bottom: 16,
              child: LiaConceptBadge(),
            ),
          ],
        ),
      ),
    );
  }
}

class LiaConceptBadge extends StatelessWidget {
  const LiaConceptBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(32, 32),
          painter: _LiaLogoPainter(),
        ),
        const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF64B5F6),
              Color(0xFFBA68C8),
            ],
          ).createShader(bounds),
          child: const Text(
            "L.I.A CONCEPT",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final gradient = const LinearGradient(
      colors: [Color(0xFF64B5F6), Color(0xFFBA68C8)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final nodePaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centerNode = Offset(cx, cy);
    final topNode = Offset(cx, cy - h * 0.4);
    final leftNode = Offset(cx - w * 0.4, cy);
    final rightNode = Offset(cx + w * 0.4, cy);
    final bottomNode = Offset(cx, cy + h * 0.4);

    canvas.drawLine(centerNode, topNode, linePaint);
    canvas.drawLine(centerNode, leftNode, linePaint);
    canvas.drawLine(centerNode, rightNode, linePaint);
    canvas.drawLine(centerNode, bottomNode, linePaint);
    canvas.drawLine(topNode, leftNode, linePaint);
    canvas.drawLine(topNode, rightNode, linePaint);
    canvas.drawLine(bottomNode, leftNode, linePaint);
    canvas.drawLine(bottomNode, rightNode, linePaint);

    canvas.drawCircle(topNode, 2.5, nodePaint);
    canvas.drawCircle(leftNode, 2.5, nodePaint);
    canvas.drawCircle(rightNode, 2.5, nodePaint);
    canvas.drawCircle(bottomNode, 2.5, nodePaint);

    final glowPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(centerNode, 4, glowPaint);
    canvas.drawCircle(centerNode, 3.5, nodePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
