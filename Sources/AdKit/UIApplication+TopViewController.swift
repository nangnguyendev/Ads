#if canImport(UIKit)
import UIKit

extension UIApplication {
    @MainActor
    var adKitTopViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        return window?.rootViewController.map(Self.topMost)
    }

    @MainActor
    private static func topMost(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed {
            return topMost(from: presented)
        }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
            return topMost(from: visible)
        }
        if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController {
            return topMost(from: selected)
        }
        return controller
    }
}
#endif
