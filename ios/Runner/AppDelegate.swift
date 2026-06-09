import FirebaseAuth

import FirebaseCore

import FirebaseMessaging

import Flutter

import UIKit



@main

@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(

    _ application: UIApplication,

    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?

  ) -> Bool {

    if FirebaseApp.app() == nil {

      FirebaseApp.configure()

    }

    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)

  }



  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {

    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

  }



  // https://firebase.google.com/docs/auth/ios/phone-auth#appendix:-using-phone-sign-in-without-swizzling

  override func application(

    _ application: UIApplication,

    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data

  ) {

    Auth.auth().setAPNSToken(deviceToken, type: .unknown)

    Messaging.messaging().apnsToken = deviceToken

    NSLog("[Firebase] APNs device token registered for Auth + Messaging")

    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)

  }



  override func application(

    _ application: UIApplication,

    didFailToRegisterForRemoteNotificationsWithError error: Error

  ) {

    NSLog("[Firebase] APNs registration failed: \(error.localizedDescription)")

    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)

  }



  override func application(

    _ application: UIApplication,

    didReceiveRemoteNotification userInfo: [AnyHashable: Any],

    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void

  ) {

    if Auth.auth().canHandleNotification(userInfo) {

      NSLog("[Firebase] Auth handled silent phone-verification push")

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

    _ app: UIApplication,

    open url: URL,

    options: [UIApplication.OpenURLOptionsKey: Any] = [:]

  ) -> Bool {

    if Auth.auth().canHandle(url) {

      return true

    }

    return super.application(app, open: url, options: options)

  }

}


