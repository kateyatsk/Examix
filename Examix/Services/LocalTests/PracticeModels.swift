//
//  PracticeModels.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation

struct PracticeQuestionRef: Hashable, Codable {
    let language: String
    let variant: Int
    let questionIndex: Int

    var stableKey: String { "\(language)|\(variant)|\(questionIndex)" }

    func singleQuestionVariant(from full: TestVariant) -> TestVariant? {
        guard questionIndex >= 0, questionIndex < full.questions.count else { return nil }
        let q = full.questions[questionIndex]
        return TestVariant(language: full.language, variant: full.variant, questions: [q], sourceTitle: full.sourceTitle)
    }
}

final class PracticeProgressStore {
    static let shared = PracticeProgressStore()

    private let defaults = UserDefaults.standard

    private func storageKey(bucket: String) -> String { "practiceSolved.\(bucket)" }

    func solvedKeys(for bucket: String) -> Set<String> {
        guard let arr = defaults.stringArray(forKey: storageKey(bucket: bucket)) else { return [] }
        return Set(arr)
    }

    func markSolved(bucket: String, refKey: String) {
        var s = solvedKeys(for: bucket)
        s.insert(refKey)
        defaults.set(Array(s), forKey: storageKey(bucket: bucket))
    }
}

enum PracticeLibrary {


    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func calendarDayKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        var c = DateComponents()
        c.year = comps.year
        c.month = comps.month
        c.day = comps.day
        c.hour = 0
        c.minute = 0
        c.second = 0
        let start = calendar.date(from: c) ?? date
        return dayKeyFormatter.string(from: start)
    }

    static func dailyProgressBucket(dayKey: String, languageKey: String) -> String {
        "dailySolved:\(dayKey):\(languageKey)"
    }

    static func stableHash64(_ string: String) -> UInt64 {
        var h: UInt64 = 14_695_981_103_932_746_037
        for b in string.utf8 {
            h ^= UInt64(b)
            h &*= 1_099_515_211_235
        }
        return h
    }

    static func dailyRef(forDayKey dayKey: String, languageKey: String, refs: [PracticeQuestionRef]) -> PracticeQuestionRef? {
        guard !refs.isEmpty else { return nil }
        let sorted = refs.sorted { $0.stableKey < $1.stableKey }
        let seed = "\(languageKey)|\(dayKey)"
        let idx = Int(stableHash64(seed) % UInt64(sorted.count))
        return sorted[idx]
    }

    static func typeProgress(typeCode: String, variants: [TestVariant], store: PracticeProgressStore) -> (solved: Int, total: Int) {
        typesAggregateProgress(typeCodes: Set([typeCode]), variants: variants, store: store)
    }

    static func themeProgress(themeDisplayTitle title: String, variants: [TestVariant], store: PracticeProgressStore) -> (solved: Int, total: Int) {
        themesAggregateProgress(themeTitles: Set([title]), variants: variants, store: store)
    }

    static func themesAggregateProgress(themeTitles: Set<String>, variants: [TestVariant], store: PracticeProgressStore) -> (solved: Int, total: Int) {
        let all = allRefs(from: variants).filter { ref in
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { return false }
            let t = themeDisplayTitle(for: v.questions[ref.questionIndex])
            return themeTitles.contains(t)
        }
        var solved = 0
        for ref in all {
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { continue }
            let t = themeDisplayTitle(for: v.questions[ref.questionIndex])
            let bucket = bucketForTheme(displayTitle: t)
            if store.solvedKeys(for: bucket).contains(ref.stableKey) {
                solved += 1
            }
        }
        return (solved, all.count)
    }

    static func typesAggregateProgress(typeCodes: Set<String>, variants: [TestVariant], store: PracticeProgressStore) -> (solved: Int, total: Int) {
        let all = allRefs(from: variants).filter { ref in
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { return false }
            return typeCodes.contains(v.questions[ref.questionIndex].id)
        }
        var solved = 0
        for ref in all {
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { continue }
            let id = v.questions[ref.questionIndex].id
            let bucket = bucketForTypeCode(id)
            if store.solvedKeys(for: bucket).contains(ref.stableKey) {
                solved += 1
            }
        }
        return (solved, all.count)
    }

    static func refs(
        typeCodes: Set<String>,
        from variants: [TestVariant],
        store: PracticeProgressStore
    ) -> [PracticeQuestionRef] {
        allRefs(from: variants).filter { ref in
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { return false }
            let id = v.questions[ref.questionIndex].id
            guard typeCodes.contains(id) else { return false }
            let bucket = bucketForTypeCode(id)
            return !store.solvedKeys(for: bucket).contains(ref.stableKey)
        }
    }

    static func refs(
        themeTitles: Set<String>,
        from variants: [TestVariant],
        store: PracticeProgressStore
    ) -> [PracticeQuestionRef] {
        allRefs(from: variants).filter { ref in
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { return false }
            let t = themeDisplayTitle(for: v.questions[ref.questionIndex])
            guard themeTitles.contains(t) else { return false }
            let bucket = bucketForTheme(displayTitle: t)
            return !store.solvedKeys(for: bucket).contains(ref.stableKey)
        }
    }

    static func themeDisplayTitle(for question: Question) -> String {
        let t = question.themeTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Без темы" : t
    }

    static func bucketForTheme(displayTitle: String) -> String {
        "theme:\(displayTitle)"
    }

    static func bucketForTypeCode(_ code: String) -> String {
        "type:\(code)"
    }

    static func allRefs(from variants: [TestVariant]) -> [PracticeQuestionRef] {
        variants.flatMap { v in
            v.questions.indices.map { PracticeQuestionRef(language: v.language, variant: v.variant, questionIndex: $0) }
        }
    }

    static func sortedTypeCodes(from variants: [TestVariant]) -> [String] {
        let set = Set(variants.flatMap { $0.questions.map(\.id) })
        return set.sorted { lhs, rhs in
            typeSortKey(lhs) < typeSortKey(rhs)
        }
    }

    private static func typeSortKey(_ code: String) -> (String, Int) {
        let letters = code.prefix { $0.isLetter }.map(String.init).joined().uppercased()
        let rest = code.drop { $0.isLetter }
        let num = Int(String(rest)) ?? 10_000
        return (letters.isEmpty ? code : letters, num)
    }

    static func themeRows(from variants: [TestVariant]) -> [(title: String, count: Int)] {
        var counts: [String: Int] = [:]
        for q in variants.flatMap(\.questions) {
            let t = themeDisplayTitle(for: q)
            counts[t, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.title < $1.title }
    }

    static func refs(
        typeCode: String,
        from variants: [TestVariant],
        excluding solved: Set<String>
    ) -> [PracticeQuestionRef] {
        allRefs(from: variants).filter { ref in
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { return false }
            let q = v.questions[ref.questionIndex]
            guard q.id == typeCode else { return false }
            return !solved.contains(ref.stableKey)
        }
    }

    static func refs(
        themeDisplayTitle title: String,
        from variants: [TestVariant],
        excluding solved: Set<String>
    ) -> [PracticeQuestionRef] {
        allRefs(from: variants).filter { ref in
            guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                  ref.questionIndex < v.questions.count else { return false }
            let q = v.questions[ref.questionIndex]
            guard themeDisplayTitle(for: q) == title else { return false }
            return !solved.contains(ref.stableKey)
        }
    }
}
