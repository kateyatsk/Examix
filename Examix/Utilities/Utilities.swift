//
//  Utilities.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.04.25.
//

import SwiftUI
import UIKit

extension View {
    /// Отключает автокоррекцию и автокапитализацию для полей ввода (меньше подсказок над клавиатурой).
    /// `spellCheckingDisabled` не используем — на целевой версии SDK у `View` его может не быть.
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
