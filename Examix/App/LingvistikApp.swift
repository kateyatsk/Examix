//
//  LingvistikApp.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 19.02.25.
//

import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}


@main
struct LingvistikApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var userSettings = UserSettings()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(userSettings)
        }
    }
}
