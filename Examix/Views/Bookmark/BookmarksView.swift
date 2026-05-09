//
//  BookmarksView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.05.25.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Модель

struct Bookmark: Identifiable, Hashable {
    /// Совпадает с id документа Firestore: `questionId_variant_language`.
    var id: String { firebaseDocumentId }

    let firebaseDocumentId: String
    let questionId: String
    let title: String
    let text: String
    let userTextAnswer: String
    let userSelectedOptions: [String]
    let options: [String]
    let correctAnswers: [String]
    let language: String
    let variant: Int
    let questionType: String
    var userComment: String
    let bookmarkedAt: Date

    var compositeLine: String {
        "\(language) · вар. \(variant)"
    }
}

// MARK: - Список

struct BookmarksView: View {
    @State private var bookmarks: [Bookmark] = []
    @State private var isLoading = false
    @State private var searchText: String = ""
    @State private var sortNewestFirst = true
    @State private var selectedLanguage: String = "Все языки"
    @State private var selectedType: String = "Все типы"
    @State private var datePeriod: BookmarksDatePeriod = .all

    private var allLanguages: [String] {
        let langs = Set(bookmarks.map(\.language))
        return ["Все языки"] + langs.sorted()
    }

    private var allTypes: [String] {
        let types = Set(bookmarks.map(\.questionType).filter { !$0.isEmpty })
        return ["Все типы"] + types.sorted()
    }

    private var filteredBookmarks: [Bookmark] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let fromDate: Date? = {
            switch datePeriod {
            case .all: return nil
            case .days7: return cal.date(byAdding: .day, value: -7, to: todayStart)
            case .days30: return cal.date(byAdding: .day, value: -30, to: todayStart)
            case .days90: return cal.date(byAdding: .day, value: -90, to: todayStart)
            }
        }()

        let filtered = bookmarks.filter { b in
            if selectedLanguage != "Все языки", b.language != selectedLanguage { return false }
            if selectedType != "Все типы", b.questionType != selectedType { return false }
            if let from = fromDate, b.bookmarkedAt < from { return false }
            if searchText.isEmpty { return true }
            let q = searchText.lowercased()
            return b.title.lowercased().contains(q)
                || b.text.lowercased().contains(q)
                || b.questionId.lowercased().contains(q)
                || b.userComment.lowercased().contains(q)
                || b.compositeLine.lowercased().contains(q)
        }

