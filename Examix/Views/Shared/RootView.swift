//
//  RootView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.04.25.
//

import SwiftUI

struct RootView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var userSettings = UserSettings()
    @StateObject private var coordinator: AppCoordinator

    init() {
        let authManager = AuthenticationManager.shared
        let userSettings = UserSettings()
        _authManager = StateObject(wrappedValue: authManager)
        _userSettings = StateObject(wrappedValue: userSettings)
        _coordinator = StateObject(wrappedValue: AppCoordinator(authManager: authManager, userSettings: userSettings))
    }

    var body: some View {
        switch coordinator.currentRoute {
        case .splash:
            SplashView {
                coordinator.determineRouteAfterSplash()
            }
            .environmentObject(authManager)
            .environmentObject(userSettings)

        case .auth:
            AuthenticationView {
                coordinator.determineRouteAfterSplash()
            }
            .environmentObject(authManager)
            .environmentObject(userSettings)

        case .languageSelection:
            LanguageSelectionView {
                coordinator.currentRoute = .mainTab
            }
            .environmentObject(userSettings)

        case .mainTab:
            MainTabView()
                .environmentObject(authManager)
                .environmentObject(userSettings)
        }
    }
}



struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
                   .environmentObject(AuthenticationManager.shared)
                   .environmentObject(UserSettings())
    }
}
