//
//  TestVariant.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation

enum TextAnswerNormalization: String, Codable, Hashable {
    case none
    case sortedDigits
    case matchingKey
}

struct TestVariant: Codable {
    let language: String
    let variant: Int
    let questions: [Question]
    let sourceTitle: String?

    init(language: String, variant: Int, questions: [Question], sourceTitle: String? = nil) {
        self.language = language
        self.variant = variant
        self.questions = questions
        self.sourceTitle = sourceTitle
    }
}

struct Question: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let text: String?
    let explanation: String?
    let themeTitle: String?
    let type: String
    let options: [Option]
    let textNormalization: TextAnswerNormalization

    init(
        id: String,
        title: String,
        text: String?,
        explanation: String? = nil,
        themeTitle: String? = nil,
        type: String,
        options: [Option],
        textNormalization: TextAnswerNormalization = .none
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.explanation = explanation
        self.themeTitle = themeTitle
        self.type = type
        self.options = options
        self.textNormalization = textNormalization
    }

    enum CodingKeys: String, CodingKey {
        case id, title, text, explanation, themeTitle, type, options, textNormalization
        case titleHTML, textHTML
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation)
        themeTitle = try c.decodeIfPresent(String.self, forKey: .themeTitle)
        type = try c.decode(String.self, forKey: .type)
        options = try c.decode([Option].self, forKey: .options)
        textNormalization = try c.decodeIfPresent(TextAnswerNormalization.self, forKey: .textNormalization) ?? .none
        _ = try c.decodeIfPresent(String.self, forKey: .titleHTML)
        _ = try c.decodeIfPresent(String.self, forKey: .textHTML)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(explanation, forKey: .explanation)
        try c.encodeIfPresent(themeTitle, forKey: .themeTitle)
        try c.encode(type, forKey: .type)
        try c.encode(options, forKey: .options)
        try c.encode(textNormalization, forKey: .textNormalization)
    }
}

struct Option: Identifiable, Codable, Hashable {
    var id: String { text }
    let text: String
    let isCorrect: Bool

    init(text: String, isCorrect: Bool) {
        self.text = text
        self.isCorrect = isCorrect
    }

    enum CodingKeys: String, CodingKey {
        case text, isCorrect, html, id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        isCorrect = try c.decode(Bool.self, forKey: .isCorrect)
        _ = try c.decodeIfPresent(String.self, forKey: .html)
        _ = try c.decodeIfPresent(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(text, forKey: .text)
        try c.encode(isCorrect, forKey: .isCorrect)
    }
}
