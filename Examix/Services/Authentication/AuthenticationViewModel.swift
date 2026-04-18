//
//  AuthenticationViewModel.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.04.25.
//

import Foundation

@MainActor
final class AuthenticationViewModel: ObservableObject {
    func signInGoogle() async throws{
        let helper = SignInGoogleHelper()
        let tokens = try await helper.signIn()
        try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
    }
      
}
