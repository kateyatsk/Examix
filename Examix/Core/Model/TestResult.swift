//
//  TestResult.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 2.05.25.
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
    /// Позиция каждого задания в полном варианте (0…), в том же порядке, что и `allQuestionIDs`.
    /// Нужна, потому что в импорте ЦТ `Question.id` часто равен коду типа (A1, B1…) и повторяется внутри варианта — иначе разбор открывает «первое» такое задание, а не то, что решали.
    let questionIndicesInVariant: [Int]?
    let questionTypesById: [String: String]?
    let correctOptionsById: [String: [String]]?
    /// `nil` — результат полного/обычного прохода варианта. Иначе: `practice_daily`, `practice_theme`, `practice_type`.
    let entrySource: String?
    /// Подпись сессии: темы, коды типов, «Задание дня».
    let practiceDetail: String?
    /// Язык обучения из настроек на момент сохранения (сырое имя), для оттенков в списке.
    let uiLearningLanguage: String?
}

extension TestResult {
    /// Полный проход варианта (не отдельное задание из практики).
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

