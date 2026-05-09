//
//  ImportedVariantJSON.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation


struct ImportedVariantDTO: Decodable {
    let variantId: Int
    let title: String?
    let sourceTitle: String?
    let subjectCode: String
    let instructions: [String]?
    let tasks: [ImportedTaskDTO]

    enum CodingKeys: String, CodingKey {
        case variantId, title, sourceTitle, subjectCode, instructions, tasks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        variantId = try c.decode(Int.self, forKey: .variantId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        sourceTitle = try c.decodeIfPresent(String.self, forKey: .sourceTitle)
        subjectCode = try c.decode(String.self, forKey: .subjectCode)
        instructions = try c.decodeIfPresent([String].self, forKey: .instructions)
        tasks = try c.decode([ImportedTaskDTO].self, forKey: .tasks)
    }
}

struct ImportedTaskDTO: Decodable {
    let order: Int
    let taskInternalId: Int?
    let typeCode: String
    let themeTitle: String?
    let prompt: String
    let options: [ImportedOptionDTO]
    let passage: String?
    let passageText: String?
    let correctAnswerRaw: String?
    let answerMode: String
    let answerInputType: String?
    let explanation: String?
    private let correctAnswerNormalizedStorage: ImportedCorrectAnswer?

    enum CodingKeys: String, CodingKey {
        case order, taskInternalId, typeCode, themeTitle, prompt, options, passage, passageText
        case correctAnswerRaw, answerMode, answerInputType, correctAnswerNormalized, explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = try c.decode(Int.self, forKey: .order)
        taskInternalId = try c.decodeIfPresent(Int.self, forKey: .taskInternalId)
        typeCode = try c.decode(String.self, forKey: .typeCode)
        themeTitle = try c.decodeIfPresent(String.self, forKey: .themeTitle)
        prompt = try c.decode(String.self, forKey: .prompt)
        options = try c.decodeIfPresent([ImportedOptionDTO].self, forKey: .options) ?? []
        passage = try c.decodeIfPresent(String.self, forKey: .passage)
        passageText = try c.decodeIfPresent(String.self, forKey: .passageText)
        correctAnswerRaw = try c.decodeIfPresent(String.self, forKey: .correctAnswerRaw)
        answerMode = try c.decode(String.self, forKey: .answerMode)
        answerInputType = try c.decodeIfPresent(String.self, forKey: .answerInputType)
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation)
        correctAnswerNormalizedStorage = try ImportedCorrectAnswer.decode(from: c, key: .correctAnswerNormalized)
    }

    var correctAnswerNormalized: ImportedCorrectAnswer? { correctAnswerNormalizedStorage }

    var resolvedReadingPassage: String? {
        for raw in [passage, passageText] {
            let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !t.isEmpty { return t }
        }
        return nil
    }
}

struct ImportedOptionDTO: Decodable {
    let index: Int
    let text: String
}


struct ImportedMatchingPair: Equatable {
    let left: String
    let right: Int
}

enum ImportedCorrectAnswer: Equatable {
    case integers([Int])
    case text(String)
    case matching(pairs: [ImportedMatchingPair])

    static func decode(from container: KeyedDecodingContainer<ImportedTaskDTO.CodingKeys>, key: ImportedTaskDTO.CodingKeys) throws -> ImportedCorrectAnswer? {
        guard container.contains(key) else { return nil }
        if let ints = try? container.decode([Int].self, forKey: key) {
            return .integers(ints)
        }
        if let s = try? container.decode(String.self, forKey: key) {
            return .text(s)
        }
        if let pairs = try? container.decode([MatchingPairDTO].self, forKey: key) {
            return .matching(pairs: pairs.map { ImportedMatchingPair(left: $0.left, right: $0.right) })
        }
        return nil
    }
}

private struct MatchingPairDTO: Decodable {
    let left: String
    let right: Int
}


enum SubjectCodeMapper {
    static func firestoreLanguage(forSubjectCode code: String) -> String {
        switch code.lowercased() {
        case "rus_ct": return "Русский язык"
        case "bel_ct", "belarus_ct": return "Белорусский язык"
        default:
            return code.replacingOccurrences(of: "_", with: " ")
        }
    }
}


enum ImportedVariantMapper {
    static func map(dto: ImportedVariantDTO) -> TestVariant {
        let language = SubjectCodeMapper.firestoreLanguage(forSubjectCode: dto.subjectCode)
        let sortedTasks = dto.tasks.sorted { $0.order < $1.order }
        let questions = sortedTasks.map { mapTask($0) }
        return TestVariant(language: language, variant: dto.variantId, questions: questions, sourceTitle: dto.sourceTitle)
    }

