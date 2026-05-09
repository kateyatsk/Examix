//
//  SignInGoogleHelper.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.04.25.
//

import GoogleSignIn
import GoogleSignInSwift

enum GoogleSignInCancellationError: Error {
    case cancelled
}

struct GoogleSignInResultModel {
    let idToken: String
    let accessToken: String
    let name: String?
    let email: String?
}

final class SignInGoogleHelper {
    
    @MainActor
    func signIn() async throws -> GoogleSignInResultModel {
        guard let topVC = Utilities.shared.topViewController() else {
            throw URLError(.cannotFindHost)
        }
        
        let gidSignInResult: GIDSignInResult

        do {
            gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain && error.code == GIDSignInError.canceled.rawValue {
            throw GoogleSignInCancellationError.cancelled
        }
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accessToken = gidSignInResult.user.accessToken.tokenString
        let name = gidSignInResult.user.profile?.name ?? "Пользователь"
        let email = gidSignInResult.user.profile?.email

        let tokens = GoogleSignInResultModel(idToken: idToken, accessToken: accessToken, name: name, email: email)
        return tokens
    }
    
}
