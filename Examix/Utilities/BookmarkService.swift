//
//  BookmarkService.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 4.05.25.
//

import SwiftUI
import FirebaseFirestore

final class BookmarkService {
    private let db = Firestore.firestore()

    func addBookmark(_ question: Question, language: String, variant: Int, for userId: String) async throws {
        let data: [String: Any] = [
            "id": question.id,
            "title": question.title,
            "language": language,
            "variant": variant,
            "timestamp": Timestamp(date: Date())
        ]
        try await db.collection("users").document(userId)
            .collection("bookmarks").document(question.id).setData(data)
    }
}
