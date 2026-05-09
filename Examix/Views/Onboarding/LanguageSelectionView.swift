//
//  LanguageSelectionView.swift
//  Examix
//
//  Created by Kate Yatskevich on 19.02.25.
//

import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var viewModel = LanguageSelectionViewModel()
    @EnvironmentObject var userSettings: UserSettings
    var onLanguageSelected: () -> Void

    private let contentWidth: CGFloat = 320
    
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 12) {
                (
                Text(viewModel.titleText)
                    .font(.custom("MontserratAlternates-Medium", size: 23))
                    .foregroundColor(.darkAccent) +
                Text(viewModel.boldText)
                    .font(.custom("MontserratAlternates-Bold", size: 23))
                    .foregroundColor(.stock)
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.subtitleText)
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                    .foregroundColor(.darkAccent.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: contentWidth)
            Spacer()
            ForEach(viewModel.languages, id: \.self) { language in
                LanguageButton(language: language, isSelected: viewModel.selectedLanguage == language)
                    .frame(maxWidth: contentWidth)
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        viewModel.selectedLanguage = language
                    }
            }
            .frame(maxWidth: .infinity)
            Spacer()
            Button(action: {
                if let selected = viewModel.selectedLanguage {
                    userSettings.selectedLanguage = selected
                    onLanguageSelected()
                }
            }) {
                Text("Продолжить")
                    .font(.custom("MontserratAlternates-Medium", size: 16))
                    .padding()
                    .frame(width: 200)
                    .background(Color(.stock))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.selectedLanguage == nil)
            Spacer()
        }
        .padding()
    }
}

struct LanguageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSelectionView(onLanguageSelected: {})
            .environmentObject(UserSettings())
    }
}
