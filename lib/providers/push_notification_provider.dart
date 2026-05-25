/**
 * PUSH NOTIFICATION PROVIDER
 *
 * PURPOSE:
 * This file serves as the central hub for managing all remote and local notifications
 * within the RTS application. It uses Firebase Cloud Messaging (FCM) for remote
 * alerts and Flutter Local Notifications for foreground display.
 *
 * KEY RESPONSIBILITIES:
 * 1. Initialization: Configures FCM background/foreground listeners and notification channels.
 * 2. Token Management: Handles fetching, saving, and registering FCM tokens with the
 * backend API, including refreshing tokens automatically.
 * 3. Auth Integration: Automatically registers the token when a user logs in and
 * unregisters it upon logout by listening to the `authProvider`.
 * 4. Foreground Notifications: Displays custom local alerts with interactive action
 * buttons only for food reminders. New request notifications show without buttons.
 * 5. Navigation: Redirects users to specific screens (Food Subscription / Dashboard)
 * when a notification is tapped, using the global `navigatorKey`.
 *
 * STATE:
 * - Returns a boolean: `true` if the device token is successfully registered with the backend,
 * `false` otherwise.
 *
 * NOTIFICATION ACTIONS:
 * - 'food_reminder' → navigates to FoodSubscriptionScreen (with Yes/No buttons)
 * - 'new_request' → navigates to DashboardScreen (no buttons)
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/services/push_notifications_api.dart';
import 'auth_provider.dart';
import '../../main.dart';
import 'package:rts/features/food_request/food_subscription_screen.dart';
import 'package:rts/features/dashboard/dashboard_screen.dart';

// ─────────────────────────────────────────────
// BACKGROUND HANDLER
// Must be top-level function outside any class
// ─────────────────────────────────────────────

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message received: ${message.messageId}');
  debugPrint('Background message data: ${message.data}');
}

class PushNotificationNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final PushNotificationsApi _pushApi;
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final GlobalKey<NavigatorState> _navigatorKey;

  PushNotificationNotifier(this._ref, this._pushApi, this._navigatorKey)
      : _firebaseMessaging = FirebaseMessaging.instance,
        _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(),
        super(false);

  // ─────────────────────────────────────────────
  // NAVIGATION HELPER
  // Single place to handle all navigation logic
  // ─────────────────────────────────────────────

  void _navigateBasedOnAction(String? action) {
    debugPrint('=== NAVIGATION CALLED ===');
    debugPrint('Action: $action');
    debugPrint('NavigatorKey: $_navigatorKey');
    debugPrint('CurrentState: ${_navigatorKey.currentState}');
    // ↑ if this prints NULL → that's the problem
    debugPrint('========================');

        //debugPrint('Navigating based on action: $action');

    if (action == 'food_reminder') {
      // Food reminder → go to FoodSubscriptionScreen
      debugPrint('Trying to navigate to FoodSubscriptionScreen...');
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const FoodSubscriptionScreen(),
        ),
      );
    } else if (action == 'new_request') {
      // New request → go to DashboardScreen
      debugPrint('Trying to navigate to DashboardScreen...');
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    } else {
      debugPrint('Unknown action: $action — no navigation performed');
    }
  }

  // ─────────────────────────────────────────────
  // INITIALIZE
  // Called once when app starts from main.dart
  // ─────────────────────────────────────────────

  Future<void> initialize() async {
    debugPrint('===INITALIZE CALLES===');
    // Step 1: Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Step 2: Set up local notification UI
    await _initLocalNotifications();

    // Step 3: Ask user for notification permission
    await _requestPermissions();
    debugPrint('=== PERMISSION DONE===');

    // Step 4: Handle terminated/closed state
    // When app is fully closed and user taps notification
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification');
      debugPrint('Terminated message data: ${initialMessage.data}');

      // Wait for first frame so navigatorKey is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateBasedOnAction(initialMessage.data['action']);
      });
    }

    // Step 5: Listen for foreground notifications
    // App is open — Firebase won't auto show, so we show manually
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('=== FOREGROUND NOTIFICATION RECEIVED ===');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('DATA: ${message.data}');
      debugPrint('ACTION: ${message.data['action']}');
      debugPrint('=========================================');

      final action = message.data['action'];

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {

        // ─────────────────────────────────
        // FOOD REMINDER — show WITH buttons
        // ─────────────────────────────────
        if (action == 'food_reminder') {
          const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'food_reminder_channel',
            'Food Reminders',
            channelDescription: 'Notifications for weekly food reminders.',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('yes', "Yes, I'm done ✓"),
              AndroidNotificationAction('no', 'No, take me there →'),
            ],
          );

          const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

          _flutterLocalNotificationsPlugin.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: platformDetails,
            payload: action, // 'food_reminder'
          );
        }

        // ─────────────────────────────────
        // NEW REQUEST — show WITHOUT buttons
        // ─────────────────────────────────
        else if (action == 'new_request') {
          const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'new_request_channel',
            'New Requests',
            channelDescription: 'Notifications for new requests.',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            // No actions = no buttons ✅
          );

          const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

          _flutterLocalNotificationsPlugin.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: platformDetails,
            payload: action, // 'new_request'
          );
        }
      }
    });

    // Step 6: Listen for notification taps from background state
    // App is minimized — user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('=== BACKGROUND TAP — notification opened app ===');
      debugPrint('DATA: ${message.data}');
      debugPrint('ACTION: ${message.data['action']}');
      debugPrint('=================================================');

      _navigateBasedOnAction(message.data['action']);
    });

    // Step 7: Listen for token refreshes
    // FCM token can change — update backend automatically
    _firebaseMessaging.onTokenRefresh.listen((fcmToken) {
      debugPrint('FCM Token refreshed: $fcmToken');
      _registerTokenWithBackend(fcmToken);
    }).onError((err) {
      debugPrint('Error refreshing FCM Token: $err');
    });

    // Step 8: Listen to auth state changes
    // Register token on login, unregister on logout
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.user == null && next.user != null) {
        debugPrint('User logged in — registering FCM token...');
        _registerTokenWithBackend(null);
      } else if (previous?.user != null && next.user == null) {
        debugPrint('User logged out — unregistering FCM token...');
        _unregisterTokenWithBackend(null);
      }
    });

    // Step 9: Already logged in when app opens
    // Streams won't fire for existing session, handle manually
    final authState = _ref.read(authProvider);
    if (authState.user != null) {
      debugPrint('Already logged in — registering initial FCM token...');
      _registerTokenWithBackend(null);
    }
  }

  // ─────────────────────────────────────────────
  // LOCAL NOTIFICATIONS SETUP
  // Sets up channels and button tap responses
  // ─────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('=== NOTIFICATION BUTTON TAPPED ===');
        debugPrint('Action ID: ${response.actionId}');
        debugPrint('Payload: ${response.payload}');
        debugPrint('==================================');

        // payload = action value we set earlier
        // ('food_reminder' or 'new_request')
        final action = response.payload;

        if (response.actionId == 'no') {
          // User tapped "No, take me there →" button
          // Only food_reminder has this button
          // so action will always be 'food_reminder' here
          _navigateBasedOnAction(action);
        }
        // 'yes' button — just dismisses, nothing to do
        // new_request has no buttons so won't reach here
      },
    );

    // ─────────────────────────────────
    // Create food reminder channel
    // ─────────────────────────────────
    const AndroidNotificationChannel foodChannel =
    AndroidNotificationChannel(
      'food_reminder_channel',
      'Food Reminders',
      description: 'Notifications for weekly food reminders.',
      importance: Importance.max,
    );

    // ─────────────────────────────────
    // Create new request channel
    // ─────────────────────────────────
    const AndroidNotificationChannel newRequestChannel =
    AndroidNotificationChannel(
      'new_request_channel',
      'New Requests',
      description: 'Notifications for new requests.',
      importance: Importance.max,
    );

    // Register both channels with Android
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(foodChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(newRequestChannel);
  }

  // ─────────────────────────────────────────────
  // PERMISSIONS
  // ─────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    NotificationSettings settings =
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint(
        'Notification permission status: ${settings.authorizationStatus}');
  }

  // ─────────────────────────────────────────────
  // TOKEN MANAGEMENT
  // ─────────────────────────────────────────────

  Future<void> _registerTokenWithBackend(String? fcmToken) async {
    try {
      final token = fcmToken ?? await _firebaseMessaging.getToken();
      debugPrint('FCM TOKEN: $token');

      if (token == null) {
        debugPrint('FCM Token is null — cannot register.');
        state = false;
        return;
      }

      await _pushApi.registerToken(token);
      debugPrint('FCM Token registered successfully with backend.');
      _saveTokenLocally(token);
      state = true;
    } catch (e) {
      debugPrint('Error registering FCM Token with backend: $e');
      state = false;
    }
  }

  Future<void> _unregisterTokenWithBackend(String? fcmToken) async {
    try {
      String? token = fcmToken ?? await _firebaseMessaging.getToken();

      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        final storedToken = prefs.getString('fcm_token');

        if (storedToken == null) {
          debugPrint(
              'FCM Token is null and no stored token — cannot unregister.');
          state = false;
          return;
        }
        token = storedToken;
      }

      await _pushApi.unregisterToken(token!);
      debugPrint('FCM Token unregistered successfully from backend.');
      _removeTokenLocally();
      state = false;
    } catch (e) {
      debugPrint('Error unregistering FCM Token with backend: $e');
      state = true;
    }
  }

  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    debugPrint('FCM Token saved locally: $token');
  }

  Future<void> _removeTokenLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fcm_token');
    debugPrint('FCM Token removed locally.');
  }

  // ─────────────────────────────────────────────
  // PUBLIC METHODS
  // ─────────────────────────────────────────────

  // Delete token completely and unregister from backend
  // Use for account deletion or security scenarios
  Future<void> deleteAndUnregisterToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _firebaseMessaging.deleteToken();
      await _unregisterTokenWithBackend(token);
    }
  }

  // Send test notification — use during development only
  Future<void> sendTestNotification() async {
    try {
      await _pushApi.sendTestNotification(
          'Test Title', 'This is a test notification from RTS App');
      debugPrint('Test notification request sent to backend.');
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
  }
}

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────

final pushNotificationProvider =
StateNotifierProvider<PushNotificationNotifier, bool>((ref) {
  final pushApi = ref.watch(pushNotificationsApiProvider);
  return PushNotificationNotifier(ref, pushApi, navigatorKey);
});