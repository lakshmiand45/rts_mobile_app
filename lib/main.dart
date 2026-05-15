import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/food_request/food_request_screen.dart';
import 'features/food_request/food_subscription_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/food_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: RTSApp(),
    ),
  );
}

class RTSApp extends ConsumerStatefulWidget {
  const RTSApp({super.key});

  @override
  ConsumerState<RTSApp> createState() => _RTSAppState();
}

class _RTSAppState extends ConsumerState<RTSApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();
    final appLink = await _appLinks.getInitialLink();
    if (appLink != null) {
      _handleDeepLink(appLink);
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.startsWith('/reset-password/')) {
      final token = uri.pathSegments.last;
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(token: token),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'RTS System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C59E8),
          primary: const Color(0xFF5C59E8),
          secondary: const Color(0xFF10B981),
          error: const Color(0xFFEF4444),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF5C59E8), width: 1.5),
          ),
        ),
      ),
      home: authState.user == null ? const LoginScreen() : const RoleBaseWrapper(),
    );
  }
}

class RoleBaseWrapper extends ConsumerWidget {
  const RoleBaseWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const LoginScreen();

    final bool isBangalore = user.location.toLowerCase() == 'bangalore';
    final bool isIntern = user.role.toLowerCase().contains('intern');

    if (isIntern) {
      if (!isBangalore) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Food services are only available in Bangalore.'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        );
      }

      final foodState = ref.watch(foodProvider);

      if (!foodState.isInitialized) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (!foodState.hasSeenOnboarding) {
        return const FoodRequestScreen();
      }

      return const FoodSubscriptionScreen();
    }

    return const DashboardScreen();
  }
}