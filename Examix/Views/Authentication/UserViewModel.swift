//
//  UserViewModel.swift
//  Examix
//
//  Created by Kate Yatskevich on 11.04.25.
//

import Combine
import Foundation

@MainActor
final class UserViewModel: ObservableObject {
    @Published private(set) var userName: String = "Гость"
    @Published private(set) var userEmail: String?
    @Published private(set) var isLoading = false
    
    private let authManager = AuthenticationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        authManager.$user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.userName = user?.displayName ?? "Гость"
                self?.userEmail = user?.email
            }
            .store(in: &cancellables)
    }
    
    func handleGoogleSignIn(tokens: GoogleSignInResultModel) async {
        isLoading = true
        do {
            _ = try await authManager.signInWithGoogle(tokens: tokens)
        } catch {
        }
        isLoading = false
    }
}
