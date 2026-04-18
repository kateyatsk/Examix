//
//  MainView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.04.25.
//

import Foundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showingLogoutAlert = false
    @State var path = NavigationPath()
    
    private var userName: String {
        do {
            let authData = try authManager.getAuthenticatedUser()
            return authData.name ?? "Пользователь"
        } catch {
            return "Пользователь"
        }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(.lightBack)
                    .ignoresSafeArea()
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Добро пожаловать!")
                                .font(.custom("MontserratAlternates-Regular", size: 12))
                                .foregroundColor(.darkAccent)
                            
                            Text(userName)
                                .font(.custom("MontserratAlternates-Bold", size: 24))
                                .foregroundColor(.darkAccent)

                        }
                        Spacer()
                        
                        if let languageFlag = userSettings.selectedLanguage?.flagName {
                            Image(languageFlag)
                                .resizable()
                                .frame(width: 34, height: 24)
                        }
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(.people)
                        .resizable()
                        .frame(width: 374, height: 374)
                    
                    VStack(alignment: .center) {
                        Text("Ты еще не занимался?")
                            .font(.custom("MontserratAlternates-Bold", size: 24))
                            .foregroundColor(.stock)
                        
                        Text("Ежедневная практика очень важна на пути к твоей цели!")
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundColor(.darkAccent)
                            .multilineTextAlignment(.center)
                        
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        path.append(Path.languageDetail)
                    }) {
                        HStack {
                            Text("Решить тест")
                                .font(.custom("MontserratAlternates-Medium", size: 16))
                        }
                        .foregroundColor(.darkAccent)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.mainBack)
                        .cornerRadius(12)
                        .padding(.horizontal, 108)
                        .padding(.bottom, 40)
                    }
                    
                    Spacer()
                    
                    
                }
                
            }.onChange(of: userSettings.selectedLanguage) { _ in
                path = NavigationPath() 
            }
            .navigationDestination(for: Path.self) { route in
                switch route {
                case .languageDetail:
                    LanguageDetailView(path: $path, language: userSettings.selectedLanguage?.rawValue ?? "")
                case .testView:
                    if let language = userSettings.selectedLanguage?.rawValue {
                        if let variant = userSettings.selectedVariant {
                            TestViewLoader(language: language, variant: variant)
                        } else {
                            TestViewLoader(language: language)
                        }
                    } else {
                        Text("Язык не выбран")
                    }
                case .chooseVariant: ChooseVariantView(language: userSettings.selectedLanguage?.rawValue ?? "", path: $path)
                default:
                    EmptyView()
                }
            }
        }
    }
}

extension HomeView {
    enum Path: Hashable {
        case modeSelection
        case forChoice
        case test
        case result
        case languageDetail
        case testView
        case chooseVariant
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(UserSettings())
            .environmentObject(AuthenticationManager.shared)
    }
}
