//
//  TestViewModel.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 23.04.25.
//

import SwiftUI

final class TestViewModel: ObservableObject {

    @Published var test: TestVariant?
    @Published var selectedOptions: [String: Set<Option>] = [:]
    @Published var textAnswers: [String: String] = [:]
    @Published var isChecked = false
    @Published var currentIndex = 0
    @Published var finishedResult: TestResult? = nil
    /// Сохранять ли итог в Firestore при завершении (для практики теперь тоже `true`).
    var persistToFirestore: Bool = true
    /// См. `TestResult.entrySource` — для практики не `nil`.
    private var resultEntrySource: String?
    private var resultPracticeDetail: String?
    private var resultUILearningLanguage: String?
    /// Параллельно `test.questions` при сохранении: индекс задания в полном варианте (для практики с одним заданием — реальный индекс, не 0).
    private var resultQuestionIndicesInVariant: [Int]?

    private let firestoreService = FirestoreService()

    var isLastQuestion: Bool {
        guard let test else { return true }
        return currentIndex == test.questions.count - 1
    }

    var progress: Int {
        guard let test else { return 0 }
        let answered = selectedOptions.count + textAnswers.count
        return test.questions.isEmpty ? 0 : Int((Double(answered) / Double(test.questions.count)) * 100)
    }

    init(test: TestVariant? = nil) {
        self.test = test
    }

    func setTest(
        _ test: TestVariant,
        persistToFirestore: Bool = true,
        entrySource: String? = nil,
        practiceDetail: String? = nil,
        uiLearningLanguage: String? = nil,
        questionIndicesInVariant: [Int]? = nil
    ) {
        self.test = test
        self.currentIndex = 0
        self.isChecked = false
        self.finishedResult = nil
        self.selectedOptions = [:]
        self.textAnswers = [:]
        self.persistToFirestore = persistToFirestore
        self.resultEntrySource = entrySource
        self.resultPracticeDetail = practiceDetail
        self.resultUILearningLanguage = uiLearningLanguage
        self.resultQuestionIndicesInVariant = questionIndicesInVariant
    }

    /// Сброс после одного задания в режиме практики (перед следующим вопросом).
    func resetAfterPracticeRound() {
        finishedResult = nil
        isChecked = false
        selectedOptions = [:]
        textAnswers = [:]
    }

    /// Восстановление прогресса из локального черновика (незаконченный вариант).
    func applyPendingResume(_ draft: PendingTestSession) {
        guard let test else { return }
        guard test.language == draft.examLanguage, test.variant == draft.variant else { return }
        finishedResult = nil
        currentIndex = min(max(0, draft.currentIndex), max(0, test.questions.count - 1))
        isChecked = draft.isChecked
        textAnswers = draft.textAnswers
        selectedOptions = Self.selectedOptionSets(from: draft.selectedOptionTexts, questions: test.questions)
    }

    func snapshotPendingSession(uiLearningLanguage: String) -> PendingTestSession? {
        guard let test else { return nil }
        var optTexts: [String: [String]] = [:]
        for (qid, set) in selectedOptions {
            optTexts[qid] = set.map(\.text)
        }
        return PendingTestSession(
            uiLearningLanguage: uiLearningLanguage,
            examLanguage: test.language,
            variant: test.variant,
            sourceTitle: test.sourceTitle,
            totalQuestions: test.questions.count,
            currentIndex: currentIndex,
            isChecked: isChecked,
            textAnswers: textAnswers,
            selectedOptionTexts: optTexts,
            updatedAt: Date()
        )
    }

    private static func selectedOptionSets(from texts: [String: [String]], questions: [Question]) -> [String: Set<Option>] {
        var out: [String: Set<Option>] = [:]
        for q in questions {
            guard let chosen = texts[q.id] else { continue }
            let opts = Set(q.options.filter { chosen.contains($0.text) })
            if !opts.isEmpty { out[q.id] = opts }
        }
        return out
    }

    func select(option: Option, for question: Question) {
        if question.type == "multi" {
            if selectedOptions[question.id, default: []].contains(option) {
                selectedOptions[question.id]?.remove(option)
            } else {
                selectedOptions[question.id, default: []].insert(option)
            }
        } else {
            selectedOptions[question.id] = [option]
        }
    }

    func nextQuestion() {
        if !isLastQuestion {
            currentIndex += 1
        } else {
            checkAnswers()
        }
    }

