//
//  RulesView.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.05.25.
//

import Foundation
import SwiftUI
import PDFKit

struct RulesView: View {
    let language: Language
    @State private var searchText = ""
    @State private var committedSearch = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ExamixStyle.accentCool)
                TextField("Поиск в PDF…", text: $searchText)
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .foregroundStyle(Color(.darkAccent))
                    .submitLabel(.search)
                    .onSubmit { committedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

                Button("Найти") {
                    committedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .font(.custom("MontserratAlternates-Bold", size: 15))
                .foregroundStyle(ExamixStyle.accentCool)
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ExamixStyle.accentCool.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            PDFSearchableRulesView(language: language, searchQuery: committedSearch)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ExamixStyle.screenCanvas.ignoresSafeArea())
        .navigationTitle("Правила")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PDFSearchableRulesView: UIViewRepresentable {
    let language: Language
    let searchQuery: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = Self.loadDocument(for: language)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        guard let doc = uiView.document else { return }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            context.coordinator.lastQuery = ""
            uiView.highlightedSelections = nil
            uiView.currentSelection = nil
            return
        }
        if context.coordinator.lastQuery == q { return }
        context.coordinator.lastQuery = q

        let found = doc.findString(q, withOptions: .caseInsensitive)
        guard !found.isEmpty else {
            uiView.highlightedSelections = nil
            uiView.currentSelection = nil
            return
        }
        uiView.highlightedSelections = found
        if let first = found.first {
            uiView.currentSelection = first
            uiView.go(to: first)
        }
    }

    private static func loadDocument(for language: Language) -> PDFDocument? {
        let fileName: String
        switch language {
        case .russian: fileName = "russian_rules"
        case .english: fileName = "english_rules"
        case .french: fileName = "french_rules"
        case .german: fileName = "german_rules"
        case .belarusian: fileName = "belarusian_rules"
        }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "pdf") else { return nil }
        return PDFDocument(url: url)
    }

    final class Coordinator {
        var lastQuery: String = ""
    }
}
