//
//  TestResult.swift
//  Examix
//
//  Created by Kate Yatskevich on 2.05.25.
//

import Foundation

struct TestResult: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    let userId: String
    let language: String
    let variant: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let timestamp: Date
    let answers: [String: String]
    let allQuestionIDs: [String]
    let questionIndicesInVariant: [Int]?
    let questionTypesById: [String: String]?
    let correctOptionsById: [String: [String]]?
    let entrySource: String?
    let practiceDetail: String?
    let uiLearningLanguage: String?
}

extension TestResult {
    var isFullVariantResult: Bool { entrySource == nil }

    var isPracticeEntry: Bool { entrySource != nil }

    var practiceKindTitle: String? {
        switch entrySource {
        case "practice_daily": return "Задание дня"
        case "practice_theme": return "Практика по теме"
        case "practice_type": return "Практика по типу"
        default: return nil
        }
    }

    var totalQuestionsIDs: [String] { allQuestionIDs }
}

