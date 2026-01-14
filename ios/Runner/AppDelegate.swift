import UIKit
import Flutter
import Firebase
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Configure Firebase (required for Auth)
    FirebaseApp.configure()

    // Google Maps
    GMSServices.provideAPIKey("AIzaSyCcv1PK7WonTsFHcaGw8T2Jw3J2Ob8DKFQ")

    // Register plugins
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // If you ever set FirebaseAppDelegateProxyEnabled = NO, handle the URL here:
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Let Firebase Auth process reCAPTCHA / phone auth callbacks
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
