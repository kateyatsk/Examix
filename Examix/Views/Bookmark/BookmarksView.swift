//
//  BookmarksView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.05.25.
//

import SwiftUI
import FirebaseFirestore

struct BookmarksView: View {
    @State private var bookmarks: [Bookmark] = []
    @State private var isLoading = false
    @State private var searchText: String = ""
    @State private var sortDescending: Bool = true
    @State private var selectedLanguage: String = "Все языки"

    private var allLanguages: [String] {
        let langs = Set(bookmarks.map { $0.language })
        return ["Все языки"] + langs.sorted()
    }

    private var filteredBookmarks: [Bookmark] {
        let filtered = bookmarks.filter { bookmark in
            (selectedLanguage == "Все языки" || bookmark.language == selectedLanguage) &&
            (searchText.isEmpty ||
             bookmark.title.localizedCaseInsensitiveContains(searchText) ||
             bookmark.text.localizedCaseInsensitiveContains(searchText) ||
             bookmark.id.localizedCaseInsensitiveContains(searchText))
        }
        return filtered.sorted {
            sortDescending ? $0.variant > $1.variant : $0.variant < $1.variant
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Загрузка закладок...")
                        .padding()
                } else {
                    HStack {
                        TextField("Поиск...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: {
                            sortDescending.toggle()
                        }) {
                            Image(systemName: sortDescending ? "arrow.down" : "arrow.up")
                        }
                    }
                    .padding(.horizontal)

                    Picker("Язык", selection: $selectedLanguage) {
                        ForEach(allLanguages, id: \ .self) { lang in
                            Text(lang)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal)

                    if filteredBookmarks.isEmpty {
                        Text("Нет сохранённых вопросов")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    } else {
                        ForEach(filteredBookmarks) { bookmark in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Text(bookmark.id)
                                        .font(.custom("MontserratAlternates-Bold", size: 18))
                                        .padding(8)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(10)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(bookmark.title)
                                            .font(.custom("MontserratAlternates-Medium", size: 16))
                                        if !bookmark.text.isEmpty {
                                            Text(bookmark.text)
                                                .font(.custom("MontserratAlternates-Regular", size: 15))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                if !bookmark.userTextAnswer.isEmpty {
                                    Text("Мой ответ: \(bookmark.userTextAnswer)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                if !bookmark.userSelectedOptions.isEmpty {
                                    Text("Выбранные: \(bookmark.userSelectedOptions.joined(separator: ", "))")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                if !bookmark.options.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Варианты ответа:")
                                            .font(.footnote.bold())
                                        ForEach(bookmark.options, id: \ .self) { option in
                                            Text("• \(option)")
                                                .font(.footnote)
                                                .foregroundColor(.primary)
                                        }
                                        let correctAnswers = bookmark.correctAnswers
                                        if !correctAnswers.isEmpty {
                                            Text("Правильный ответ: \(correctAnswers.joined(separator: ", "))")
                                                .font(.footnote)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                HStack {
                                    Text("Вариант: \(bookmark.variant)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("Язык: \(bookmark.language)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await deleteBookmark(bookmark)
                                    }
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Мои закладки")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadBookmarks()
            }
        }
    }

    private func loadBookmarks() async {
        do {
            isLoading = true
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let snapshot = try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks")
                .getDocuments()

            let loaded = snapshot.documents.compactMap { doc -> Bookmark? in
                guard let id = doc["id"] as? String,
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
                return Bookmark(id: id, title: title, text: text, userTextAnswer: answer, userSelectedOptions: selected, options: options, correctAnswers: correctAnswers, language: language, variant: variant)
            }

            await MainActor.run {
                self.bookmarks = loaded
                self.isLoading = false
            }
        } catch {
            print("Ошибка загрузки закладок: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func deleteBookmark(_ bookmark: Bookmark) async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let bookmarkId = "\(bookmark.id)_\(bookmark.variant)_\(bookmark.language)"
            try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmarkId)
                .delete()

            await loadBookmarks()
        } catch {
            print("Ошибка удаления закладки: \(error)")
        }
    }
}


struct Bookmark: Identifiable {
    let id: String
    let title: String
    let text: String
    let userTextAnswer: String
    let userSelectedOptions: [String]
    let options: [String]
    let correctAnswers: [String]
    let language: String
    let variant: Int
}

struct BookmarksView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BookmarksView()
        }
    }
}
