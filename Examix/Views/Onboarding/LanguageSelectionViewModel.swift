//
//  LanguageSelectionViewModel.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.04.25.
//

import Foundation

class LanguageSelectionViewModel: ObservableObject {
    @Published var selectedLanguage: Language? = nil
    
    let languages = Language.allCases
    let titleText = "Выберите предмет "
    let boldText = "для старта"
    let subtitleText = "Сейчас можно выбрать один предмет. Позже в приложении легко переключиться на другой."
}
