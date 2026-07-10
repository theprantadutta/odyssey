import Flutter
import UIKit
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase
    FirebaseApp.configure()

    // Set up push notifications
    UNUserNotificationCenter.current().delegate = self

    // Register for remote notifications
    application.registerForRemoteNotifications()

    // Set Firebase Messaging delegate
    Messaging.messaging().delegate = self

    // Plugin registration moved to didInitializeImplicitFlutterEngine
    // for the UIScene lifecycle (see flutter.dev/to/uiscene-migration).
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Register plugins once the implicit Flutter engine is ready. Under the
  // UIScene lifecycle, plugin registration must happen here rather than in
  // application(_:didFinishLaunchingWithOptions:).
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Handle registration for remote notifications
  override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // FCM token is received/refreshed
    // The flutter_firebase_messaging plugin handles this automatically
    if let token = fcmToken {
      print("FCM Token: \(token)")
    }
  }
}
