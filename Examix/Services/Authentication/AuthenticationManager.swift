//
//  AuthenticationManager.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.04.25.
//

import Foundation
import FirebaseAuth
import Combine

struct AuthDataResultModel {
    let uid: String
    let email: String?
    let photoUrl: String?
    let name: String?
    
    init(user: User) {
        self.uid = user.uid
        self.email = user.email
        self.photoUrl = user.photoURL?.absoluteString
        self.name = user.displayName
    }
}

enum AuthProviderOption: String {
    case google = "google.com"
    case email = "password"
}

final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var user: User? = nil
    @Published var isAuthenticated = false
    @Published var isSplashScreenShown = true
    
    private init() {
        let current = Auth.auth().currentUser
        user = current
        isAuthenticated = current != nil
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    func getAuthenticatedUser() throws -> AuthDataResultModel {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.badServerResponse)
        }
        return AuthDataResultModel(user: user)
    }
    
    func getProviders() throws -> [AuthProviderOption] {
        guard let providerData = Auth.auth().currentUser?.providerData else {
            throw URLError(.badServerResponse)
        }
        
        var providers: [AuthProviderOption] = []
        for provider in providerData {
            if let option = AuthProviderOption(rawValue: provider.providerID) {
                providers.append(option)
            } else {
                assertionFailure("Provider option not found: \(provider.providerID)")
            }
        }
        return providers
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
    
    func delete() async throws {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.badURL)
        }
        try await user.delete()
        DispatchQueue.main.async {
            self.user = nil
            self.isAuthenticated = false
        }
    }
    
    func hideSplashScreen() {
        DispatchQueue.main.async {
            self.isSplashScreenShown = false
        }
    }
}

extension AuthenticationManager {
    @discardableResult
    func signInWithGoogle(tokens: GoogleSignInResultModel) async throws -> AuthDataResultModel {
        let credential = GoogleAuthProvider.credential(
            withIDToken: tokens.idToken,
            accessToken: tokens.accessToken
        )
        _ = try await signIn(credential: credential)
        
        if let name = tokens.name {
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = name
            try await changeRequest?.commitChanges()
        }
        
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        return try getAuthenticatedUser()
    }

    @discardableResult
    func createUser(email: String, password: String, name: String?) async throws -> AuthDataResultModel {
        let authDataResult = try await Auth.auth().createUser(withEmail: email, password: password)

        if let name, !name.isEmpty {
            let changeRequest = authDataResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }

        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        return AuthDataResultModel(user: authDataResult.user)
    }

    @discardableResult
    func signInWithEmail(email: String, password: String) async throws -> AuthDataResultModel {
        let authDataResult = try await Auth.auth().signIn(withEmail: email, password: password)
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        return AuthDataResultModel(user: authDataResult.user)
    }
    
    private func signIn(credential: AuthCredential) async throws -> AuthDataResultModel {
        let authDataResult = try await Auth.auth().signIn(with: credential)
        return AuthDataResultModel(user: authDataResult.user)
    }
}
