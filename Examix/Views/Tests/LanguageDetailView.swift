//
//  LanguageDetailView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 20.02.25.
//

import SwiftUI

struct LanguageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var path: NavigationPath
    @EnvironmentObject var userSettings: UserSettings

    var language: String

    var body: some View {
        ZStack {
            ExamixStyle.practiceScreenWash
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 20) {
                        Image("boy")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .shadow(color: ExamixStyle.accentCool.opacity(0.25), radius: 20, x: 0, y: 10)

                        VStack(spacing: 8) {
                            Text("Режим теста")
                                .font(.custom("MontserratAlternates-Bold", size: 14))
                                .foregroundStyle(ExamixStyle.accentCool)
                                .textCase(.uppercase)
                                .tracking(1.2)

                            Text("Выберите, как запустить вариант")
                                .font(.custom("MontserratAlternates-Bold", size: 24))
                                .foregroundStyle(Color(.darkAccent))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(language)
                                .font(.custom("MontserratAlternates-Medium", size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 28)

                    VStack(spacing: 14) {
                        modeCard(
                            title: "Случайный вариант",
                            subtitle: "Система подберёт вариант из базы",
                            icon: "shuffle.circle.fill",
                            iconGradient: ExamixStyle.practiceTypesGradient,
                            iconTint: ExamixStyle.practiceTypesGradientColors[1]
                        ) {
                            userSettings.selectedVariant = nil
                            path.append(HomeView.Path.testView)
                        }

                        modeCard(
                            title: "На выбор",
                            subtitle: "Сами укажете номер варианта",
                            icon: "list.bullet.rectangle.portrait.fill",
                            iconGradient: ExamixStyle.practiceThemesGradient,
                            iconTint: ExamixStyle.practiceThemesGradientColors[1]
                        ) {
                            path.append(HomeView.Path.chooseVariant)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Text("‹")
                            .font(.custom("MontserratAlternates-Bold", size: 20))
                        Text("Назад")
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                    }
                    .foregroundStyle(ExamixStyle.accentCool)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func modeCard(
        title: String,
        subtitle: String,
        icon: String,
        iconGradient: LinearGradient,
        iconTint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(iconTint.opacity(0.16))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(iconGradient)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("MontserratAlternates-Bold", size: 18))
                        .foregroundStyle(Color(.darkAccent))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.custom("MontserratAlternates-Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Text("›")
                    .font(.custom("MontserratAlternates-Bold", size: 26))
                    .foregroundStyle(ExamixStyle.accentCool.opacity(0.55))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                ExamixStyle.accentCool.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
