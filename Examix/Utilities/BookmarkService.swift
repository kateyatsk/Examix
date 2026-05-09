//
//  BookmarkService.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 4.05.25.
//

import FirebaseFirestore

final class BookmarkService {
    private let db = Firestore.firestore()

    /// Идентификатор документа совпадает с логикой в `TestView` / `BookmarksView`.
    private static func bookmarkDocumentId(questionId: String, variant: Int, language: String) -> String {
        "\(questionId)_\(variant)_\(language)"
    }

    func addBookmark(
        _ question: Question,
        language: String,
        variant: Int,
        for userId: String,
        userTextAnswer: String?,
        userSelectedOptions: [String]
    ) async throws {
        let bookmarkId = Self.bookmarkDocumentId(questionId: question.id, variant: variant, language: language)

        let data: [String: Any] = [
            "id": question.id,
            "title": question.title,
            "text": question.text ?? "",
            "explanation": question.explanation ?? "",
            "type": question.type,
            "questionType": question.type,
            "options": question.options.map { ["text": $0.text, "isCorrect": $0.isCorrect] },
            "userTextAnswer": userTextAnswer ?? "",
            "userSelectedOptions": userSelectedOptions,
            "userComment": "",
            "language": language,
            "variant": variant,
            "timestamp": Timestamp(date: Date())
        ]

        try await db.collection("users").document(userId)
            .collection("bookmarks").document(bookmarkId).setData(data)
    }
}
