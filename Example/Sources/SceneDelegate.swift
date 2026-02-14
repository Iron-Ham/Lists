import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
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
        ]

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
    }

    private func makeTab(_ viewController: UIViewController, title: String, icon: String) -> UINavigationController {
        let nav = UINavigationController(rootViewController: viewController)
        nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), selectedImage: nil)
        return nav
    }
}
