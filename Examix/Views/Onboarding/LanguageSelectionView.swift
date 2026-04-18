//
//  LanguageSelectionView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 19.02.25.
//

import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var viewModel = LanguageSelectionViewModel()
    @EnvironmentObject var userSettings: UserSettings
    var onLanguageSelected: () -> Void
    
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            HStack {
                Text(viewModel.titleText)
                    .font(.custom("MontserratAlternates-Medium", size: 24))
                    .foregroundColor(.darkAccent) +
                Text(viewModel.boldText)
                    .font(.custom("MontserratAlternates-Bold", size: 24))
                    .foregroundColor(.stock)
            }
            .multilineTextAlignment(.center)
         Spacer()
            ForEach(viewModel.languages, id: \.self) { language in
                LanguageButton(language: language, isSelected: viewModel.selectedLanguage == language)
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        viewModel.selectedLanguage = language
                    }
            }
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

