//
//  PracticeViews.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import SwiftUI


private enum PracticeStyle {
    static let restingBorder = Color(red: 0.48, green: 0.61, blue: 0.70).opacity(0.42)
    static let selectedBorder = Color(red: 0.08, green: 0.26, blue: 0.38).opacity(0.96)
    static let selectedFill = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.34, blue: 0.48),
            Color(red: 0.18, green: 0.46, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func progressBlueFill(fraction: Double) -> Color {
        let t = min(max(fraction, 0), 1)
        let light = (r: 0.90, g: 0.95, b: 1.0)
        let dark = (r: 0.18, g: 0.42, b: 0.62)
        return Color(
            red: light.r + (dark.r - light.r) * t,
            green: light.g + (dark.g - light.g) * t,
            blue: light.b + (dark.b - light.b) * t
        )
    }

    static func progressLabelColor(fraction: Double) -> Color {
        fraction > 0.48 ? Color.white : Color(.darkAccent)
    }

    static func cardLabelColor(isSelected: Bool, fraction: Double) -> Color {
        isSelected ? .white : progressLabelColor(fraction: fraction)
    }
}

private struct MidnightCountdownView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let sec = Self.secondsUntilEndOfCalendarDay(from: context.date)
            Text(Self.formatHMS(sec))
                .font(.custom("MontserratAlternates-Bold", size: 32))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private static func secondsUntilEndOfCalendarDay(from date: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let next = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return max(0, Int(next.timeIntervalSince(date)))
    }

    private static func formatHMS(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        return String(format: "%02d:%02d:%02d", h, m, r)
    }
}


struct PracticeDailyView: View {
    let uiLanguage: String

    @StateObject private var vm = TestViewModel()
    @State private var currentRef: PracticeQuestionRef?
    @State private var loadError: String?
    @State private var alreadyDoneToday = false

    private var langKey: String { VariantCatalogService.shared.firestoreLanguageKey(from: uiLanguage) }

    private var dayKey: String { PracticeLibrary.calendarDayKey() }

