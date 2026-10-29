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

    // No Messaging delegate of our own. FlutterFire's plugin installs itself as
    // the delegate when it registers, and that is how onTokenRefresh reaches
    // Dart; one set here only printed the token, and whichever was assigned
    // last won - under the UIScene lifecycle the plugin registers later, but
    // nothing guaranteed it.

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

