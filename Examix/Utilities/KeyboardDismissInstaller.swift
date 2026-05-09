//
//  KeyboardDismissInstaller.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import UIKit

enum ExamixAppKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

final class KeyboardDismissInstaller: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissInstaller()

    private var tap: UITapGestureRecognizer?

    private override init() {
        super.init()
    }

    func installIfNeeded() {
        guard tap == nil else { return }

        DispatchQueue.main.async { [weak self] in
            self?.attachToKeyWindow()
        }
    }

    private func attachToKeyWindow() {
        guard tap == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let win = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        guard let window = win else { return }

        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        window.addGestureRecognizer(gesture)

        tap = gesture
    }

    @objc private func handleTap() {
        ExamixAppKeyboard.dismiss()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view
        while let v = view {
            if v is UITextField || v is UITextView || v is UISearchBar { return false }
            if NSStringFromClass(type(of: v)).contains("UISearch") { return false }
            if NSStringFromClass(type(of: v)).contains("TextEditor") { return false }
            if NSStringFromClass(type(of: v)).contains("_UIText") { return false }
            view = v.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
