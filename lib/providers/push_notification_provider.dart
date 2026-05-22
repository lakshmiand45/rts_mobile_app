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
 *    backend API, including refreshing tokens automatically.
 * 3. Auth Integration: Automatically registers the token when a user logs in and
 *    unregisters it upon logout by listening to the `authProvider`.
 * 4. Foreground Notifications: Displays custom local alerts with interactive action
 *    buttons (e.g., "Yes, I'm done" / "No, take me there") when the app is active.
 * 5. Navigation: Redirects users to specific screens (like the Food Request page)
 *    when a notification is tapped, using the global `navigatorKey`.
 *
 * STATE:
 * - Returns a boolean: `true` if the device token is successfully registered with the backend,
 *   `false` otherwise.
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
import '../../main.dart'; // Import to access global navigatorKey

// A `typedef` for the background message handler
// Needs to be a top-level function.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  // Ensure Firebase is initialized in its own isolate when handling background messages
  await Firebase.initializeApp();

  // For now, just print the message. We'll handle local notifications later.
  debugPrint('Background Message data: ${message.data}');
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

  // Initialize all notification-related setups
  Future<void> initialize() async {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize flutter_local_notifications
    await _initLocalNotifications();

    // Request permissions (Android handled automatically for basic features, but explicit for Android 13+)
    await _requestPermissions();

    // Handle messages in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If `notification` is null, assume a data-only message and still try to show it
      if (notification != null && android != null) {
        // Define action buttons for Android
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'food_reminder_channel', // Must match the channel ID created in _initLocalNotifications
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
        const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

        _flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: platformChannelSpecifics, // Use named parameter 'notificationDetails'
          payload: message.data['action'], // Use the action from data for payload
        );
      }
    });

    // Handle when a notification is tapped from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('onMessageOpenedApp: A new RemoteMessage was published!');
      if (message.data['action'] == 'food_reminder') {
        _navigatorKey.currentState?.pushNamed('/food');
      }
    });

    // Listen to token changes and re-register
    _firebaseMessaging.onTokenRefresh.listen((fcmToken) {
      debugPrint('FCM Token refreshed: $fcmToken');
      _registerTokenWithBackend(fcmToken);
    }).onError((err) {
      debugPrint('Error refreshing FCM Token: $err');
    });

    // Listen to auth state changes to register/unregister FCM token
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.user == null && next.user != null) {
        // User logged in, register token
        debugPrint('User logged in, registering FCM token...');
        _registerTokenWithBackend(null); // Pass null to get current token
      } else if (previous?.user != null && next.user == null) {
        // User logged out, unregister token
        debugPrint('User logged out, unregistering FCM token...');
        _unregisterTokenWithBackend(null); // Pass null to get current token
      }
    });

    // Handle initial token registration if already logged in
    final authState = _ref.read(authProvider);
    if (authState.user != null) {
      debugPrint('Already logged in, registering initial FCM token...');
      _registerTokenWithBackend(null);
    }
  }

  // Initialize FlutterLocalNotificationsPlugin
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings (even though we're focusing on Android, keep the structure)
    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('onDidReceiveNotificationResponse: payload: ${response.payload}, actionId: ${response.actionId}, input: ${response.input}');
        if (response.actionId == 'no') {
          // Navigate to Food tab
          _navigatorKey.currentState?.pushNamed('/food');
        }
        // 'yes' action is handled by dismissing the notification, no further action needed here.
      },
    );

    // Create a notification channel for Android 8.0+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'food_reminder_channel', // id
      'Food Reminders', // title
      description: 'Notifications for weekly food reminders.', // description
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  // Register FCM token with your backend
  Future<void> _registerTokenWithBackend(String? fcmToken) async {
    try {
      final token = fcmToken ?? await _firebaseMessaging.getToken();
      debugPrint("FCM TOKEN: $token");
      if (token == null) {
        debugPrint('FCM Token is null, cannot register.');
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

  // Unregister FCM token from your backend
  Future<void> _unregisterTokenWithBackend(String? fcmToken) async {
    try {
      String? token = fcmToken ?? await _firebaseMessaging.getToken();
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        final storedToken = prefs.getString('fcm_token');
        if (storedToken == null) {
          debugPrint('FCM Token is null and no stored token, cannot unregister.');
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

  // Save the FCM token locally
  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    debugPrint('FCM Token saved locally: $token');
  }

  // Remove the FCM token locally
  Future<void> _removeTokenLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fcm_token');
    debugPrint('FCM Token removed locally.');
  }

  // Exposed method to delete token and unregister
  Future<void> deleteAndUnregisterToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _firebaseMessaging.deleteToken();
      await _unregisterTokenWithBackend(token);
    }
  }

  // Method to send a test notification
  Future<void> sendTestNotification() async {
    try {
      await _pushApi.sendTestNotification('Test Title', 'This is a test notification from RTS App');
      debugPrint('Test notification request sent to backend.');
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
  }
}

final pushNotificationProvider = StateNotifierProvider<PushNotificationNotifier, bool>((ref) {
  final pushApi = ref.watch(pushNotificationsApiProvider);
  return PushNotificationNotifier(ref, pushApi, navigatorKey);
});