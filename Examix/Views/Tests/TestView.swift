//
//  TestView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI
import FirebaseFirestore
import AlertToast

private struct MultipleChoiceView: View {
    let question: Question
    @ObservedObject var viewModel: TestViewModel
    
    var body: some View {
        ForEach(question.options) { option in
            let isSelected = viewModel.selectedOptions[question.id]?.contains(option) ?? false
            let isCorrect = option.isCorrect
            let isChecked = viewModel.isChecked
            
            Button(action: {
                viewModel.select(option: option, for: question)
            }) {
                HStack {
                    Text(.init(option.text))
                        .font(.custom("MontserratAlternates-Medium", size: 16))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.brown)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isChecked ?
                            (isCorrect ? Color.green : (isSelected ? Color.red : Color.gray.opacity(0.3))) :
                                (isSelected ? Color.brown : Color.gray.opacity(0.3)),
                            lineWidth: 2
                        )
                )
            }
            .disabled(isChecked)
        }
    }
}

private struct TextAnswerView: View {
    let question: Question
    @ObservedObject var viewModel: TestViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(
                "Введите ответ",
                text: Binding<String>(
                    get: {
                        viewModel.textAnswers[question.id, default: ""]
                    },
                    set: { newValue in
                        viewModel.textAnswers[question.id] = newValue
                    }
                )
            )
            .disabled(viewModel.isChecked)
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4)))
            
            if viewModel.isChecked {
                let correct = question.options.first?.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let userAnswer = viewModel.textAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                
                if userAnswer == correct {
                    Text(userAnswer)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                } else {
                    Text(userAnswer)
                        .strikethrough()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    
                    Text("Правильный ответ: \(question.options.first?.text ?? "")")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TestView: View {
    @ObservedObject var viewModel: TestViewModel
    @State private var showSummary = false
    @State private var showTextPopup = false
    @State private var hasSeenTextQuestion = false
    @State private var isBookmarked = false
    @State private var showBookmarkToast = false
    @State private var bookmarkTask: Task<Void, Never>? = nil
    
    var body: some View {
        if let test = viewModel.test {
            content(test: test)
                .onDisappear {
                    bookmarkTask?.cancel()
                }
        } else {
            ProgressView("Загрузка теста...")
        }
        
    }
    
    @ViewBuilder
    private func content(test: TestVariant) -> some View {
        if showSummary {
            if let result = viewModel.finishedResult {
                ResultSummaryView(
                    correctAnswers: result.correctAnswers,
                    totalQuestions: result.totalQuestions,
                    partialAnswers: viewModel.partialCount(for: result)
                ) {
                    showSummary = false
                }
            }
        } else if let result = viewModel.finishedResult {
            ResultDetailView(result: result)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(test.language)
                            .font(.custom("MontserratAlternates-Bold", size: 18))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.orange.opacity(0.3))
                            .cornerRadius(12)
                        
                        Text("Вариант \(test.variant)")
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("\(viewModel.progress)%")
                            .font(.custom("MontserratAlternates-Medium", size: 12))
                        ProgressView(value: Float(viewModel.progress) / 100.0)
                            .accentColor(.brown)
                    }
                    .padding(.horizontal)
                    
                    let question = test.questions[viewModel.currentIndex]
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Text(question.id)
                                    .font(.custom("MontserratAlternates-Bold", size: 18))
                                    .padding(8)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(10)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(.init(question.title))
                                        .font(.custom("MontserratAlternates-Medium", size: 16))
                                    if let text = question.text {
                                        Text(.init(text))
                                            .font(.custom("MontserratAlternates-Regular", size: 15))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if question.type == "multi" || question.type == "single" {
                                MultipleChoiceView(question: question, viewModel: viewModel)
                            } else if question.type == "text" {
                                TextAnswerView(question: question, viewModel: viewModel)
                            }
                        }
                        Spacer()
                        Button {
                            bookmarkTask?.cancel()
                            bookmarkTask = Task {
                                await toggleBookmark(question, test: test)
                            }
                        } label: {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .resizable()
                                .frame(width: 20, height: 24)
                                .foregroundColor(.secondaryBlue)
                        }
                    }
                    .padding(.horizontal)
                    .task {
                        await checkIfBookmarked(question, test: test)
                    }
                    
                    if !viewModel.isChecked {
                        VStack(spacing: 12) {
                            Button(action: {
                                if question.id.lowercased().contains("текст") {
                                    hasSeenTextQuestion = true
                                    
                                    if viewModel.isLastQuestion {
                                        viewModel.nextQuestion()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showSummary = true
                                        }
                                    } else {
                                        viewModel.nextQuestion()
                                    }
                                } else {
                                    viewModel.isChecked = true
                                }
                            }) {
                                Text(question.id.lowercased().contains("текст") ? "Далее" : "Проверить")
                                    .font(.custom("MontserratAlternates-Medium", size: 16))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        viewModel.isAnswerGiven(for: question) || question.id.lowercased().contains("текст") ? Color.brown : Color.gray.opacity(0.5)
                                    )
                                    .cornerRadius(12)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 20)
                            }
                            .disabled(!(viewModel.isAnswerGiven(for: question) || question.id.lowercased().contains("текст")))
                            
                            if hasSeenTextQuestion {
                                Button {
                                    showTextPopup = true
                                } label: {
                                    Text("Посмотреть текст")
                                        .font(.custom("MontserratAlternates-Bold", size: 16))
                                        .foregroundColor(.secondaryBlue)
                                        .padding(.horizontal, 32)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.isChecked = false
                                if viewModel.isLastQuestion {
                                    viewModel.nextQuestion()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showSummary = true
                                    }
                                } else {
                                    viewModel.nextQuestion()
                                }
                                isBookmarked = false
                            }) {
                                Text(viewModel.isLastQuestion ? "Завершить" : "Следующий")
                                    .font(.custom("MontserratAlternates-Medium", size: 16))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 20)
                            }
                            
                            if hasSeenTextQuestion {
                                Button {
                                    showTextPopup = true
                                } label: {
                                    Text("Посмотреть текст")
                                        .font(.custom("MontserratAlternates-Bold", size: 16))
                                        .foregroundColor(.secondaryBlue)
                                        .padding(.horizontal, 32)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
                .sheet(isPresented: $showTextPopup) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(test.questions.filter { $0.id.lowercased().contains("текст") }) { q in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Текст к заданиям")
                                        .font(.custom("MontserratAlternates-Bold", size: 16))
                                    Text(.init(q.title))
                                        .font(.custom("MontserratAlternates-Medium", size: 16))
                                        .foregroundColor(.secondary)
                                    if let extra = q.text {
                                        Text(.init(extra))
                                            .font(.custom("MontserratAlternates-Medium", size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .toast(isPresenting: $showBookmarkToast) {
                AlertToast(
                    type: .complete(.green),
                    title: "Добавлено в закладки"
                )
            }
        }
    }
    
    private func toggleBookmark(_ question: Question, test: TestVariant) async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let db = Firestore.firestore()
            let bookmarkId = "\(question.id)_\(test.variant)_\(test.language)"
            let docRef = db.collection("users").document(userId)
                .collection("bookmarks").document(bookmarkId)
            
            let snapshot = try await docRef.getDocument()
            
            if snapshot.exists {
                try await docRef.delete()
                await MainActor.run {
                    isBookmarked = false
                }
            } else {
                try await BookmarkService().addBookmark(
                    question,
                    language: test.language,
                    variant: test.variant,
                    for: userId,
                    userTextAnswer: viewModel.textAnswers[question.id],
                    userSelectedOptions: viewModel.selectedOptions[question.id]?.map(\.text) ?? []
                )
                await MainActor.run {
                    isBookmarked = true
                    showBookmarkToast = true
                }
            }
        } catch {
            print("Ошибка при переключении закладки: \(error)")
        }
    }
    
    private func checkIfBookmarked(_ question: Question, test: TestVariant) async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let bookmarkId = "\(question.id)_\(test.variant)_\(test.language)"
            let docRef = Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmarkId)
            
            let snapshot = try await docRef.getDocument()
            await MainActor.run {
                isBookmarked = snapshot.exists
            }
        } catch {
            print("Ошибка при проверке закладки: \(error)")
            await MainActor.run {
                isBookmarked = false
            }
        }
    }
}




final class BookmarkService {
    private let db = Firestore.firestore()
    
    func addBookmark(
        _ question: Question,
        language: String,
        variant: Int,
        for userId: String,
        userTextAnswer: String?,
        userSelectedOptions: [String]
    ) async throws {
        let bookmarkId = "\(question.id)_\(variant)_\(language)"
        
        let data: [String: Any] = [
            "id": question.id,
            "title": question.title,
            "text": question.text ?? "",
            "type": question.type,
            "options": question.options.map { ["text": $0.text, "isCorrect": $0.isCorrect] },
            "userTextAnswer": userTextAnswer ?? "",
            "userSelectedOptions": userSelectedOptions,
            "language": language,
            "variant": variant,
            "timestamp": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId)
            .collection("bookmarks").document(bookmarkId).setData(data)
    }
}


#Preview {
    ResultSummaryView(correctAnswers: 8, totalQuestions: 10, partialAnswers: 2) {
        print("Продолжить")
    }
}
