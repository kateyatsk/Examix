//
//  AuthenticationView.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.04.25.
//

import SwiftUI

private enum AuthSurface {
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.95, blue: 0.99),
                Color(red: 0.77, green: 0.88, blue: 0.96),
                Color(red: 0.47, green: 0.66, blue: 0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var isEmailSheetPresented = false
    var onSignInSuccess: () -> Void

    var body: some View {
        ZStack {
            AuthSurface.background
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 17) {
                VStack {
                    Text("Добро пожаловать в")
                        .font(.custom("MontserratAlternates-Medium", size: 24))
                        .foregroundColor(.darkAccent)
                    Text("Examix.")
                        .font(.custom("KottaOne-Regular", size: 32))
                        .foregroundColor(.darkAccent)
                }

                Text("Приложение, которое поможет сдать все экзамены на 100 баллов!")
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                    .foregroundColor(.darkAccent)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    AuthProviderButton(title: "Продолжить с почтой", icon: .system("envelope.fill")) {
                        isEmailSheetPresented = true
                    }

                    AuthProviderButton(title: "Продолжить с Google", icon: .google) {
                        Task {
                            await authenticate {
                                try await viewModel.signInGoogle()
                            }
                        }
                    }
                }
                .padding(.top, 12)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.custom("MontserratAlternates-Medium", size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 327)
                }
            }
            .padding()
        }
        .sheet(isPresented: $isEmailSheetPresented) {
            EmailRegistrationView(viewModel: viewModel) {
                isEmailSheetPresented = false
                onSignInSuccess()
            }
            .presentationDetents([.medium])
        }
    }

    @MainActor
    private func authenticate(_ action: @escaping () async throws -> Void) async {
        viewModel.isLoading = true
        viewModel.errorMessage = nil

        do {
            try await action()
            onSignInSuccess()
        } catch GoogleSignInCancellationError.cancelled {
            viewModel.errorMessage = nil
        } catch {
            viewModel.errorMessage = "Не удалось выполнить вход. Проверьте настройки авторизации и попробуйте еще раз."
        }

        viewModel.isLoading = false
    }
}

private enum AuthProviderIcon {
    case google
    case system(String)
}

private struct AuthProviderButton: View {
    let title: String
    let icon: AuthProviderIcon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconView
                    .frame(width: iconSize.width, height: iconSize.height)
                    .offset(x: iconOffsetX)

                Text(title)
                    .font(.custom("MontserratAlternates-Bold", size: 16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(.darkAccent)
            .frame(maxWidth: 327, minHeight: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.darkAccent.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconSize: CGSize {
        switch icon {
        case .google:
            return CGSize(width: 32, height: 32)
        case .system:
            return CGSize(width: 24, height: 24)
        }
    }

    private var iconOffsetX: CGFloat {
        switch icon {
        case .google:
            return -4
        case .system:
            return 0
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .google:
            Image("google")
                .resizable()
                .scaledToFit()
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
        }
    }
}

private struct EmailRegistrationView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSignInMode = false
    let onSuccess: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AuthSurface.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Text("Готово")
                                .font(.custom("MontserratAlternates-Medium", size: 15))
                                .foregroundColor(.darkAccent)
                        }
                    }

                    VStack(spacing: 6) {
                        Text(isSignInMode ? "Вход по почте" : "Регистрация по почте")
                            .font(.custom("MontserratAlternates-Bold", size: 20))
                            .foregroundColor(.darkAccent)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("Можно создать новый аккаунт или войти в уже существующий.")
                            .font(.custom("MontserratAlternates-Medium", size: 13))
                            .foregroundColor(.darkAccent.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 4)

                    AuthModeSwitcher(isSignInMode: $isSignInMode)

                    if !isSignInMode {
                        TextField("Имя", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .authTextFieldStyle()
                    }

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .authTextFieldStyle()

                    SecureField("Пароль", text: $password)
                        .textContentType(isSignInMode ? .password : .newPassword)
                        .authTextFieldStyle()

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.custom("MontserratAlternates-Medium", size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSignInMode ? "Войти" : "Зарегистрироваться")
                            .font(.custom("MontserratAlternates-Bold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.darkAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(viewModel.isLoading || email.isEmpty || password.count < 6)
                    .opacity(viewModel.isLoading || email.isEmpty || password.count < 6 ? 0.55 : 1)

                    Spacer()
                }
                .padding(20)
            }
        }
    }

    @MainActor
    private func submit() async {
        viewModel.isLoading = true
        viewModel.errorMessage = nil

        do {
            if isSignInMode {
                try await viewModel.signInEmail(email: email, password: password)
            } else {
                try await viewModel.createEmailAccount(email: email, password: password, name: name)
            }
            onSuccess()
        } catch {
            viewModel.errorMessage = "Не удалось авторизоваться по почте. Проверьте email, пароль и настройки Firebase."
        }

        viewModel.isLoading = false
    }
}

private struct AuthModeSwitcher: View {
    @Binding var isSignInMode: Bool

    var body: some View {
        HStack(spacing: 4) {
            modeButton(title: "Регистрация", isSelected: !isSignInMode) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSignInMode = false
                }
            }

            modeButton(title: "Вход", isSelected: isSignInMode) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSignInMode = true
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.darkAccent.opacity(0.12), lineWidth: 1)
        }
    }

    private func modeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("MontserratAlternates-Bold", size: 14))
                .foregroundColor(isSelected ? .white : .darkAccent)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(isSelected ? Color.darkAccent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func authTextFieldStyle() -> some View {
        self
            .font(.custom("MontserratAlternates-Medium", size: 15))
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.darkAccent.opacity(0.12), lineWidth: 1)
            }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView(onSignInSuccess: {})
    }
}
