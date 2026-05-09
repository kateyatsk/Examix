//
//  Utilities.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.04.25.
//

import SwiftUI
import UIKit

extension View {
    func examixPlainTextFieldInput() -> some View {
        autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
    }
}

final class Utilities {
    static let shared = Utilities()
    private init() {}
    
    @MainActor
        func topViewController(controller: UIViewController? = nil) -> UIViewController? {
            let controller = controller ?? UIApplication.shared.keyWindow?.rootViewController
            
            if let navigationController = controller as? UINavigationController {
                return topViewController(controller: navigationController.visibleViewController)
            }
            if let tabController = controller as? UITabBarController {
                if let selected = tabController.selectedViewController {
                    return topViewController(controller: selected)
                }
            }
            if let presented = controller?.presentedViewController {
                return topViewController(controller: presented)
            }
            return controller
        }
    
}
