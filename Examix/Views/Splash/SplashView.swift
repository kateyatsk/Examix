//
//  SplashView.swift
//  Examix
//
//  Created by Kate Yatskevich on 19.02.25.
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showLogoAnimation = false
    @State private var showContent = false
    let completion: () -> Void

    private let splashDuration: TimeInterval = 2.6
    private let logoDelay: TimeInterval = 0.45
    private let fadeDuration: TimeInterval = 0.55
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.32, blue: 0.48),
                    Color(red: 0.35, green: 0.58, blue: 0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()
            
            if showLogoAnimation {
                LottieView(filename: "LogoAnimation", loopMode: .playOnce)
                    .frame(
                        width: min(UIScreen.main.bounds.width * 0.48, 220),
                        height: min(UIScreen.main.bounds.width * 0.48, 220)
                    )
                    .scaleEffect(isAnimating ? 1.04 : 0.94)
                    .opacity(isAnimating ? 1 : 0.72)
                    .transition(.opacity)
            }
        }
        .opacity(showContent ? 0 : 1)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + logoDelay) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    showLogoAnimation = true
                }
                withAnimation(.easeInOut(duration: 0.7)) {
                    isAnimating = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                withAnimation(.easeInOut(duration: fadeDuration)) {
                    showContent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) {
                        completion()
                    }
                }
            }
        }
    }
}
