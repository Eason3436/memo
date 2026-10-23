import UIKit

/// 純程式碼建立畫面，不使用 Storyboard
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let listVC = NotesListViewController()
        let nav = UINavigationController(rootViewController: listVC)
        nav.navigationBar.prefersLargeTitles = true
        nav.isToolbarHidden = false

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = nav
        window.tintColor = .systemOrange
        window.makeKeyAndVisible()
        self.window = window
    }
}
