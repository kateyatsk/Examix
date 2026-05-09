//
//  UserSettings.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.04.25.
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

    /// Лимит открытий подсказки за один проход теста: **-1** — без ограничения, **0** — подсказки отключены, **1…20** — не больше N раз за сессию.
    @Published var maxHintsPerTest: Int = -1 {
        didSet {
            UserDefaults.standard.set(maxHintsPerTest, forKey: Self.maxHintsPerTestKey)
        }
    }

    /// Показ экскурсии по разделам приложения (первый запуск или из настроек).
    @Published var hasCompletedFeatureOnboarding: Bool = false {
        didSet {
            UserDefaults.standard.set(hasCompletedFeatureOnboarding, forKey: Self.featureOnboardingCompletedKey)
        }
    }

    /// Увеличивается при запросе повторной экскурсии — `MainTabView` подписывается через `onChange`.
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