        return filtered.sorted {
            sortNewestFirst ? $0.bookmarkedAt > $1.bookmarkedAt : $0.bookmarkedAt < $1.bookmarkedAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ExamixStyle.practiceScreenWash
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    bookmarksFiltersSection
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                if isLoading {
                        Spacer()
                        ProgressView("Загрузка…")
                            .tint(ExamixStyle.accentCool)
                            .font(.custom("MontserratAlternates-Medium", size: 15))
                        Spacer()
                    } else if filteredBookmarks.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(ExamixStyle.accentMuted.opacity(0.5))
                            Text(bookmarks.isEmpty ? "Нет сохранённых вопросов" : "Ничего не найдено")
                                .font(.custom("MontserratAlternates-Bold", size: 17))
                                .foregroundStyle(Color(.darkAccent))
                            Text(bookmarks.isEmpty ? "Закладки появятся из прохождения теста." : "Измените поиск, период или фильтры.")
                                .font(.custom("MontserratAlternates-Regular", size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredBookmarks) { bookmark in
                                NavigationLink {
                                    BookmarkDetailView(
                                        bookmark: bookmark,
                                        onBookmarksChanged: { Task { await loadBookmarks() } }
                                    )
                                } label: {
                                    BookmarkResultStyleRow(bookmark: bookmark)
                                        .padding(.vertical, 4)
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await deleteBookmark(bookmark) }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .environment(\.defaultMinListRowHeight, 1)
                    }
                }
            }
            .navigationTitle("Закладки")
            .navigationBarTitleDisplayMode(.large)
        .onAppear {
                Task { await loadBookmarks() }
            }
        }
    }

    private var bookmarksFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ExamixStyle.accentCool)
                    TextField("Поиск по тексту, комментарию, номеру…", text: $searchText)
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundStyle(Color(.darkAccent))
                        .examixPlainTextFieldInput()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )

                Button {
                    sortNewestFirst.toggle()
                } label: {
                    Image(systemName: sortNewestFirst ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(ExamixStyle.accentDeep)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sortNewestFirst ? "Сначала новые" : "Сначала старые")
            }

            Menu {
                Picker("Период", selection: $datePeriod) {
                    ForEach(BookmarksDatePeriod.allCases, id: \.self) { p in
                        Text(p.menuTitle).tag(p)
                    }
                }
            } label: {
                filterMenuRow(title: "Период", value: datePeriod.menuTitle)
            }
            .tint(ExamixStyle.accentCool)

            Menu {
                Picker("Язык", selection: $selectedLanguage) {
                    ForEach(allLanguages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
            } label: {
                filterMenuRow(title: "Предмет", value: selectedLanguage)
            }
            .tint(ExamixStyle.accentCool)

            Menu {
                Picker("Тип задания", selection: $selectedType) {
                    ForEach(allTypes, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
            } label: {
                filterMenuRow(title: "Тип", value: selectedType)
            }
            .tint(ExamixStyle.accentCool)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ExamixStyle.cardFill)
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ExamixStyle.accentCool.opacity(0.14), lineWidth: 1)
        )
    }

    private func filterMenuRow(title: String, value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.custom("MontserratAlternates-Bold", size: 9))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.custom("MontserratAlternates-Medium", size: 14))
                .foregroundStyle(Color(.darkAccent))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ExamixStyle.accentCool.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
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
                let docId = doc.documentID
                let qType = doc["questionType"] as? String ?? doc["type"] as? String ?? ""
                let comment = doc["userComment"] as? String ?? ""
                let ts = (doc["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return Bookmark(
                    firebaseDocumentId: docId,
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

            await MainActor.run {
                self.bookmarks = loaded
                self.isLoading = false
            }
        } catch {
            print("Ошибка загрузки закладок: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    private func deleteBookmark(_ bookmark: Bookmark) async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmark.firebaseDocumentId)
                .delete()
            await loadBookmarks()
        } catch {
            print("Ошибка удаления закладки: \(error)")
        }
    }
}

// MARK: - Период (как в результатах, упрощённо)

private enum BookmarksDatePeriod: String, CaseIterable, Hashable {
    case all
    case days7
    case days30
    case days90

    var menuTitle: String {
        switch self {
        case .all: return "Всё время"
        case .days7: return "7 дней"
        case .days30: return "30 дней"
        case .days90: return "90 дней"
        }
    }
}

// MARK: - Карточка в стиле «Подробные ответы» в результатах

