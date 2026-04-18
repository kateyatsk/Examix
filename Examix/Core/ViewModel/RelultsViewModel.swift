//
//  RelultsViewModel.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 2.05.25.
//

import Foundation

final class ResultsViewModel: ObservableObject {
    @Published var results: [TestResult] = []
    private let firestoreService = FirestoreService()
    
    func loadResults() async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let fetchedResults = try await firestoreService.fetchResults(for: userId)
            await MainActor.run {
                self.results = fetchedResults
            }
        } catch {
            print("Ошибка загрузки результатов: \(error)")
        }
    }
}
