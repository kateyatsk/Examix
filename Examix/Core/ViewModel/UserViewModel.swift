//
//  UserViewModel.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 11.04.25.
//

import Combine

final class UserViewModel: ObservableObject {
    @Published private(set) var userName: String = "Гость"
    @Published private(set) var userEmail: String?
    @Published private(set) var isLoading = false
    
    private let authManager = AuthenticationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        authManager.$userName
            .assign(to: \.userName, on: self)
            .store(in: &cancellables)
        
        authManager.$userEmail
            .assign(to: \.userEmail, on: self)
            .store(in: &cancellables)
    }
    
    func handleGoogleSignIn(tokens: GoogleSignInResultModel) async {
        isLoading = true
        do {
            _ = try await authManager.signInWithGoogle(
                idToken: tokens.idToken,
                accessToken: tokens.accessToken,
                displayName: tokens.name
            )
        } catch {
            print("Ошибка входа: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