private struct BookmarkResultStyleRow: View {
    let bookmark: Bookmark

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(bookmark.questionId)
                                .font(.custom("MontserratAlternates-Bold", size: 14))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(ExamixStyle.squircleFill))

                            Text("Закладка")
                                .font(.custom("MontserratAlternates-Medium", size: 14))
                                .foregroundStyle(ExamixStyle.accentCool)
                        }

                        Text(.init(bookmark.title))
                            .font(.custom("MontserratAlternates-Medium", size: 15))
                            .foregroundStyle(Color(.darkAccent))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        Text(bookmark.compositeLine)
                            .font(.custom("MontserratAlternates-Regular", size: 12))
                            .foregroundStyle(.secondary)

                        if !bookmark.questionType.isEmpty {
                            Text("Тип: \(bookmark.questionType)")
                                .font(.custom("MontserratAlternates-Regular", size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(bookmark.bookmarkedAt.formatted(date: .numeric, time: .shortened))
                        .font(.custom("MontserratAlternates-Regular", size: 11))
                        .foregroundStyle(.secondary)
                }

                if !bookmark.userComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("«\(bookmark.userComment)»")
                        .font(.custom("MontserratAlternates-Medium", size: 13))
                        .foregroundStyle(Color(.darkAccent).opacity(0.85))
                        .lineLimit(2)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ExamixStyle.cardFill)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ExamixStyle.accentCool.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Детальный экран (как разбор задания в результатах)

private struct BookmarkDetailView: View {
    let bookmark: Bookmark
    /// После сохранения комментария или удаления закладки.
    let onBookmarksChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var commentDraft: String
    @State private var isSavingComment = false
    @State private var showDeleteConfirm = false
    @State private var showCommentSavedToast = false
    /// После сохранения обновляем базу сравнения (модель `bookmark` из навигации не меняется).
    @State private var savedCommentBaseline: String

    private var trimmedDraft: String {
        commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var commentUnchanged: Bool {
        trimmedDraft == savedCommentBaseline.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(bookmark: Bookmark, onBookmarksChanged: @escaping () -> Void) {
        self.bookmark = bookmark
        self.onBookmarksChanged = onBookmarksChanged
        _commentDraft = State(initialValue: bookmark.userComment)
        _savedCommentBaseline = State(initialValue: bookmark.userComment)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Закладка")
                        .font(.custom("MontserratAlternates-Bold", size: 20))
                        .foregroundStyle(Color(.darkAccent))
                    Text(bookmark.compositeLine)
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundStyle(.secondary)
                }

                sectionTitle("Формулировка")
                Text(.init(bookmark.title))
                    .font(.custom("MontserratAlternates-Medium", size: 16))
                    .foregroundStyle(Color(.darkAccent))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !bookmark.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sectionTitle("Текст / фрагмент")
                    Text(.init(bookmark.text))
                        .font(.custom("MontserratAlternates-Regular", size: 16))
                        .foregroundStyle(Color(.darkAccent))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                sectionTitle("Ответы")
                VStack(alignment: .leading, spacing: 12) {
                    if !bookmark.userTextAnswer.isEmpty {
                        answerPill(label: "Мой ответ (текст)", text: bookmark.userTextAnswer)
                    }
                    if !bookmark.userSelectedOptions.isEmpty {
                        answerPill(label: "Выбранные варианты", text: bookmark.userSelectedOptions.joined(separator: ", "))
                    }
                    if !bookmark.correctAnswers.isEmpty {
                        answerPill(label: "Правильный ответ", text: bookmark.correctAnswers.joined(separator: ", "), highlightCorrect: true)
                    }
                }

                if !bookmark.options.isEmpty {
                    sectionTitle("Варианты в задании")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(bookmark.options, id: \.self) { opt in
                            Text("• \(opt)")
                                .font(.custom("MontserratAlternates-Regular", size: 15))
                                .foregroundStyle(Color(.darkAccent))
                        }
                    }
                }

                sectionTitle("Комментарий")
                TextField("Заметка к этому заданию…", text: $commentDraft, axis: .vertical)
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .lineLimit(3...8)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(ExamixStyle.accentCool.opacity(0.2), lineWidth: 1)
                    )

                Button {
                    Task { await saveComment() }
                } label: {
                    Text(isSavingComment ? "Сохранение…" : "Сохранить комментарий")
                        .font(.custom("MontserratAlternates-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(commentUnchanged || isSavingComment ? Color.gray.opacity(0.38) : ExamixStyle.accentCool)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSavingComment || commentUnchanged)
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(ExamixStyle.practiceScreenWash.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if showCommentSavedToast {
                Text("Комментарий сохранён")
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.16, green: 0.52, blue: 0.42))
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showCommentSavedToast)
        .navigationTitle("Задание \(bookmark.questionId)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Удалить закладку?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                Task {
                    await deleteSelf()
                }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.custom("MontserratAlternates-Bold", size: 13))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func answerPill(label: String, text: String, highlightCorrect: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("MontserratAlternates-Regular", size: 11))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.custom("MontserratAlternates-Medium", size: 15))
                .foregroundStyle(Color(.darkAccent))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(highlightCorrect ? Color.green.opacity(0.1) : Color.blue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(highlightCorrect ? Color.green.opacity(0.3) : Color.blue.opacity(0.18), lineWidth: 1)
        )
    }

    private func saveComment() async {
        isSavingComment = true
        defer { isSavingComment = false }
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmark.firebaseDocumentId)
                .setData(["userComment": commentDraft], merge: true)
            await MainActor.run {
                savedCommentBaseline = commentDraft
                onBookmarksChanged()
                withAnimation { showCommentSavedToast = true }
            }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                withAnimation { showCommentSavedToast = false }
            }
        } catch {
            print("Ошибка сохранения комментария: \(error)")
        }
    }

    private func deleteSelf() async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmark.firebaseDocumentId)
                .delete()
            await MainActor.run {
                onBookmarksChanged()
                dismiss()
            }
        } catch {
            print("Ошибка удаления: \(error)")
        }
    }
}

struct BookmarksView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BookmarksView()
        }
    }
}
