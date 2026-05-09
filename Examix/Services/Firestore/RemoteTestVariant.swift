//
//  RemoteTestVariant.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 4.05.25.
//

import Foundation
import FirebaseFirestore

struct RemoteTestVariant: Codable {
    let language: String
    let variant: Int
    let questions: [Question]
    let sourceTitle: String?
}

final class FirestoreTestService {
    private let db = Firestore.firestore()

    func fetchTest(language: String, variant: Int) async throws -> TestVariant {
        let documentID = "\(language) язык_\(variant)"
        let docRef = db.collection("tests").document(documentID)

        let snapshot = try await docRef.getDocument()

        do {
            let data = try snapshot.data(as: RemoteTestVariant.self)
            return TestVariant(language: data.language, variant: data.variant, questions: data.questions)
        } catch {
            throw NSError(
                domain: "Firestore",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось декодировать тест: \(error.localizedDescription)"]
            )
        }
    }


    func fetchRandomTest(for language: String) async throws -> TestVariant? {
        let firestoreLanguage = language + " язык" 
        
        let snapshot = try await db.collection("tests")
            .whereField("language", isEqualTo: firestoreLanguage)
            .getDocuments()

        let tests = try snapshot.documents.compactMap {
            try $0.data(as: RemoteTestVariant.self)
        }

        return tests.randomElement().map {
            TestVariant(language: $0.language, variant: $0.variant, questions: $0.questions, sourceTitle: $0.sourceTitle)
        }
    }

}
