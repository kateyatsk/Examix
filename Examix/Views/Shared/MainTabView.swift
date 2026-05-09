//
//  TabView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @State private var selectedTab = 0
    @State private var showFeatureOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Главная")
                }
                .tag(0)

            ResultsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "star.fill" : "star")
                    Text("Результаты")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                    Text("Профиль")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                    Text("Настройки")
                }
                .tag(3)
        }
        .accentColor(.stock) // активный цвет вкладки
        .onAppear {
            if !userSettings.hasCompletedFeatureOnboarding {
                showFeatureOnboarding = true
            }
        }
        .onChange(of: userSettings.featureOnboardingReplaySignal) { _, _ in
            showFeatureOnboarding = true
        }
        .fullScreenCover(isPresented: $showFeatureOnboarding) {
            AppFeatureOnboardingView {
                userSettings.markFeatureOnboardingCompleted()
                showFeatureOnboarding = false
            }
        }
    }
}


#Preview {
    MainTabView()
        .environmentObject(UserSettings())
}
