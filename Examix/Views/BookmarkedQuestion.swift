//
//  BookmarksView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 4.05.25.
//

import SwiftUI
import FirebaseFirestore

struct BookmarkedQuestion: Identifiable, Codable {
    var id: String
    let title: String
    let language: String
    let variant: Int
    let timestamp: Date
}

final class BookmarksViewModel: ObservableObject {
    @Published var bookmarks: [BookmarkedQuestion] = []

    func loadBookmarks() async {
        do {
            guard let userId = try? AuthenticationManager.shared.getAuthenticatedUser().uid else { return }
            let snapshot = try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks")
                .order(by: "timestamp", descending: true)
                .getDocuments()

            let loaded = snapshot.documents.compactMap { doc -> BookmarkedQuestion? in
                try? doc.data(as: BookmarkedQuestion.self)
            }
            await MainActor.run {
                self.bookmarks = loaded
            }
        } catch {
            print("\u{274C} Ошибка загрузки закладок: \(error)")
        }
    }
}

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.bookmarks) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.custom("MontserratAlternates-Bold", size: 16))
                    Text("Вариант \(item.variant), \(item.language)")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundColor(.gray)
                    Text(item.timestamp.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Закладки")
            .onAppear {
                Task {
                    await viewModel.loadBookmarks()
                }
            }
        }
    }
}

#Preview {
    BookmarksView()
}
