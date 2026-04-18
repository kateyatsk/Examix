//
//  LanguageSelectionViewModel.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 9.04.25.
//

import Foundation

class LanguageSelectionViewModel: ObservableObject {
    @Published var selectedLanguage: Language? = nil
    
    let languages = Language.allCases
    let titleText = "Какой язык вы планируете сдавать на "
    let boldText = "ЦТ/ЦЭ?"
}
