import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var phoneAuthChannel: FlutterMethodChannel?

  /// Firebase recommends `.unknown` so Auth infers sandbox vs production (firebase-ios-sdk #13502).
  private let authApnsTokenType: AuthAPNSTokenType = .unknown

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    UNUserNotificationCenter.current().delegate = self
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    application.registerForRemoteNotifications()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    phoneAuthChannel = FlutterMethodChannel(
      name: "com.realtorone.app/phone_auth",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    phoneAuthChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handlePhoneAuthCall(call, result: result)
    }

    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  private func handlePhoneAuthCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "debugStatus":
      result(debugApnsStatus())
    case "syncApnsToAuth":
      _ = syncMessagingApnsTokenToAuth()
      UIApplication.shared.registerForRemoteNotifications()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        result(self.debugApnsStatus())
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func syncMessagingApnsTokenToAuth() -> Bool {
    guard let token = Messaging.messaging().apnsToken else {
      NSLog("[OTP_DEBUG] syncApnsToAuth: Messaging.apnsToken is nil")
      return false
    }
    Auth.auth().setAPNSToken(token, type: authApnsTokenType)
    NSLog("[OTP_DEBUG] syncApnsToAuth: copied token to Auth (type=unknown)")
    return Auth.auth().apnsToken != nil
  }

  private func buildTypeLabel() -> String {
    #if DEBUG
    return "debug"
    #elseif PROFILE
    return "profile"
    #else
    return "release"
    #endif
  }

  private func apsEnvironmentLabel() -> String {
    #if DEBUG
    return "development"
    #elseif PROFILE
    return "development"
    #else
    return "production"
    #endif
  }

  private func debugApnsStatus() -> [String: Any] {
    let authToken = Auth.auth().apnsToken
    let msgToken = Messaging.messaging().apnsToken
    return [
      "buildType": buildTypeLabel(),
      "apsEnvironment": apsEnvironmentLabel(),
      "apnsTokenType": "unknown",
      "authHasApnsToken": authToken != nil,
      "authTokenBytes": authToken?.count ?? 0,
      "messagingHasApnsToken": msgToken != nil,
      "messagingTokenBytes": msgToken?.count ?? 0,
    ]
  }

  private func logRemoteNotification(_ userInfo: [AnyHashable: Any], source: String) {
    let keys = userInfo.keys.map { "\($0)" }.sorted().joined(separator: ", ")
    NSLog("[OTP_DEBUG] remoteNotification source=%@ keyCount=%lu keys=[%@]", source, userInfo.count, keys)
    if let aps = userInfo["aps"] {
      NSLog("[OTP_DEBUG] remoteNotification source=%@ aps=%@", source, String(describing: aps))
    }
    if let firebaseAuth = userInfo["com.google.firebase.auth"] {
      NSLog("[OTP_DEBUG] remoteNotification source=%@ firebaseAuth=%@", source, String(describing: firebaseAuth))
    }
  }

  /// Forward silent Firebase Auth verification pushes (phone OTP).
  private func forwardAuthNotification(_ userInfo: [AnyHashable: Any], source: String) -> Bool {
    logRemoteNotification(userInfo, source: source)
    let handled = Auth.auth().canHandleNotification(userInfo)
    NSLog("[OTP_DEBUG] canHandleNotification source=%@ handled=%@", source, handled ? "YES" : "NO")
    if handled {
      NSLog("[OTP_DEBUG] Auth handled phone-verification notification")
    }
    return handled
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Let FlutterFire plugins register first; then ensure Auth has the final token type.
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    Messaging.messaging().apnsToken = deviceToken
    Auth.auth().setAPNSToken(deviceToken, type: authApnsTokenType)
    NSLog(
      "[OTP_DEBUG] didRegisterForRemoteNotifications tokenBytes=%lu type=unknown build=%@ aps=%@",
      deviceToken.count,
      buildTypeLabel(),
      apsEnvironmentLabel()
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[OTP_DEBUG] APNs registration failed: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if forwardAuthNotification(userInfo, source: "fetchCompletionHandler") {
      completionHandler(.noData)
      return
    }
    if userInfo["gcm.message_id"] != nil {
      Messaging.messaging().appDidReceiveMessage(userInfo)
    }
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) {
    if forwardAuthNotification(userInfo, source: "legacy") {
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    if forwardAuthNotification(userInfo, source: "willPresent") {
      completionHandler([])
      return
    }
    super.userNotificationCenter(
      center,
      willPresent: notification,
      withCompletionHandler: completionHandler
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if forwardAuthNotification(userInfo, source: "didReceiveResponse") {
      completionHandler()
      return
    }
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) {
      NSLog("[OTP_DEBUG] Auth handled reCAPTCHA redirect URL: %@", url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
