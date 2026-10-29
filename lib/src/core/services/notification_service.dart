import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'logger_service.dart';
import 'startup_prompt_queue.dart';

/// Callback type for handling notification taps
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Callback type for foreground message events
typedef ForegroundMessageCallback = void Function();

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info('Handling background message: ${message.messageId}');
}

/// Service for managing push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationTapCallback? _onNotificationTap;
  ForegroundMessageCallback? _onForegroundMessage;
  bool _initialized = false;

  /// A tap that arrived before anything could route it - above all the one
  /// that launched the app, which is read in main() long before the router and
  /// the signed-in session exist. Delivered when [attachHandlers] is called.
  Map<String, dynamic>? _pendingTap;

  /// The status-bar icon: white on transparent, as Android requires. The
  /// launcher icon used before is full colour and rendered as a white blob.
  static const String _smallIcon = '@drawable/ic_stat_notification';

  /// Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'odyssey_notifications',
    'Odyssey Notifications',
    description: 'Notifications from Odyssey app',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize the notification service
  ///
  /// Called once from main(), before there is anywhere to send a tap. The
  /// handlers come later through [attachHandlers]. Passing them here still
  /// works, on the first call or any later one.
  Future<void> initialize({
    NotificationTapCallback? onNotificationTap,
    ForegroundMessageCallback? onForegroundMessage,
  }) async {
    // A second call used to return here before storing its callbacks. main()
    // makes the first call with none, so the handlers the signed-in session
    // passed were dropped and no tap was ever routed anywhere.
    if (onNotificationTap != null || onForegroundMessage != null) {
      attachHandlers(
        onNotificationTap: onNotificationTap,
        onForegroundMessage: onForegroundMessage,
      );
    }
    if (_initialized) return;

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Deliberately no permission request here.
    //
    // This runs from main(), so asking here put the iOS system dialog on screen
    // during launch, before the person had seen anything of the app. App Review
    // rejects that, and it is also the surest way to get a refusal - which is
    // permanent, because the dialog is only ever shown once.
    //
    // The request now lives behind our own explanation sheet; see
    // NotificationPermissionPolicy and showNotificationPermissionSheet. Setting
    // up the handlers below does not require permission, so a person who has not
    // decided yet still gets a fully working app.

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification - a push, or one of ours
    // shown while the app was in the foreground.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    } else {
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && payload != null) {
        _deliverTap(decodePayload(payload));
      }
    }

    _initialized = true;
    AppLogger.info('NotificationService initialized');
  }

  /// Sets where taps and foreground arrivals go, and delivers a tap that was
  /// waiting for somewhere to go.
  void attachHandlers({
    NotificationTapCallback? onNotificationTap,
    ForegroundMessageCallback? onForegroundMessage,
  }) {
    if (onNotificationTap != null) _onNotificationTap = onNotificationTap;
    if (onForegroundMessage != null) _onForegroundMessage = onForegroundMessage;

    final pending = _pendingTap;
    if (pending != null && _onNotificationTap != null) {
      _pendingTap = null;
      _onNotificationTap!(pending);
    }
  }

  void _deliverTap(Map<String, dynamic> data) {
    final handler = _onNotificationTap;
    if (handler == null) {
      _pendingTap = data;
      return;
    }
    handler(data);
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(_smallIcon);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  /// Request notification permissions
  ///
  /// Queued with the other startup prompts. This runs during `main()` while the
  /// UMP consent flow is running in the background, and two system modals
  /// presented at once are drawn over each other - with a tap meant for one
  /// landing on the other. Ordering them costs a moment at launch and makes the
  /// sequence the same every time.
  Future<bool> requestPermission() async {
    final settings = await StartupPromptQueue.instance.enqueue(
      'notification-permission',
      () => _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      ),
    );

    if (settings == null) return false;

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    AppLogger.info('Notification permission: ${settings.authorizationStatus}');
    return granted;
  }

  /// Whether notifications are allowed right now, without asking for them.
  Future<bool> hasPermission() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      AppLogger.error('Could not read notification settings', e);
      return false;
    }
  }

  /// Opens this app's page in the system settings.
  ///
  /// The only route left once the OS dialog has been answered: it is shown once,
  /// and after that `requestPermission` returns the existing answer without
  /// presenting anything.
  ///
  /// Through Geolocator, which looks odd until you notice the alternative is a
  /// second permissions package for one method. `openAppSettings` is not about
  /// location - it opens the app's own settings page on both platforms, and that
  /// page is where the notification toggle lives. Named for what it does here.
  Future<bool> openSystemNotificationSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      AppLogger.error('Could not open the system settings', e);
      return false;
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      AppLogger.info('FCM Token obtained: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      AppLogger.error('Failed to get FCM token', e);
      return null;
    }
  }

  /// Listen for token refresh events
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('Received foreground message: ${message.messageId}');

    // Notify listener that a foreground message arrived (for badge update).
    // Every message adds a history row on the server, data-only ones included.
    _onForegroundMessage?.call();

    final notification = message.notification;
    if (notification == null) return;

    // The system shows nothing for a push while the app is open; show it
    // ourselves.
    _showLocalNotification(
      title: notification.title ?? 'Odyssey',
      body: notification.body ?? '',
      data: message.data,
    );
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Build notification details
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: _smallIcon,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Generate unique notification ID
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    // Encode data as payload
    final payload = data != null ? jsonEncode(data) : null;

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Handle notification tap from FCM
  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.info('Notification tapped: ${message.messageId}');
    _deliverTap(message.data);
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    AppLogger.info('Local notification tapped');
    final payload = response.payload;
    if (payload != null) _deliverTap(decodePayload(payload));
  }

  /// Decodes a local notification's payload.
  ///
  /// JSON now. It was `key=value&key=value`, which dropped any pair whose
  /// value contained `=` and split values containing `&`. A notification shown
  /// by the previous version can still be tapped after an update, so that
  /// format is still read.
  static Map<String, dynamic> decodePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through to the old format.
    }

    final map = <String, dynamic>{};
    for (final pair in payload.split('&')) {
      final index = pair.indexOf('=');
      if (index > 0) map[pair.substring(0, index)] = pair.substring(index + 1);
    }
    return map;
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      AppLogger.info('Subscribed to topic: $topic');
    } catch (e) {
      AppLogger.error('Failed to subscribe to topic: $topic', e);
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      AppLogger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      AppLogger.error('Failed to unsubscribe from topic: $topic', e);
    }
  }

  /// Delete the FCM token (used on logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      AppLogger.info('FCM token deleted');
    } catch (e) {
      AppLogger.error('Failed to delete FCM token', e);
    }
  }
}
