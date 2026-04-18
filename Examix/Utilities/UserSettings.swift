//
//  UserSettings.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.04.25.
//

import Foundation

class UserSettings: ObservableObject {
    @Published var selectedLanguage: Language? {
        didSet {
            UserDefaults.standard.set(selectedLanguage?.rawValue, forKey: "selectedLanguage")
        }
    }
    
    @Published var selectedVariant: Int? 

    init() {

        if let rawValue = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: rawValue) {
            selectedLanguage = language
        }

        selectedVariant = UserDefaults.standard.integer(forKey: "selectedVariant")
        if UserDefaults.standard.object(forKey: "selectedVariant") == nil {
            selectedVariant = nil
        }
    }
}
