// ABOUTME: Scene delegate that sets up the main window with a tab bar controller.
// ABOUTME: Each tab hosts one example (ListKit, Manual, DSL, Mixed, Outline, SwiftUI, etc.).
import SwiftUI
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  // MARK: Internal

  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo _: UISceneSession,
    options _: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [
      makeTab(ListKitExampleViewController(), title: "ListKit", icon: "list.bullet"),
      makeTab(GroupedListExampleViewController(), title: "Manual", icon: "rectangle.3.group"),
      makeTab(DSLExampleViewController(), title: "DSL", icon: "chevron.left.forwardslash.chevron.right"),
      makeTab(MixedExampleViewController(), title: "Mixed", icon: "square.stack.3d.up"),
      makeTab(OutlineExampleViewController(), title: "Outline", icon: "list.triangle"),
      makeTab(SwiftUIExampleViewController(), title: "SwiftUI", icon: "swift"),
      makeTab(
        UIHostingController(rootView: SwiftUIWrappersExampleView()),
        title: "Wrappers",
        icon: "rectangle.on.rectangle"
      ),
      makeTab(LiveExampleViewController(), title: "Live", icon: "chart.line.uptrend.xyaxis"),
      makeTab(
        UIHostingController(rootView: ChatExampleView()),
        title: "Chat",
        icon: "bubble.left.and.bubble.right"
      ),
      makeTab(
        ListsChatExampleViewController(),
        title: "Chat Lists",
        icon: "bubble.left.and.text.bubble.right"
      ),
      makeTab(
        ListKitChatExampleViewController(),
        title: "Chat ListKit",
        icon: "ellipsis.message"
      ),
    ]

    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = tabBarController
    window?.makeKeyAndVisible()
  }

  // MARK: Private

  private func makeTab(_ viewController: UIViewController, title: String, icon: String) -> UINavigationController {
    let nav = UINavigationController(rootViewController: viewController)
    nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), selectedImage: nil)
    return nav
  }
}
