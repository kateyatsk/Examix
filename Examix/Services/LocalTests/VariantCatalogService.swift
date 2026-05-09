//
//  VariantCatalogService.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation
import FirebaseFirestore

final class VariantCatalogService {
    static let shared = VariantCatalogService()

    private let local = LocalTestDatabase.shared
    private let firestore = FirestoreTestService()

    func firestoreLanguageKey(from uiLanguage: String) -> String {
        uiLanguage.hasSuffix(" язык") ? uiLanguage : uiLanguage + " язык"
    }

    func importVariantJSON(data: Data) throws {
        let dto = try JSONDecoder().decode(ImportedVariantDTO.self, from: data)
        let test = ImportedVariantMapper.map(dto: dto)
        try local.upsert(test)
    }

    func importVariantJSON(at url: URL) throws {
        let data = try Data(contentsOf: url)
        try importVariantJSON(data: data)
    }

    func importBundledCTVariants() {
        var candidateURLs: [URL] = []
        if let fromSubdir = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "CTVariants") {
            candidateURLs.append(contentsOf: fromSubdir)
        }
        if let resourceRoot = Bundle.main.resourceURL {
            let fm = FileManager.default
            if let top = try? fm.contentsOfDirectory(at: resourceRoot, includingPropertiesForKeys: nil) {
                candidateURLs.append(contentsOf: top.filter { $0.pathExtension.lowercased() == "json" })
            }
            let ctFolder = resourceRoot.appendingPathComponent("CTVariants", isDirectory: true)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: ctFolder.path, isDirectory: &isDir), isDir.boolValue,
               let inside = try? fm.contentsOfDirectory(at: ctFolder, includingPropertiesForKeys: nil) {
                candidateURLs.append(contentsOf: inside.filter { $0.pathExtension.lowercased() == "json" })
            }
        }
        var seen = Set<String>()
        for url in candidateURLs {
            guard seen.insert(url.path).inserted else { continue }
            do {
                try importVariantJSON(at: url)
            } catch {
            }
        }
    }

    func fetchTest(uiLanguage: String, variant: Int) async throws -> TestVariant {
        let key = firestoreLanguageKey(from: uiLanguage)
        if let t = try local.fetch(language: key, variant: variant) {
            return t
        }
        return try await firestore.fetchTest(language: uiLanguage, variant: variant)
    }

    func fetchRandomTest(uiLanguage: String) throws -> TestVariant? {
        importBundledCTVariants()
        let key = firestoreLanguageKey(from: uiLanguage)
        let variants = try local.fetchAll(language: key)
        guard !variants.isEmpty else { return nil }
        let grouped = Dictionary(grouping: variants.flatMap { variant in
            variant.questions.map { question in
                RandomQuestionCandidate(question: question)
            }
        }, by: { $0.question.id })

        let questions = grouped
            .keys
            .sorted(by: Self.questionIDComesBefore)
            .compactMap { grouped[$0]?.randomElement()?.question }

        guard !questions.isEmpty else { return try local.fetchRandom(language: key) }
        return TestVariant(
            language: key,
            variant: Int.random(in: 900_000...999_999),
            questions: questions,
            sourceTitle: "Случайный сборный вариант"
        )
    }

    func fetchAllLocalVariants(uiLanguage: String) throws -> [TestVariant] {
        importBundledCTVariants()
        let key = firestoreLanguageKey(from: uiLanguage)
        return try local.fetchAll(language: key)
    }

    func listVariantNumbers(uiLanguage: String) async throws -> [Int] {
        let key = firestoreLanguageKey(from: uiLanguage)
        let localList = try local.listVariantNumbers(language: key)
        if !localList.isEmpty {
            return localList
        }
        return try await fetchVariantNumbersFromFirestore(uiLanguage: uiLanguage)
    }

    private func fetchVariantNumbersFromFirestore(uiLanguage: String) async throws -> [Int] {
        let firestoreLanguage = firestoreLanguageKey(from: uiLanguage)
        let snapshot = try await Firestore.firestore()
            .collection("tests")
            .whereField("language", isEqualTo: firestoreLanguage)
            .getDocuments()
        let variants = snapshot.documents.compactMap {
            ($0.data()["variant"] as? NSNumber)?.intValue
        }
        return Array(Set(variants)).sorted()
    }

    private struct RandomQuestionCandidate {
        let question: Question
    }

    private static func questionIDComesBefore(_ lhs: String, _ rhs: String) -> Bool {
        let l = questionSortKey(lhs)
        let r = questionSortKey(rhs)
        if l.prefix != r.prefix { return l.prefix < r.prefix }
        if l.number != r.number { return l.number < r.number }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private static func questionSortKey(_ id: String) -> (prefix: String, number: Int) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let prefix = String(trimmed.prefix { !$0.isNumber })
        let digits = String(trimmed.drop { !$0.isNumber }.prefix { $0.isNumber })
        return (prefix.isEmpty ? trimmed : prefix, Int(digits) ?? Int.max)
    }
}