    private static func mapTask(_ t: ImportedTaskDTO) -> Question {
        let id = t.typeCode
        let title = t.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = t.resolvedReadingPassage
        let explanation = mappedExplanation(t)
        let themeTitle = themeTitle(for: t)

        switch (t.answerMode, t.answerInputType) {
        case ("multi_select", "text"):
            return shortTextQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle, normalization: textNormalizationForFreeAnswer(t))
        case ("selection", "checkbox"), ("multi_select", _):
            return selectionCheckboxQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle)
        case ("selection", "radio"):
            return selectionRadioQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle)
        case ("short_text", _):
            return shortTextQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle, normalization: textNormalizationForFreeAnswer(t))
        case ("multi_choice", _):
            return shortTextQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle, normalization: .sortedDigits)
        case ("matching", _):
            return matchingQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle)
        default:
            if t.options.isEmpty {
                return shortTextQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle, normalization: textNormalizationForFreeAnswer(t))
            }
            if t.answerInputType == "checkbox" {
                return selectionCheckboxQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle)
            }
            return selectionRadioQuestion(t, id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle)
        }
    }

    private static func themeTitle(for t: ImportedTaskDTO) -> String? {
        let s = t.themeTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    private static func mappedExplanation(_ t: ImportedTaskDTO) -> String? {
        let s = t.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    private static func mapOptions(_ t: ImportedTaskDTO, correct: Set<Int>) -> [Option] {
        t.options.map { opt in
            let plain = opt.text.isEmpty ? " " : opt.text
            return Option(text: plain, isCorrect: correct.contains(opt.index))
        }
    }

    private static func textNormalizationForFreeAnswer(_ t: ImportedTaskDTO) -> TextAnswerNormalization {
        let raw = t.correctAnswerRaw ?? ""
        let digitsOnly = raw.filter(\.isNumber)
        if !digitsOnly.isEmpty, digitsOnly.count == raw.count, raw.count > 1 {
            return .sortedDigits
        }
        return .none
    }

    private static func selectionCheckboxQuestion(_ t: ImportedTaskDTO, id: String, title: String, text: String?, explanation: String?, themeTitle: String?) -> Question {
        let correct = Set(correctIndices(from: t))
        let opts = mapOptions(t, correct: correct)
        return Question(id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle, type: "multi", options: opts, textNormalization: .none)
    }

    private static func selectionRadioQuestion(_ t: ImportedTaskDTO, id: String, title: String, text: String?, explanation: String?, themeTitle: String?) -> Question {
        let correct = Set(correctIndices(from: t))
        let opts = mapOptions(t, correct: correct)
        return Question(id: id, title: title, text: text, explanation: explanation, themeTitle: themeTitle, type: "single", options: opts, textNormalization: .none)
    }

    private static func shortTextQuestion(_ t: ImportedTaskDTO, id: String, title: String, text: String?, explanation: String?, themeTitle: String?, normalization: TextAnswerNormalization) -> Question {
        let answer = canonicalShortTextAnswer(t)
        return Question(
            id: id,
            title: title,
            text: text,
            explanation: explanation,
            themeTitle: themeTitle,
            type: "text",
            options: [Option(text: answer, isCorrect: true)],
            textNormalization: normalization
        )
    }

    private static func matchingQuestion(_ t: ImportedTaskDTO, id: String, title: String, text: String?, explanation: String?, themeTitle: String?) -> Question {
        let answer: String
        switch t.correctAnswerNormalized {
        case .some(.text(let s)):
            answer = s
        case .some(.matching(let pairs)):
            let sortedPairs = pairs.sorted { $0.left < $1.left }
            answer = sortedPairs.map { "\($0.left)\($0.right)" }.joined()
        default:
            answer = t.correctAnswerRaw ?? ""
        }
        return Question(
            id: id,
            title: title,
            text: text,
            explanation: explanation,
            themeTitle: themeTitle,
            type: "text",
            options: [Option(text: answer, isCorrect: true)],
            textNormalization: .matchingKey
        )
    }

    private static func canonicalShortTextAnswer(_ t: ImportedTaskDTO) -> String {
        if let norm = t.correctAnswerNormalized {
            switch norm {
            case .text(let s): return s
            case .integers(let ints): return ints.map(String.init).joined()
            case .matching:
                break
            }
        }
        return t.correctAnswerRaw ?? ""
    }

    private static func correctIndices(from t: ImportedTaskDTO) -> [Int] {
        if case .some(.integers(let ints)) = t.correctAnswerNormalized {
            return ints
        }
        let raw = t.correctAnswerRaw ?? ""
        return raw.compactMap { Int(String($0)) }
    }
}
