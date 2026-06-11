import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

private final class TokenWaitBox {
  var responded = false
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  private var phoneAuthChannel: FlutterMethodChannel?
  private var pendingTokenWaiters: [(Data?) -> Void] = []
  private var remoteNotificationCount: Int = 0

  /// Debug/profile → development entitlement (sandbox). Release/TestFlight → production.
  private func resolvedAuthApnsTokenType() -> AuthAPNSTokenType {
    #if DEBUG
    return .sandbox
    #elseif PROFILE
    return .sandbox
    #else
    return .prod
    #endif
  }

  private func apnsTypeLabel(_ type: AuthAPNSTokenType) -> String {
    switch type {
    case .sandbox: return "sandbox"
    case .prod: return "prod"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Proxy ON — Firebase swizzles APNs; we still sync Auth token + forward silent OTP pushes below.
    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    requestNotificationsAndRegister(application)
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

    DispatchQueue.main.async { [weak self] in
      self?.requestNotificationsAndRegister(UIApplication.shared)
    }
  }

  private func requestNotificationsAndRegister(_ application: UIApplication) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      DispatchQueue.main.async {
        if let error {
          NSLog("[OTP_DEBUG] notification authorization error: %@", error.localizedDescription)
        }
        NSLog("[OTP_DEBUG] notification authorization granted=%@", granted ? "YES" : "NO")
        application.registerForRemoteNotifications()
      }
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
    case "prepareForPhoneAuth":
      prepareForPhoneAuth(result: result)
    case "resetNotificationCounter":
      remoteNotificationCount = 0
      result(["ok": true])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func prepareForPhoneAuth(result: @escaping FlutterResult) {
    remoteNotificationCount = 0
    let tokenType = resolvedAuthApnsTokenType()

    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let status = settings.authorizationStatus
        let authorized = status == .authorized || status == .provisional

        if !authorized {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
              if !granted {
                result(self.debugApnsStatus(extra: [
                  "authorized": false,
                  "authorizationStatus": "\(status.rawValue)",
                ]))
                return
              }
              self.waitForApnsTokenThenRespond(result: result, tokenType: tokenType)
            }
          }
          return
        }

        self.waitForApnsTokenThenRespond(result: result, tokenType: tokenType)
      }
    }
  }

  private func waitForApnsTokenThenRespond(result: @escaping FlutterResult, tokenType: AuthAPNSTokenType) {
    if let existing = Messaging.messaging().apnsToken ?? Auth.auth().apnsToken {
      applyApnsToken(existing, type: tokenType)
      result(debugApnsStatus(extra: ["authorized": true, "waitedForToken": false]))
      return
    }

    let box = TokenWaitBox()
    let finish: (Data?) -> Void = { [weak self] token in
      guard let self, !box.responded else { return }
      box.responded = true
      if let token {
        self.applyApnsToken(token, type: tokenType)
      }
      result(self.debugApnsStatus(extra: [
        "authorized": true,
        "waitedForToken": true,
        "tokenReceived": token != nil,
      ]))
    }

    pendingTokenWaiters.append(finish)
    UIApplication.shared.registerForRemoteNotifications()

    DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
      guard let self, !box.responded else { return }
      box.responded = true
      self.pendingTokenWaiters.removeAll()
      if let token = Messaging.messaging().apnsToken ?? Auth.auth().apnsToken {
        self.applyApnsToken(token, type: tokenType)
      }
      result(self.debugApnsStatus(extra: [
        "authorized": true,
        "waitedForToken": true,
        "tokenReceived": Messaging.messaging().apnsToken != nil,
        "timedOut": true,
      ]))
    }
  }

  private func applyApnsToken(_ deviceToken: Data, type: AuthAPNSTokenType? = nil) {
    let resolved = type ?? resolvedAuthApnsTokenType()
    // Auth must receive the token before Messaging for phone OTP silent push.
    Auth.auth().setAPNSToken(deviceToken, type: resolved)
    Messaging.messaging().apnsToken = deviceToken
    NSLog(
      "[OTP_DEBUG] applyApnsToken bytes=%lu type=%@ build=%@",
      deviceToken.count,
      apnsTypeLabel(resolved),
      buildTypeLabel()
    )
  }

  private func syncMessagingApnsTokenToAuth() -> Bool {
    guard let token = Messaging.messaging().apnsToken ?? Auth.auth().apnsToken else {
      NSLog("[OTP_DEBUG] syncApnsToAuth: no APNs token on device")
      return false
    }
    applyApnsToken(token)
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

  private func debugApnsStatus(extra: [String: Any] = [:]) -> [String: Any] {
    let authToken = Auth.auth().apnsToken
    let msgToken = Messaging.messaging().apnsToken
    let tokenType = resolvedAuthApnsTokenType()
    var status: [String: Any] = [:]
    status["buildType"] = buildTypeLabel()
    status["apsEnvironment"] = apsEnvironmentLabel()
    status["apnsTokenType"] = apnsTypeLabel(tokenType)
    status["authHasApnsToken"] = authToken != nil
    status["authTokenBytes"] = authToken?.count ?? 0
    status["messagingHasApnsToken"] = msgToken != nil
    status["messagingTokenBytes"] = msgToken?.count ?? 0
    status["remoteNotificationsReceived"] = remoteNotificationCount
    status["isRegisteredForRemoteNotifications"] = UIApplication.shared.isRegisteredForRemoteNotifications
    status["firebaseProxyEnabled"] = true
    for (key, value) in extra {
      status[key] = value
    }
    return status
  }

  private func logRemoteNotification(_ userInfo: [AnyHashable: Any], source: String) {
    remoteNotificationCount += 1
    let keys = userInfo.keys.map { "\($0)" }.sorted().joined(separator: ", ")
    NSLog("[OTP_DEBUG] remoteNotification #%d source=%@ keys=[%@]", remoteNotificationCount, source, keys)
    if let aps = userInfo["aps"] {
      NSLog("[OTP_DEBUG] remoteNotification aps=%@", String(describing: aps))
    }
    if let firebaseAuth = userInfo["com.google.firebase.auth"] {
      NSLog("[OTP_DEBUG] remoteNotification firebaseAuth=%@", String(describing: firebaseAuth))
    }
  }

  /// Forward silent Firebase Auth verification pushes (phone OTP). Auth is checked before Messaging/FCM.
  private func forwardAuthNotification(_ userInfo: [AnyHashable: Any], source: String) -> Bool {
    logRemoteNotification(userInfo, source: source)
    if Auth.auth().canHandleNotification(userInfo) {
      NSLog("[OTP_DEBUG] canHandleNotification source=%@ handled=YES", source)
      return true
    }
    NSLog("[OTP_DEBUG] canHandleNotification source=%@ handled=NO", source)
    return false
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Let Flutter/Firebase plugins run first, then re-apply so Auth keeps the final token.
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    applyApnsToken(deviceToken)
    let waiters = pendingTokenWaiters
    pendingTokenWaiters.removeAll()
    waiters.forEach { $0(deviceToken) }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[OTP_DEBUG] APNs registration failed: %@", error.localizedDescription)
    let waiters = pendingTokenWaiters
    pendingTokenWaiters.removeAll()
    waiters.forEach { $0(nil) }
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

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    NSLog("[OTP_DEBUG] FCM registration token refreshed: %@", fcmToken ?? "nil")
    syncMessagingApnsTokenToAuth()
  }
}
