//
//  LanguageModel.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 8.04.25.
//

import Foundation

enum Language: String, CaseIterable {
    case russian = "Русский"
    case belarusian = "Белорусский"
    case english = "Английский"
    case french = "Французский"
    case german = "Немецкий"
    
    var flagName: String {
        switch self {
        case .russian: return "russianFlag"
        case .belarusian: return "belarusianFlag"
        case .english: return "englishFlag"
        case .french: return "frenchFlag"
        case .german: return "germanFlag"
        }
    }
}

struct LanguageModel {
    let language: Language
    
    var name: String { language.rawValue }
    var flag: String { language.flagName }
}

