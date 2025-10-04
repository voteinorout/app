import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }

    let window = UIWindow(windowScene: windowScene)
    if let flutterDelegate = UIApplication.shared.delegate as? FlutterAppDelegate {
      window.rootViewController = flutterDelegate.window?.rootViewController ?? FlutterViewController()
      flutterDelegate.window = window
    }
    self.window = window
    window.makeKeyAndVisible()
  }
}
