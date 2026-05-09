//
//  TestViewModel.swift
//  Examix
//
//  Created by Kate Yatskevich on 23.04.25.
//

import SwiftUI

final class TestViewModel: ObservableObject {

    @Published var test: TestVariant?
    @Published var selectedOptions: [String: Set<Option>] = [:]
    @Published var textAnswers: [String: String] = [:]
    @Published var isChecked = false
    @Published var currentIndex = 0
    @Published var finishedResult: TestResult? = nil
    var persistToFirestore: Bool = true
    private var resultEntrySource: String?
    private var resultPracticeDetail: String?
    private var resultUILearningLanguage: String?
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

    func resetAfterPracticeRound() {
        finishedResult = nil
        isChecked = false
        selectedOptions = [:]
        textAnswers = [:]
    }

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

            default:
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
