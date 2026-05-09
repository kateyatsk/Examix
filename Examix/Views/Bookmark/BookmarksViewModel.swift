//
//  BookmarksViewModel.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    @Published var isLoading = false

    func loadBookmarks() async {
        do {
            isLoading = true
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let snapshot = try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks")
                .getDocuments()

            bookmarks = snapshot.documents.compactMap { doc -> Bookmark? in
                guard let qid = doc["id"] as? String,
                      let title = doc["title"] as? String else { return nil }
                let text = doc["text"] as? String ?? ""
                let answer = doc["userTextAnswer"] as? String ?? ""
                let selected = doc["userSelectedOptions"] as? [String] ?? []
                let options = (doc["options"] as? [[String: Any]])?.compactMap { $0["text"] as? String } ?? []
                let correctAnswers = (doc["options"] as? [[String: Any]])?.compactMap {
                    ($0["isCorrect"] as? Bool == true) ? $0["text"] as? String : nil
                } ?? []
                let language = doc["language"] as? String ?? "-"
                let variant = doc["variant"] as? Int ?? 0
                let qType = doc["questionType"] as? String ?? doc["type"] as? String ?? ""
                let comment = doc["userComment"] as? String ?? ""
                let ts = (doc["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return Bookmark(
                    firebaseDocumentId: doc.documentID,
                    questionId: qid,
                    title: title,
                    text: text,
                    userTextAnswer: answer,
                    userSelectedOptions: selected,
                    options: options,
                    correctAnswers: correctAnswers,
                    language: language,
                    variant: variant,
                    questionType: qType,
                    userComment: comment,
                    bookmarkedAt: ts
                )
            }
            isLoading = false
        } catch {
            isLoading = false
        }
    }

    func deleteBookmark(_ bookmark: Bookmark) async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmark.firebaseDocumentId)
                .delete()
            await loadBookmarks()
        } catch {
        }
    }
}
