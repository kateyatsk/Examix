//
//  AuthenticationViewModel.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.04.25.
//

import Foundation

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func signInGoogle() async throws{
        let helper = SignInGoogleHelper()
        let tokens = try await helper.signIn()
        try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
    }

    func createEmailAccount(email: String, password: String, name: String?) async throws {
        try await AuthenticationManager.shared.createUser(email: email, password: password, name: name)
    }

    func signInEmail(email: String, password: String) async throws {
        try await AuthenticationManager.shared.signInWithEmail(email: email, password: password)
    }
      
}
