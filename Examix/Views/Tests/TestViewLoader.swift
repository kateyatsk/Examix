//
//  TestViewLoader.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 4.05.25.
//

import SwiftUI

struct TestViewLoader: View {
    let language: String
    var variant: Int? = nil

    @StateObject private var viewModel = TestViewModel()
    @State private var error: String? = nil
    @State private var loadingTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if let _ = viewModel.test {
                TestView(viewModel: viewModel)
            } else if let error = error {
                Text("Ошибка: \(error)")
                    .foregroundColor(.red)
            } else {
                ProgressView("Загрузка теста...")
            }
        }
        .task {
            if viewModel.test == nil {
                loadingTask?.cancel()
                loadingTask = Task {
                    await loadTest()
                }
            }
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }

    private func loadTest() async {
        do {
            let firestore = FirestoreTestService()

            if let variant = variant {
                let fetched = try await firestore.fetchTest(language: language, variant: variant)
                await MainActor.run {
                    viewModel.setTest(fetched)
                }
            } else {
                guard let fetched = try await firestore.fetchRandomTest(for: language) else {
                    await MainActor.run {
                        self.error = "Нет тестов для выбранного языка"
                    }
                    return
                }
                await MainActor.run {
                    viewModel.setTest(fetched)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}
