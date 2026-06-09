import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var phoneAuthChannel: FlutterMethodChannel?

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
    #if DEBUG
    let tokenType: AuthAPNSTokenType = .sandbox
    #else
    let tokenType: AuthAPNSTokenType = .prod
    #endif
    Auth.auth().setAPNSToken(token, type: tokenType)
    NSLog("[OTP_DEBUG] syncApnsToAuth: copied token to Auth (type=%@)", tokenType == .sandbox ? "sandbox" : "prod")
    return Auth.auth().apnsToken != nil
  }

  private func debugApnsStatus() -> [String: Any] {
    let authToken = Auth.auth().apnsToken
    let msgToken = Messaging.messaging().apnsToken
    #if DEBUG
    let buildType = "debug"
    #else
    let buildType = "release"
    #endif
    return [
      "buildType": buildType,
      "authHasApnsToken": authToken != nil,
      "authTokenBytes": authToken?.count ?? 0,
      "messagingHasApnsToken": msgToken != nil,
      "messagingTokenBytes": msgToken?.count ?? 0,
    ]
  }

  /// Forward silent Firebase Auth verification pushes (phone OTP).
  private func forwardAuthNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    if Auth.auth().canHandleNotification(userInfo) {
      NSLog("[OTP_DEBUG] Auth handled phone-verification notification")
      return true
    }
    return false
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    #if DEBUG
    let tokenType: AuthAPNSTokenType = .sandbox
    #else
    let tokenType: AuthAPNSTokenType = .prod
    #endif
    Auth.auth().setAPNSToken(deviceToken, type: tokenType)
    Messaging.messaging().apnsToken = deviceToken
    NSLog(
      "[OTP_DEBUG] didRegisterForRemoteNotifications tokenBytes=%lu type=%@",
      deviceToken.count,
      tokenType == .sandbox ? "sandbox" : "prod"
    )
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
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
    if forwardAuthNotification(userInfo) {
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
    if forwardAuthNotification(userInfo) {
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
    if forwardAuthNotification(userInfo) {
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
    if forwardAuthNotification(userInfo) {
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
      NSLog("[OTP_DEBUG] Auth handled reCAPTCHA redirect URL")
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