    private var dailyBucket: String { PracticeLibrary.dailyProgressBucket(dayKey: dayKey, languageKey: langKey) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.96, blue: 0.99), ExamixStyle.screenCanvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let err = loadError {
                Text(err)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if alreadyDoneToday {
                dailyCompletedCard
            } else if let ref = currentRef, singleTest(for: ref) != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Сегодняшнее задание")
                        .font(.custom("MontserratAlternates-Bold", size: 18))
                        .foregroundColor(.darkAccent)
                        .padding(.horizontal, 4)
                    Text("Одно задание на день. После полуночи — новое.")
                        .font(.custom("MontserratAlternates-Medium", size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)

                    TestView(
                        viewModel: vm,
                        practiceMode: true,
                        practiceInlineFeedback: true,
                        practiceOnFinished: {
                            if let r = currentRef {
                                PracticeProgressStore.shared.markSolved(bucket: dailyBucket, refKey: r.stableKey)
                            }
                            vm.resetAfterPracticeRound()
                            alreadyDoneToday = true
                        }
                    )
                    .id(ref.stableKey)
                }
                .padding(.horizontal, 12)
                .onChange(of: currentRef?.stableKey, initial: true) { _, _ in
                    guard let r = currentRef, let s = singleTest(for: r) else { return }
                    vm.setTest(
                        s,
                        persistToFirestore: true,
                        entrySource: "practice_daily",
                        practiceDetail: "Задание дня",
                        uiLearningLanguage: uiLanguage,
                        questionIndicesInVariant: [r.questionIndex]
                    )
                }
            } else {
                ProgressView("Загрузка…")
            }
        }
        .navigationTitle("Задание дня")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDaily()
        }
    }

    private var dailyCompletedCard: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.35), Color.teal.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }

            VStack(spacing: 10) {
                Text("Новых заданий нет")
                    .font(.custom("MontserratAlternates-Bold", size: 26))
                    .foregroundColor(.darkAccent)
                    .multilineTextAlignment(.center)
                Text("Вы уже решили задание дня. Следующее появится в полночь.")
                    .font(.custom("MontserratAlternates-Medium", size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                Text("До нового задания")
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                    .foregroundColor(.white.opacity(0.9))
                MidnightCountdownView()
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.38, blue: 0.32), Color(red: 0.12, green: 0.28, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            )
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 32)
    }

    private func singleTest(for ref: PracticeQuestionRef) -> TestVariant? {
        guard let full = try? LocalTestDatabase.shared.fetch(language: ref.language, variant: ref.variant) else { return nil }
        return ref.singleQuestionVariant(from: full)
    }

    @MainActor
    private func loadDaily() async {
        do {
            let variants = try VariantCatalogService.shared.fetchAllLocalVariants(uiLanguage: uiLanguage)
            let refs = PracticeLibrary.allRefs(from: variants)
            let dk = PracticeLibrary.calendarDayKey()
            let lk = VariantCatalogService.shared.firestoreLanguageKey(from: uiLanguage)
            let bucket = PracticeLibrary.dailyProgressBucket(dayKey: dk, languageKey: lk)
            guard let ref = PracticeLibrary.dailyRef(forDayKey: dk, languageKey: lk, refs: refs) else {
                loadError = "Нет заданий в локальной базе для выбранного языка."
                return
            }
            currentRef = ref
            if PracticeProgressStore.shared.solvedKeys(for: bucket).contains(ref.stableKey) {
                alreadyDoneToday = true
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}


struct PracticeTypePickerView: View {
    @Binding var path: NavigationPath
    let uiLanguage: String

    @State private var types: [String] = []
    @State private var variants: [TestVariant] = []
    @State private var selected = Set<String>()
    @State private var isLoading = true
    @State private var loadError: String?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            ExamixStyle.practiceScreenWash.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Загрузка…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else if let err = loadError {
                        Text(err)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Выберите один или несколько типов, затем нажмите галочку вверху.")
                            .font(.custom("MontserratAlternates-Medium", size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        selectAllButton(totalCount: types.count, allValues: types)
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(types, id: \.self) { code in
                                typeCell(code: code)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Типы заданий")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ExamixToolbarTitle(text: "Типы заданий")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let codes = selected.sorted()
                    guard !codes.isEmpty else { return }
                    path.append(HomeView.Path.practiceTypeSession(codes))
                } label: {
                    HStack(spacing: 5) {
                        Text("\(selected.count)")
                            .font(.custom("MontserratAlternates-Bold", size: 13))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                    }
                    .foregroundStyle(selected.isEmpty ? Color.gray.opacity(0.55) : ExamixStyle.accentCool)
                }
                .disabled(selected.isEmpty)
                .accessibilityLabel("Начать практику")
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func selectAllButton(totalCount: Int, allValues: [String]) -> some View {
        if totalCount > 0 {
            Button {
                if selected.count == totalCount {
                    selected.removeAll()
                } else {
                    selected = Set(allValues)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selected.count == totalCount ? "xmark.circle" : "checkmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                    Text(selected.count == totalCount ? "Снять все" : "Выбрать все")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ExamixStyle.accentCool)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PracticeStyle.restingBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func typeCell(code: String) -> some View {
        let stats = PracticeLibrary.typeProgress(
            typeCode: code,
            variants: variants,
            store: PracticeProgressStore.shared
        )
        let frac = stats.total > 0 ? Double(stats.solved) / Double(stats.total) : 0
        let isOn = selected.contains(code)
        Button {
            if isOn { selected.remove(code) } else { selected.insert(code) }
        } label: {
            VStack(spacing: 6) {
                Text(code)
                    .font(.custom("MontserratAlternates-Bold", size: 17))
                    .foregroundColor(PracticeStyle.cardLabelColor(isSelected: isOn, fraction: frac))
                Text("\(stats.solved)/\(stats.total) · \(Int((frac * 100).rounded()))%")
                    .font(.custom("MontserratAlternates-Medium", size: 11))
                    .foregroundColor(PracticeStyle.cardLabelColor(isSelected: isOn, fraction: frac).opacity(0.92))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? AnyShapeStyle(PracticeStyle.selectedFill) : AnyShapeStyle(PracticeStyle.progressBlueFill(fraction: frac)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isOn ? PracticeStyle.selectedBorder : PracticeStyle.restingBorder, lineWidth: isOn ? 3 : 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func load() {
        do {
            let v = try VariantCatalogService.shared.fetchAllLocalVariants(uiLanguage: uiLanguage)
            variants = v
            types = PracticeLibrary.sortedTypeCodes(from: v)
            loadError = types.isEmpty ? "Нет заданий в базе." : nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}


struct PracticeByTypeSessionView: View {
    @Binding var path: NavigationPath
    let typeCodes: [String]
    let uiLanguage: String

    @StateObject private var vm = TestViewModel()
    @State private var currentRef: PracticeQuestionRef?
    @State private var loadError: String?
    @State private var exhausted = false
    @State private var sessionAttempts = 0
    @State private var sessionCorrect = 0
    @State private var catalogVariants: [TestVariant] = []
    @State private var catalogProgressNonce = 0

    private var typeSet: Set<String> { Set(typeCodes) }

    private var titleLine: String {
        let sorted = typeCodes.sorted()
        if sorted.count <= 2 { return sorted.joined(separator: ", ") }
        return "\(sorted.count) типов"
    }

    var body: some View {
        ZStack {
            ExamixStyle.practiceScreenWash.ignoresSafeArea()
            if exhausted {
                exhaustedTypeView
            } else if let err = loadError {
                Text(err).foregroundColor(.red).padding()
            } else if let ref = currentRef, singleTest(for: ref) != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Типы: \(titleLine)")
                        .font(.custom("MontserratAlternates-Bold", size: 17))
                        .foregroundColor(.darkAccent)
                        .padding(.horizontal)
                    Text("Сессия: \(sessionCorrect) верных из \(sessionAttempts)")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    TestView(
                        viewModel: vm,
                        practiceMode: true,
                        practiceInlineFeedback: true,
                        practiceOnFinished: { handleContinue() },
                        practiceCatalogSolved: typeSessionCatalogProgress?.solved,
                        practiceCatalogTotal: typeSessionCatalogProgress?.total
                    )
                    .id("\(ref.stableKey)-\(catalogProgressNonce)")
                }
                .onChange(of: currentRef?.stableKey, initial: true) { _, _ in
                    guard let r = currentRef, let s = singleTest(for: r) else { return }
                    vm.setTest(
                        s,
                        persistToFirestore: true,
                        entrySource: "practice_type",
                        practiceDetail: titleLine,
                        uiLearningLanguage: uiLanguage,
                        questionIndicesInVariant: [r.questionIndex]
                    )
                }
            } else {
                ProgressView("Подбор задания…")
            }
        }
        .navigationTitle("Практика")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pickNext()
        }
    }

    private var typeSessionCatalogProgress: (solved: Int, total: Int)? {
        guard !catalogVariants.isEmpty else { return nil }
        let _ = catalogProgressNonce
        let agg = PracticeLibrary.typesAggregateProgress(typeCodes: typeSet, variants: catalogVariants, store: PracticeProgressStore.shared)
        return agg.total > 0 ? agg : nil
    }

    private var exhaustedTypeView: some View {
        VStack(spacing: 20) {
            Text("Все выбранные задания решены")
                .font(.custom("MontserratAlternates-Bold", size: 22))
                .foregroundColor(.stock)
                .multilineTextAlignment(.center)
            Text("В этой сессии верных ответов: \(sessionCorrect) из \(sessionAttempts)")
                .font(.custom("MontserratAlternates-Medium", size: 16))
                .foregroundColor(.darkAccent)
                .multilineTextAlignment(.center)
            Button("Назад к списку типов") {
                path.removeLast()
            }
            .font(.custom("MontserratAlternates-Medium", size: 16))
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.brown)
            .cornerRadius(12)
            .padding(.horizontal, 32)
        }
        .padding()
    }

    private func singleTest(for ref: PracticeQuestionRef) -> TestVariant? {
        guard let full = try? LocalTestDatabase.shared.fetch(language: ref.language, variant: ref.variant) else { return nil }
        return ref.singleQuestionVariant(from: full)
    }

    private func bucketForRef(_ ref: PracticeQuestionRef) -> String? {
        guard let full = try? LocalTestDatabase.shared.fetch(language: ref.language, variant: ref.variant),
              ref.questionIndex < full.questions.count else { return nil }
        return PracticeLibrary.bucketForTypeCode(full.questions[ref.questionIndex].id)
    }

    @MainActor
    private func pickNext() async {
        do {
            let variants = try VariantCatalogService.shared.fetchAllLocalVariants(uiLanguage: uiLanguage)
            catalogVariants = variants
            let store = PracticeProgressStore.shared
            let candidates = PracticeLibrary.refs(typeCodes: typeSet, from: variants, store: store)
            guard let next = candidates.randomElement() else {
                exhausted = true
                currentRef = nil
                return
            }
            currentRef = next
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func handleContinue() {
        if let r = vm.finishedResult {
            sessionAttempts += 1
            if r.correctAnswers == r.totalQuestions { sessionCorrect += 1 }
        }
        if let ref = currentRef, let b = bucketForRef(ref) {
            PracticeProgressStore.shared.markSolved(bucket: b, refKey: ref.stableKey)
        }
        catalogProgressNonce += 1
        vm.resetAfterPracticeRound()
        Task { await pickNext() }
    }
}


struct PracticeThemeListView: View {
    @Binding var path: NavigationPath
    let uiLanguage: String

    @State private var rows: [(title: String, count: Int)] = []
    @State private var variants: [TestVariant] = []
    @State private var selected = Set<String>()
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            ExamixStyle.practiceScreenWash.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if isLoading {
                        ProgressView("Загрузка…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else if let err = loadError {
                        Text(err).foregroundColor(.red).padding()
                    } else {
                        Text("Выберите темы и нажмите галочку вверху, чтобы начать.")
                            .font(.custom("MontserratAlternates-Medium", size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        selectAllButton(totalCount: rows.count, allValues: rows.map(\.title))

                        ForEach(rows, id: \.title) { row in
                            themeRow(row: row)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Темы")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ExamixToolbarTitle(text: "Темы")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let titles = selected.sorted()
                    guard !titles.isEmpty else { return }
                    path.append(HomeView.Path.practiceThemeSession(titles))
                } label: {
                    HStack(spacing: 5) {
                        Text("\(selected.count)")
                            .font(.custom("MontserratAlternates-Bold", size: 13))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                    }
                    .foregroundStyle(selected.isEmpty ? Color.gray.opacity(0.55) : ExamixStyle.accentCool)
                }
                .disabled(selected.isEmpty)
                .accessibilityLabel("Начать практику по темам")
            }
        }
        .onAppear(perform: load)
    }

    private func themeRow(row: (title: String, count: Int)) -> some View {
        let stats = PracticeLibrary.themeProgress(
            themeDisplayTitle: row.title,
            variants: variants,
            store: PracticeProgressStore.shared
        )
        let frac = stats.total > 0 ? Double(stats.solved) / Double(stats.total) : 0
        let isOn = selected.contains(row.title)
        return Button {
            if isOn { selected.remove(row.title) } else { selected.insert(row.title) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundColor(PracticeStyle.cardLabelColor(isSelected: isOn, fraction: frac))
                        .multilineTextAlignment(.leading)
                    Text("\(stats.solved)/\(stats.total) · \(Int((frac * 100).rounded()))%")
                        .font(.custom("MontserratAlternates-Medium", size: 12))
                        .foregroundColor(PracticeStyle.cardLabelColor(isSelected: isOn, fraction: frac).opacity(0.9))
                }
                Spacer()
                Text("\(stats.total)")
                    .font(.custom("MontserratAlternates-Bold", size: 14))
                    .foregroundColor(PracticeStyle.cardLabelColor(isSelected: isOn, fraction: frac).opacity(0.88))
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? AnyShapeStyle(PracticeStyle.selectedFill) : AnyShapeStyle(PracticeStyle.progressBlueFill(fraction: frac)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isOn ? PracticeStyle.selectedBorder : PracticeStyle.restingBorder, lineWidth: isOn ? 3 : 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func selectAllButton(totalCount: Int, allValues: [String]) -> some View {
        if totalCount > 0 {
            Button {
                if selected.count == totalCount {
                    selected.removeAll()
                } else {
                    selected = Set(allValues)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selected.count == totalCount ? "xmark.circle" : "checkmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                    Text(selected.count == totalCount ? "Снять все" : "Выбрать все")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ExamixStyle.accentCool)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PracticeStyle.restingBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func load() {
        do {
            let v = try VariantCatalogService.shared.fetchAllLocalVariants(uiLanguage: uiLanguage)
            variants = v
            rows = PracticeLibrary.themeRows(from: v)
            loadError = rows.isEmpty ? "Нет тем в базе." : nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}


struct PracticeByThemeSessionView: View {
    @Binding var path: NavigationPath
    let themeTitles: [String]
    let uiLanguage: String

    @StateObject private var vm = TestViewModel()
    @State private var currentRef: PracticeQuestionRef?
    @State private var loadError: String?
    @State private var exhausted = false
    @State private var sessionAttempts = 0
    @State private var sessionCorrect = 0
    @State private var catalogVariants: [TestVariant] = []
    @State private var catalogProgressNonce = 0

    private var themeSet: Set<String> { Set(themeTitles) }

    private var titleLine: String {
        if themeTitles.count <= 1 { return themeTitles.first ?? "" }
        return "\(themeTitles.count) тем"
    }

    var body: some View {
        ZStack {
            ExamixStyle.practiceScreenWash.ignoresSafeArea()
            if exhausted {
                VStack(spacing: 20) {
                    Text("Все задания по выбранным темам решены")
                        .font(.custom("MontserratAlternates-Bold", size: 22))
                        .foregroundColor(.stock)
                        .multilineTextAlignment(.center)
                    Text(titleLine)
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundColor(.darkAccent)
                        .multilineTextAlignment(.center)
                    Text("Верных в сессии: \(sessionCorrect) из \(sessionAttempts)")
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundColor(.gray)
                    Button("К списку тем") {
                        path.removeLast()
                    }
                    .font(.custom("MontserratAlternates-Medium", size: 16))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.brown)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                }
                .padding()
            } else if let err = loadError {
                Text(err).foregroundColor(.red).padding()
            } else if let ref = currentRef, singleTest(for: ref) != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(titleLine)
                        .font(.custom("MontserratAlternates-Bold", size: 16))
                        .foregroundColor(.darkAccent)
                        .padding(.horizontal)
                        .lineLimit(2)
                    Text("Сессия: \(sessionCorrect) / \(sessionAttempts)")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    TestView(
                        viewModel: vm,
                        practiceMode: true,
                        practiceInlineFeedback: true,
                        practiceOnFinished: { handleContinue() },
                        practiceCatalogSolved: themeCatalogProgress?.solved,
                        practiceCatalogTotal: themeCatalogProgress?.total
                    )
                    .id("\(ref.stableKey)-\(catalogProgressNonce)")
                }
                .onChange(of: currentRef?.stableKey, initial: true) { _, _ in
                    guard let r = currentRef, let s = singleTest(for: r) else { return }
                    vm.setTest(
                        s,
                        persistToFirestore: true,
                        entrySource: "practice_theme",
                        practiceDetail: titleLine,
                        uiLearningLanguage: uiLanguage,
                        questionIndicesInVariant: [r.questionIndex]
                    )
                }
            } else {
                ProgressView("Подбор задания…")
            }
        }
        .navigationTitle("Практика")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pickNext()
        }
    }

    private var themeCatalogProgress: (solved: Int, total: Int)? {
        guard !catalogVariants.isEmpty else { return nil }
        let _ = catalogProgressNonce
        let agg = PracticeLibrary.themesAggregateProgress(themeTitles: themeSet, variants: catalogVariants, store: PracticeProgressStore.shared)
        return agg.total > 0 ? agg : nil
    }

    private func singleTest(for ref: PracticeQuestionRef) -> TestVariant? {
        guard let full = try? LocalTestDatabase.shared.fetch(language: ref.language, variant: ref.variant) else { return nil }
        return ref.singleQuestionVariant(from: full)
    }

    private func bucketForRef(_ ref: PracticeQuestionRef) -> String? {
        guard let full = try? LocalTestDatabase.shared.fetch(language: ref.language, variant: ref.variant),
              ref.questionIndex < full.questions.count else { return nil }
        let t = PracticeLibrary.themeDisplayTitle(for: full.questions[ref.questionIndex])
        return PracticeLibrary.bucketForTheme(displayTitle: t)
    }

    @MainActor
    private func pickNext() async {
        do {
            let variants = try VariantCatalogService.shared.fetchAllLocalVariants(uiLanguage: uiLanguage)
            catalogVariants = variants
            let store = PracticeProgressStore.shared
            let candidates = PracticeLibrary.refs(themeTitles: themeSet, from: variants, store: store)
            guard let next = candidates.randomElement() else {
                exhausted = true
                currentRef = nil
                return
            }
            currentRef = next
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func handleContinue() {
        if let r = vm.finishedResult {
            sessionAttempts += 1
            if r.correctAnswers == r.totalQuestions { sessionCorrect += 1 }
        }
        if let ref = currentRef, let b = bucketForRef(ref) {
            PracticeProgressStore.shared.markSolved(bucket: b, refKey: ref.stableKey)
        }
        catalogProgressNonce += 1
        vm.resetAfterPracticeRound()
        Task { await pickNext() }
    }
}
