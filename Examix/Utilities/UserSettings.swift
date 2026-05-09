//
//  UserSettings.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.04.25.
//

import Foundation

class UserSettings: ObservableObject {
    private static let maxHintsPerTestKey = "maxHintsPerTest"
    private static let featureOnboardingCompletedKey = "featureOnboardingCompletedV1"

    @Published var selectedLanguage: Language? {
        didSet {
            UserDefaults.standard.set(selectedLanguage?.rawValue, forKey: "selectedLanguage")
        }
    }
    
    @Published var selectedVariant: Int?

    @Published var maxHintsPerTest: Int = -1 {
        didSet {
            UserDefaults.standard.set(maxHintsPerTest, forKey: Self.maxHintsPerTestKey)
        }
    }

    @Published var hasCompletedFeatureOnboarding: Bool = false {
        didSet {
            UserDefaults.standard.set(hasCompletedFeatureOnboarding, forKey: Self.featureOnboardingCompletedKey)
        }
    }

    @Published private(set) var featureOnboardingReplaySignal: Int = 0

    init() {

        if let rawValue = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: rawValue) {
            selectedLanguage = language
        }

        selectedVariant = UserDefaults.standard.integer(forKey: "selectedVariant")
        if UserDefaults.standard.object(forKey: "selectedVariant") == nil {
            selectedVariant = nil
        }

        if UserDefaults.standard.object(forKey: Self.maxHintsPerTestKey) != nil {
            maxHintsPerTest = UserDefaults.standard.integer(forKey: Self.maxHintsPerTestKey)
        } else {
            maxHintsPerTest = -1
        }

        hasCompletedFeatureOnboarding = UserDefaults.standard.bool(forKey: Self.featureOnboardingCompletedKey)
    }

    func markFeatureOnboardingCompleted() {
        hasCompletedFeatureOnboarding = true
    }

    func requestFeatureOnboardingReplay() {
        hasCompletedFeatureOnboarding = false
        featureOnboardingReplaySignal &+= 1
    }
}