    func checkAnswers() {
        guard let test else { return }
        isChecked = true

        var correctCount = 0
        var answers: [String: String] = [:]
        var questionTypes: [String: String] = [:]
        var correctOptionsMap: [String: [String]] = [:]

        for question in test.questions {
            questionTypes[question.id] = question.type

            let correctOptions = Set(question.options.filter { $0.isCorrect }.map { $0.text })
            if question.type != "text" {
                correctOptionsMap[question.id] = Array(correctOptions)
            }

            switch question.type {
            case "text":
                let correctRaw = question.options.first?.text ?? ""
                let userRaw = textAnswers[question.id] ?? ""
                let correct = Self.normalizeTextAnswer(correctRaw, mode: question.textNormalization)
                let userAnswer = Self.normalizeTextAnswer(userRaw, mode: question.textNormalization)
                if correct == userAnswer {
                    correctCount += 1
                } else {
                    answers[question.id] = userRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                }

            case "multi":
                let selected = selectedOptions[question.id] ?? []
                let selectedTexts = Set(selected.map { $0.text })

                if selectedTexts == correctOptions {
                    correctCount += 1
                } else {
                    let selectedText = selected.map { $0.text }.joined(separator: ", ")
                    answers[question.id] = selectedText
                }

            default: // single
                let selected = selectedOptions[question.id] ?? []
                let selectedTexts = Set(selected.map { $0.text })

                if selectedTexts == correctOptions {
                    correctCount += 1
                } else {
                    let selectedText = selected.map { $0.text }.joined(separator: ", ")
                    answers[question.id] = selectedText
                }
            }
        }

        let allIDs = test.questions.map { $0.id }
        let indicesToSave: [Int]? = {
            if let explicit = resultQuestionIndicesInVariant,
               explicit.count == allIDs.count {
                return explicit
            }
            return Array(test.questions.indices)
        }()

        Task {
            do {
                let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
                let result = TestResult(
                    userId: userId,
                    language: test.language,
                    variant: test.variant,
                    correctAnswers: correctCount,
                    totalQuestions: test.questions.count,
                    timestamp: Date(),
                    answers: answers,
                    allQuestionIDs: allIDs,
                    questionIndicesInVariant: indicesToSave,
                    questionTypesById: questionTypes,
                    correctOptionsById: correctOptionsMap,
                    entrySource: resultEntrySource,
                    practiceDetail: resultPracticeDetail,
                    uiLearningLanguage: resultUILearningLanguage
                )
                if persistToFirestore {
                    try await firestoreService.saveTestResult(result, for: userId)
                }

                await MainActor.run {
                    self.finishedResult = result
                }
            } catch {
                print("Ошибка сохранения результата: \(error)")
            }
        }
    }

    func isAnswerGiven(for question: Question) -> Bool {
        switch question.type {
        case "multi", "single":
            return !(selectedOptions[question.id]?.isEmpty ?? true)
        case "text":
            return !(textAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        default:
            return false
        }
    }
    
    func partialCount(for result: TestResult) -> Int {
        guard result.language == "Русский язык" || result.language == "Белорусский язык",
              let correctMap = result.correctOptionsById,
              let types = result.questionTypesById else { return 0 }

        var partial = 0

        for (id, type) in types {
            guard type == "multi",
                  let answer = result.answers[id],
                  let correctArray = correctMap[id] else {
                continue
            }

            let correct = Set(correctArray)
            let selected = Set(answer.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })

            if !selected.isEmpty,
               selected.isSubset(of: correct),
               selected.count < correct.count {
                partial += 1
            }
        }

        return partial
    }
    deinit {
        print("TestViewModel deallocated")
    }

    private static func normalizeTextAnswer(_ raw: String, mode: TextAnswerNormalization) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .none:
            return trimmed.lowercased()
        case .sortedDigits:
            return String(trimmed.filter(\.isNumber).sorted())
        case .matchingKey:
            return trimmed.uppercased().filter { $0.isLetter || $0.isNumber }
        }
    }
}

enum TextAnswerNormalization: String, Codable, Hashable {
    case none
    case sortedDigits
    case matchingKey
}

struct TestVariant: Codable {
    let language: String
    let variant: Int
    let questions: [Question]
    /// Подпись из JSON (`sourceTitle`); для экрана выбора варианта и шапки теста.
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
    /// Разбор задания из импорта (`explanation` в JSON); для подсказки в тесте.
    let explanation: String?
    /// Тема из импорта ЦТ (`themeTitle`); для группировки в практике по темам.
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

// MARK: - Незаконченные варианты (локально)

struct PendingTestSession: Codable, Equatable, Identifiable {
    /// Ключ хранения: язык экзамена + вариант + язык обучения из настроек.
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
    /// id вопроса → выбранные формулировки вариантов (для восстановления `Option`).
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

enum PendingTestSessionStore {
    private static let defaultsKey = "examix.pendingTestSessions.v1"

    static func allSessions() -> [PendingTestSession] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let list = try? JSONDecoder().decode([PendingTestSession].self, from: data) else { return [] }
        return list.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func sessions(uiLearningLanguage: String) -> [PendingTestSession] {
        allSessions().filter { $0.uiLearningLanguage == uiLearningLanguage }
    }

    static func load(id: String) -> PendingTestSession? {
        allSessions().first { $0.id == id }
    }

    static func upsert(_ session: PendingTestSession) {
        var list = allSessions().filter { $0.id != session.id }
        list.append(session)
        persist(list)
    }

    static func remove(id: String) {
        let list = allSessions().filter { $0.id != id }
        persist(list)
    }

    static func remove(examLanguage: String, variant: Int, uiLearningLanguage: String) {
        remove(id: PendingTestSession.storageId(examLanguage: examLanguage, variant: variant, uiLearningLanguage: uiLearningLanguage))
    }

    private static func persist(_ list: [PendingTestSession]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

enum TestLoader {
    static func loadTest(named filename: String) -> TestVariant? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("Test file not found: \(filename)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([TestVariant].self, from: data)
            return decoded.randomElement()
        } catch {
            print("Failed to decode test: \(error)")
            return nil
        }
    }
}
