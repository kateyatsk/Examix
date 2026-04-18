//
//  SplashScreenViewModel.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 19.02.25.
//

import SwiftUI
import Foundation

class SplashViewModel: ObservableObject {
    @Published var isActive = true
    @Published var isTextVisible = false
    
    private var animationDuration: Double = 3.0
    private var textDelay: Double = 1.2
    
    func startAnimation(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + textDelay) {
            withAnimation(.easeIn(duration: 0.5)) {
                self.isTextVisible = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            withAnimation(.easeOut(duration: 0.5)) {
                self.isActive = false
                completion()
            }
        }
    }
}
