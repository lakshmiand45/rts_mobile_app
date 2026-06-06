// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rts/main.dart';
import 'package:rts/providers/auth_provider.dart';
import 'package:rts/models/user_model.dart';
import 'package:rts/providers/push_notification_provider.dart';
import 'package:rts/core/services/api_service.dart';
import 'package:rts/core/services/push_notifications_api.dart'; // Import PushNotificationsApi
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Import for GlobalKey

// Mock ApiService
class MockApiService extends ApiService {
  MockApiService(); // No explicit constructor, as base ApiService uses a default.

  @override
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    return http.Response('{}', 200);
  }

  @override
  Future<http.Response> post(String path, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    return http.Response('{}', 200);
  }
}

// Mock PushNotificationsApi
class MockPushNotificationsApi extends PushNotificationsApi {
  MockPushNotificationsApi(ApiService apiService) : super(apiService);

  @override
  Future<dynamic> registerToken(String token) async { return {}; }
  @override
  Future<dynamic> unregisterToken(String token) async { return {}; }
  @override
  Future<dynamic> sendTestNotification(String title, String body) async { return {}; }
}

// Mock PushNotificationNotifier to avoid actual Firebase Messaging calls
class MockPushNotificationNotifier extends PushNotificationNotifier {
  MockPushNotificationNotifier(Ref ref, PushNotificationsApi pushApi, GlobalKey<NavigatorState> navigatorKey)
      : super(ref, pushApi, navigatorKey);

  @override
  Future<void> initialize() async {
    // Do nothing in test mode
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock Firebase Core method channel
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'Firebase#initializeCore') {
          return null;
        }
        return null;
      },
    );
     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_messaging'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'Messaging#getInitialMessage') {
          return null;
        }
        return null;
      },
    );
  });

  testWidgets('App renders LoginScreen without crashing in test mode', (WidgetTester tester) async {
    // Create mock instances
    final mockApiService = MockApiService();
    final mockPushNotificationsApi = MockPushNotificationsApi(mockApiService);
    final mockNavigatorKey = GlobalKey<NavigatorState>(); // Create a mock navigator key

    // Override providers for testing
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApiService), // Override apiServiceProvider itself
          authProvider.overrideWith(
            (ref) => AuthNotifier(mockApiService),
          ),
          pushNotificationsApiProvider.overrideWithValue(mockPushNotificationsApi), // Override pushNotificationsApiProvider
          pushNotificationProvider.overrideWith(
            (ref) => MockPushNotificationNotifier(ref, mockPushNotificationsApi, mockNavigatorKey),
          ),
        ],
        child: const RTSApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the LoginScreen is rendered by looking for text commonly found on it.
    // Assuming the LoginScreen has a visible "Login" text or similar.
    expect(find.text('Login'), findsOneWidget);
  });
}
