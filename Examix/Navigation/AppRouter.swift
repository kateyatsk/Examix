//
//  AppRouter.swift
//  Examix
//
//  Created by Kate Yatskevich on 17.04.25.
//

import Foundation
import SwiftUI
import Combine

enum AppRoute {
    case splash
    case auth
    case languageSelection
    case mainTab
}

final class AppCoordinator: ObservableObject {
    @Published var currentRoute: AppRoute = .splash
    
    private var authManager: AuthenticationManager
    private var userSettings: UserSettings
    private var cancellables = Set<AnyCancellable>()
    
    private var hasShownSplash = false
    
    init(authManager: AuthenticationManager, userSettings: UserSettings) {
        self.authManager = authManager
        self.userSettings = userSettings
        observeAuthState()
    }

    private func routeToMainFlow() {
        guard hasShownSplash else { return }
        if !authManager.isAuthenticated {
            currentRoute = .auth
            return
        }
        if userSettings.selectedLanguage == nil {
            currentRoute = .languageSelection
        } else {
            currentRoute = .mainTab
        }
    }
    
    private func observeAuthState() {
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.routeToMainFlow()
            }
            .store(in: &cancellables)
    }

    func determineRouteAfterSplash() {
        hasShownSplash = true
        routeToMainFlow()
    }

    func logout() {
        do {
            try authManager.signOut()
            userSettings.selectedLanguage = nil
            routeToMainFlow()
        } catch {
        }
    }
}
