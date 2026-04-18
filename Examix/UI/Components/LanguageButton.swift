//
//  CustomLanguageView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 20.02.25.
//

import SwiftUI

struct LanguageButton: View {
    let language: Language
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color(.stock) : Color(.secondaryBlue), lineWidth: 2)
            .frame(width: 320, height: 72)
            .background(isSelected ? Color(.stock).opacity(0.1) : Color.clear)
            .overlay(
                HStack {
                    Image(language.flagName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 24)
                    
                    Text(language.rawValue)
                        .font(.custom("MontserratAlternates-Medium", size: 18))
                        .foregroundColor(isSelected ? Color(.stock) : Color(.darkAccent))
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.stock)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.right")
                            .fontWeight(.bold)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.darkAccent)
                    }
                }
                .padding()
            )
            .animation(.easeInOut, value: isSelected)
    }
}

struct LanguageButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            LanguageButton(language: .russian, isSelected: true)
            LanguageButton(language: .english, isSelected: false)
        }
    }
}
