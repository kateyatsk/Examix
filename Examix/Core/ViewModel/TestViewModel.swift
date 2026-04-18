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

    func setTest(_ test: TestVariant) {
        self.test = test
        self.currentIndex = 0
        self.isChecked = false
        self.finishedResult = nil
        self.selectedOptions = [:]
        self.textAnswers = [:]
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
                let correct = question.options.first?.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let userAnswer = textAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                if correct == userAnswer {
                    correctCount += 1
                } else {
                    answers[question.id] = userAnswer
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
                    questionTypesById: questionTypes,
                    correctOptionsById: correctOptionsMap
                )
                try await firestoreService.saveTestResult(result, for: userId)

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
}


struct TestVariant: Decodable {
    let language: String
    let variant: Int
    let questions: [Question]
}

struct Question: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let text: String?
    let type: String
    let options: [Option]
}

struct Option: Identifiable, Codable, Hashable {
    var id: String { text }
    let text: String
    let isCorrect: Bool
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
