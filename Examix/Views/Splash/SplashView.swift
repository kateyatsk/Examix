//
//  SplashView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 19.02.25.
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    let completion: () -> Void
    
    var body: some View {
        ZStack {
            Color(.mainBack)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                LottieView(filename: "LogoAnimation")
                    .frame(width: UIScreen.main.bounds.width * 0.4,
                           height: UIScreen.main.bounds.width * 0.4)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                
                if isAnimating {
                    Text("Lingvistik.")
                        .font(.custom("KottaOne-Regular", size: 32))
                        .foregroundColor(.darkAccent)
                        .padding(.top, 11)
                        .transition(.opacity)
                }
                
                Spacer()
            }
        }
        .opacity(showContent ? 0 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showContent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        completion()
                    }
                }
            }
        }
    }
}
