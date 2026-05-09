//
//  VariantCatalogService.swift
//  Examix
//
//  Импорт JSON → SQLite и загрузка тестов (приоритет над Firestore).
//

import Foundation
import FirebaseFirestore

final class VariantCatalogService {
    static let shared = VariantCatalogService()

    private let local = LocalTestDatabase.shared
    private let firestore = FirestoreTestService()

    /// Короткое имя из UI («Русский») → ключ как в Firestore («Русский язык»).
    func firestoreLanguageKey(from uiLanguage: String) -> String {
        uiLanguage.hasSuffix(" язык") ? uiLanguage : uiLanguage + " язык"
    }

    /// Декодирует экспортированный JSON варианта и сохраняет в локальную БД.
    func importVariantJSON(data: Data) throws {
        let dto = try JSONDecoder().decode(ImportedVariantDTO.self, from: data)
        let test = ImportedVariantMapper.map(dto: dto)
        try local.upsert(test)
    }

    func importVariantJSON(at url: URL) throws {
        let data = try Data(contentsOf: url)
        try importVariantJSON(data: data)
    }

    /// Импортирует варианты из бандла: `CTVariants/*.json` и **любые** `.json` в корне `.app` (как файлы из группы Examix в Xcode).
    /// Файлы не в формате `ImportedVariantDTO` тихо пропускаются.
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
                // не экспорт ЦТ — например English.json / test_sample.json
            }
        }
    }

    /// Сначала локальная БД, затем Firestore.
    func fetchTest(uiLanguage: String, variant: Int) async throws -> TestVariant {
        let key = firestoreLanguageKey(from: uiLanguage)
        if let t = try local.fetch(language: key, variant: variant) {
            return t
        }
        return try await firestore.fetchTest(language: uiLanguage, variant: variant)
    }

    /// Случайный вариант только из локальной БД (без Firestore).
    func fetchRandomTest(uiLanguage: String) throws -> TestVariant? {
        importBundledCTVariants()
        let key = firestoreLanguageKey(from: uiLanguage)
        return try local.fetchRandom(language: key)
    }

    /// Все варианты из локальной БД для практики (импорт из бандла при необходимости).
    func fetchAllLocalVariants(uiLanguage: String) throws -> [TestVariant] {
        importBundledCTVariants()
        let key = firestoreLanguageKey(from: uiLanguage)
        return try local.fetchAll(language: key)
    }

    /// Номера вариантов для экрана выбора: сначала из БД; если пусто — из Firestore.
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
}
