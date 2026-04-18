//
//  FirestoreService.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 2.05.25.
//

import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()

    func saveTestResult(_ result: TestResult, for userId: String) async throws {
        try db.collection("users")
            .document(userId)
            .collection("results")
            .document(result.id)
            .setData(from: result)
    }

    func fetchResults(for userId: String) async throws -> [TestResult] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("results")
            .order(by: "timestamp", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: TestResult.self) }
    }
}
