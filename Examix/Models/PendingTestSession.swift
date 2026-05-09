//
//  PendingTestSession.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation

struct PendingTestSession: Codable, Equatable, Identifiable {
    var id: String {
        Self.storageId(examLanguage: examLanguage, variant: variant, uiLearningLanguage: uiLearningLanguage)
    }

    let uiLearningLanguage: String
    let examLanguage: String
    let variant: Int
    let sourceTitle: String?
    let totalQuestions: Int
    var currentIndex: Int
    var isChecked: Bool
    var textAnswers: [String: String]
    var selectedOptionTexts: [String: [String]]
    var updatedAt: Date

    static func storageId(examLanguage: String, variant: Int, uiLearningLanguage: String) -> String {
        "\(examLanguage)|\(variant)|\(uiLearningLanguage)"
    }

    var hasMeaningfulProgress: Bool {
        if currentIndex > 0 { return true }
        if isChecked { return true }
        if textAnswers.values.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return true
        }
        return selectedOptionTexts.values.contains { !$0.isEmpty }
    }

    var displayTitleLine: String {
        let s = sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if s.isEmpty { return "Вариант \(variant)" }
        return "\(s) · вар. \(variant)"
    }
}
