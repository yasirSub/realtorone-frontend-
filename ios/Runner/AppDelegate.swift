import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications
import AVFoundation

private final class TokenWaitBox {
  var responded = false
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate, AuthUIDelegate {
  private var phoneAuthChannel: FlutterMethodChannel?
  private var pendingTokenWaiters: [(Data?) -> Void] = []
  private var remoteNotificationCount: Int = 0

  /// Read signed aps-environment from embedded.mobileprovision (dev/ad-hoc builds).
  private func embeddedApsEnvironment() -> String? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let raw = String(data: data, encoding: .isoLatin1) else {
      return nil
    }
    guard let keyRange = raw.range(of: "aps-environment") else { return nil }
    let tail = raw[keyRange.upperBound...]
    if tail.contains("development") { return "development" }
    if tail.contains("production") { return "production" }
    return nil
  }

  /// Firebase Auth infers sandbox vs production from the embedded profile when `.unknown`.
  private func resolvedAuthApnsTokenType() -> AuthAPNSTokenType {
    .unknown
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

    configurePlaybackAudioSession()

    // Let FlutterAppDelegate + Firebase proxy own UNUserNotificationCenter first.
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    Messaging.messaging().delegate = self
    let tokenType = resolvedAuthApnsTokenType()
    NSLog(
      "[OTP_DEBUG] launch aps=%@ authApnsType=%@ bundle=%@",
      embeddedApsEnvironment() ?? apsEnvironmentLabel(),
      apnsTypeLabel(tokenType),
      Bundle.main.bundleIdentifier ?? "unknown"
    )
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

  private func configurePlaybackAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .default,
        options: [.duckOthers, .defaultToSpeaker]
      )
      try session.setActive(true)
      NSLog("[Audio] AVAudioSession playback category active")
    } catch {
      NSLog("[Audio] AVAudioSession setup failed: %@", error.localizedDescription)
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
    case "embeddedApsEnvironment":
      result([
        "apsEnvironment": embeddedApsEnvironment() ?? apsEnvironmentLabel(),
        "apnsTokenType": apnsTypeLabel(resolvedAuthApnsTokenType()),
        "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
      ])
    case "verifyPhoneNumberNative":
      guard let args = call.arguments as? [String: Any],
            let phone = args["phoneNumber"] as? String else {
        result(FlutterError(code: "invalid-args", message: "phoneNumber required", details: nil))
        return
      }
      verifyPhoneNumberNative(phoneNumber: phone, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func isFirebaseAppDelegateProxyEnabled() -> Bool {
    guard let value = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppDelegateProxyEnabled") else {
      return true
    }
    if let enabled = value as? Bool { return enabled }
    if let text = value as? String {
      return text.lowercased() != "false" && text != "0"
    }
    return true
  }

  private func isNotificationNotForwardedError(_ error: Error) -> Bool {
    let nsError = error as NSError
    let name = nsError.userInfo["FIRAuthErrorUserInfoNameKey"] as? String ?? ""
    return name == "ERROR_NOTIFICATION_NOT_FORWARDED"
      || nsError.localizedDescription.contains("NOT_FORWARDED")
  }

  /// Native verify with AuthUIDelegate — Flutter firebase_auth plugin passes UIDelegate:nil.
  private func verifyPhoneNumberNative(phoneNumber: String, result: @escaping FlutterResult) {
    remoteNotificationCount = 0
    syncMessagingApnsTokenToAuth()
    UIApplication.shared.registerForRemoteNotifications()

    #if DEBUG
    Auth.auth().settings?.isAppVerificationDisabledForTesting = true
    NSLog(
      "[OTP_DEBUG] DEBUG build: isAppVerificationDisabledForTesting=true "
        + "(only works with fictional test numbers in Firebase Console — not real numbers)"
    )
    #endif

    NSLog("[OTP_DEBUG] native verifyPhoneNumber %@", phoneNumber)

    Auth.auth().initializeRecaptchaConfig { [weak self] error in
      if let error {
        NSLog("[OTP_DEBUG] initializeRecaptchaConfig: %@", error.localizedDescription)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self?.runNativeVerifyAttempt(phoneNumber: phoneNumber, isRetry: false, result: result)
      }
    }
  }

  private func runNativeVerifyAttempt(
    phoneNumber: String,
    isRetry: Bool,
    result: @escaping FlutterResult
  ) {
    if isRetry {
      NSLog("[OTP_DEBUG] retry verifyPhoneNumber after ERROR_NOTIFICATION_NOT_FORWARDED")
      syncMessagingApnsTokenToAuth()
      UIApplication.shared.registerForRemoteNotifications()
    }
    PhoneAuthProvider.provider().verifyPhoneNumber(
      phoneNumber,
      uiDelegate: self
    ) { [weak self] verificationId, error in
      guard let self else { return }
      if let error, !isRetry, self.isNotificationNotForwardedError(error) {
        NSLog(
          "[OTP_DEBUG] ERROR_NOTIFICATION_NOT_FORWARDED received=%d — re-registering APNs, retrying once",
          self.remoteNotificationCount
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          self.runNativeVerifyAttempt(phoneNumber: phoneNumber, isRetry: true, result: result)
        }
        return
      }
      self.finishNativeVerify(verificationId: verificationId, error: error, result: result)
    }
  }

  private func finishNativeVerify(
    verificationId: String?,
    error: Error?,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.main.async {
      if let error {
        let nsError = error as NSError
        let code = nsError.userInfo["FIRAuthErrorUserInfoNameKey"] as? String ?? "\(nsError.code)"
        NSLog(
          "[OTP_DEBUG] native verify failed code=%@ domain=%@ msg=%@ received=%d",
          code,
          nsError.domain,
          nsError.localizedDescription,
          self.remoteNotificationCount
        )
        result([
          "ok": false,
          "code": code,
          "message": nsError.localizedDescription,
          "remoteNotificationsReceived": self.remoteNotificationCount,
          "native": self.debugApnsStatus(),
        ])
        return
      }
      guard let verificationId else {
        result(FlutterError(code: "no-id", message: "No verificationId", details: nil))
        return
      }
      NSLog("[OTP_DEBUG] native verify codeSent id=%@…", String(verificationId.prefix(8)))
      result([
        "ok": true,
        "verificationId": verificationId,
        "remoteNotificationsReceived": self.remoteNotificationCount,
      ])
    }
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
      ?? scenes.flatMap(\.windows).first
    guard var top = window?.rootViewController else { return nil }
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }

  func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
    NSLog("[OTP_DEBUG] AuthUIDelegate present reCAPTCHA / SFSafariViewController")
    DispatchQueue.main.async {
      guard let top = self.topViewController() else {
        NSLog("[OTP_DEBUG] AuthUIDelegate present failed: no root VC")
        completion?()
        return
      }
      top.present(viewControllerToPresent, animated: flag, completion: completion)
    }
  }

  func dismiss(animated flag: Bool, completion: (() -> Void)?) {
    NSLog("[OTP_DEBUG] AuthUIDelegate dismiss")
    DispatchQueue.main.async {
      self.topViewController()?.dismiss(animated: flag, completion: completion)
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
    status["apsEnvironment"] = embeddedApsEnvironment() ?? apsEnvironmentLabel()
    status["bundleId"] = Bundle.main.bundleIdentifier ?? "unknown"
    status["apnsTokenType"] = apnsTypeLabel(tokenType)
    status["authHasApnsToken"] = authToken != nil
    status["authTokenBytes"] = authToken?.count ?? 0
    status["messagingHasApnsToken"] = msgToken != nil
    status["messagingTokenBytes"] = msgToken?.count ?? 0
    status["remoteNotificationsReceived"] = remoteNotificationCount
    status["isRegisteredForRemoteNotifications"] = UIApplication.shared.isRegisteredForRemoteNotifications
    status["firebaseProxyEnabled"] = isFirebaseAppDelegateProxyEnabled()
    #if DEBUG
    status["appVerificationDisabledForTesting"] = Auth.auth().settings?.isAppVerificationDisabledForTesting ?? false
    #endif
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

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Auth before and after super so Firebase Phone Auth keeps the APNs token.
    applyApnsToken(deviceToken)
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
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) {
    // When proxy is on, Firebase swizzler must own the prober notification loop — don't intercept.
    if isFirebaseAppDelegateProxyEnabled() {
      super.application(application, didReceiveRemoteNotification: userInfo)
      return
    }
    if Auth.auth().canHandleNotification(userInfo) {
      logRemoteNotification(userInfo, source: "didReceiveRemoteNotification-auth")
      NSLog("[OTP_DEBUG] canHandleNotification didReceiveRemoteNotification handled=YES")
      return
    }
    logRemoteNotification(userInfo, source: "didReceiveRemoteNotification")
    if userInfo["gcm.message_id"] != nil {
      Messaging.messaging().appDidReceiveMessage(userInfo)
    }
    super.application(application, didReceiveRemoteNotification: userInfo)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if isFirebaseAppDelegateProxyEnabled() {
      super.application(
        application,
        didReceiveRemoteNotification: userInfo,
        fetchCompletionHandler: completionHandler
      )
      return
    }
    if Auth.auth().canHandleNotification(userInfo) {
      logRemoteNotification(userInfo, source: "fetchCompletionHandler-auth")
      NSLog("[OTP_DEBUG] canHandleNotification fetchCompletionHandler handled=YES")
      completionHandler(.noData)
      return
    }
    logRemoteNotification(userInfo, source: "fetchCompletionHandler")
    if userInfo["gcm.message_id"] != nil {
      Messaging.messaging().appDidReceiveMessage(userInfo)
    }
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    if Auth.auth().canHandleNotification(userInfo) {
      logRemoteNotification(userInfo, source: "willPresent-auth")
      NSLog("[OTP_DEBUG] canHandleNotification willPresent handled=YES")
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
    if Auth.auth().canHandleNotification(userInfo) {
      logRemoteNotification(userInfo, source: "didReceiveResponse-auth")
      NSLog("[OTP_DEBUG] canHandleNotification didReceiveResponse handled=YES")
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
