//
//  FirestoreService.swift
//  Examix
//
//  Created by Kate Yatskevich on 2.05.25.
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

    func fetchResultsForAllUsers(from startDate: Date, to endDate: Date) async throws -> [TestResult] {
        let snapshot = try await db.collectionGroup("results")
            .whereField("timestamp", isGreaterThanOrEqualTo: startDate)
            .whereField("timestamp", isLessThanOrEqualTo: endDate)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            if let decoded = try? document.data(as: TestResult.self) {
                return decoded
            }

            let data = document.data()
            guard let correctAnswers = data["correctAnswers"] as? Int,
                  let totalQuestions = data["totalQuestions"] as? Int,
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                return nil
            }

            let userId = data["userId"] as? String
                ?? document.reference.parent.parent?.documentID
                ?? ""
            guard !userId.isEmpty else { return nil }

            return TestResult(
                id: document.documentID,
                userId: userId,
                language: data["language"] as? String ?? "",
                variant: data["variant"] as? Int ?? 0,
                correctAnswers: correctAnswers,
                totalQuestions: totalQuestions,
                timestamp: timestamp,
                answers: data["answers"] as? [String: String] ?? [:],
                allQuestionIDs: data["allQuestionIDs"] as? [String] ?? [],
                questionIndicesInVariant: data["questionIndicesInVariant"] as? [Int],
                questionTypesById: data["questionTypesById"] as? [String: String],
                correctOptionsById: data["correctOptionsById"] as? [String: [String]],
                entrySource: data["entrySource"] as? String,
                practiceDetail: data["practiceDetail"] as? String,
                uiLearningLanguage: data["uiLearningLanguage"] as? String
            )
        }
    }
}
