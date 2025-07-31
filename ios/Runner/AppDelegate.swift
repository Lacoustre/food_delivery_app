import UIKit
import Flutter
import Firebase         // ✅ Add this if using Firebase
import GoogleMaps       // ✅ Add this if using Google Maps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    
    // ✅ Google Maps API Key (replace with your real key)
    GMSServices.provideAPIKey("AIzaSyCcv1PK7WonTsFHcaGw8T2Jw3J2Ob8DKFQ")
    
    // ✅ Register Plugins
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
