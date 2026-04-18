//
//  AuthenticationView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.04.25.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    var onSignInSuccess: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.mainBack))
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 17) {
                VStack {
                    Text("Добро пожаловать в")
                        .font(.custom("MontserratAlternates-Medium", size: 24))
                        .foregroundColor(.darkAccent)
                    Text("Lingvistik.")
                        .font(.custom("KottaOne-Regular", size: 32))
                        .foregroundColor(.darkAccent)
                }

                Text("Приложение, которое поможет сдать все экзамены на 100 баллов!")
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                    .foregroundColor(.darkAccent)
                    .multilineTextAlignment(.center)

                GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(
                    scheme: .light,
                    style: .wide,
                    state: .normal
                )) {
                    Task {
                        do {
                            try await viewModel.signInGoogle()
                            onSignInSuccess()
                        } catch {
                            print("Ошибка входа: \(error.localizedDescription)")
                        }
                    }
                }
                .cornerRadius(12)
                .frame(maxWidth: 327, minHeight: 64)
                .padding(20)
            }
            .padding()
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView(onSignInSuccess: {})
    }
}
