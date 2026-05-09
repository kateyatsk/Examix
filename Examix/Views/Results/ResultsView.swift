//
//  ResultsView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI

/// Слияние: верх видимой области (глобальный Y) + геометрия блока фильтров (глобальный низ и minY в scroll space).
private struct ResultsFilterVisibilityPref: Equatable {
    var viewportTopGlobalY: CGFloat?
    var filtersBottomGlobalY: CGFloat?
    var filtersMinYInScroll: CGFloat?
}

private enum ResultsFilterVisibilityKey: PreferenceKey {
    static var defaultValue = ResultsFilterVisibilityPref()

    static func reduce(value: inout ResultsFilterVisibilityPref, nextValue: () -> ResultsFilterVisibilityPref) {
        let n = nextValue()
        if let t = n.viewportTopGlobalY { value.viewportTopGlobalY = t }
        if let b = n.filtersBottomGlobalY { value.filtersBottomGlobalY = b }
        if let m = n.filtersMinYInScroll { value.filtersMinYInScroll = m }
    }
}

// MARK: - Группировка практики по теме / типу (одна строка в списке, внутри — задания)

private struct PracticeResultsCluster: Identifiable {
    /// Стабильный ключ: источник + подпись сессии + язык + календарный день.
    let id: String
    /// От новых к старым.
    var members: [TestResult]
}

private enum ResultsDisplayRow: Identifiable {
    case single(TestResult)
    case cluster(PracticeResultsCluster)

    var id: String {
        switch self {
        case .single(let r): return r.id
        case .cluster(let c): return "cluster:\(c.id)"
        }
    }
}

struct ResultsView: View {
    @StateObject private var viewModel = ResultsViewModel()
    @State private var searchText = ""
    @State private var selectedLanguageFilter: String = "Все"
    @State private var sortMode: ResultsSortMode = .dateNewest
    @State private var datePeriod: ResultsDatePeriod = .all
    @State private var originFilter: ResultsOriginFilter = .all
    @State private var showJumpToFilters = false
    @State private var showCustomPeriodSheet = false
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var expandedPracticeClusterIDs: Set<String> = []

    private var filteredResults: [TestResult] {
        var results = viewModel.results

        results = results.filter { originFilter.includes($0) }

        if selectedLanguageFilter != "Все" {
            results = results.filter { $0.language == selectedLanguageFilter }
        }

        results = results.filter { isInSelectedPeriod($0) }

        if !searchText.isEmpty {
            let q = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                results = results.filter {
                    $0.language.lowercased().contains(q)
                        || String($0.variant).contains(q)
                        || ($0.practiceDetail?.lowercased().contains(q) ?? false)
                }
            }
        }

        switch sortMode {
        case .dateNewest:
            results.sort { $0.timestamp > $1.timestamp }
        case .dateOldest:
            results.sort { $0.timestamp < $1.timestamp }
        case .scoreBest:
            results.sort { score($0) > score($1) }
        case .scoreWorst:
            results.sort { score($0) < score($1) }
        }

        return results
    }

    /// Практика по теме/типу: несколько записей за один день с одной подписью сессии — одна строка с суммой и раскрытием.
    private var filteredDisplayRows: [ResultsDisplayRow] {
        let rows = buildPracticeDisplayRows(from: filteredResults)
        switch sortMode {
        case .dateNewest:
            return rows.sorted { displayRowSortDate($0) > displayRowSortDate($1) }
        case .dateOldest:
            return rows.sorted { displayRowSortDate($0) < displayRowSortDate($1) }
        case .scoreBest:
            return rows.sorted { displayRowScore($0) > displayRowScore($1) }
        case .scoreWorst:
            return rows.sorted { displayRowScore($0) < displayRowScore($1) }
        }
    }

    private func displayRowSortDate(_ row: ResultsDisplayRow) -> Date {
        switch row {
        case .single(let r): return r.timestamp
        case .cluster(let c): return c.members.first?.timestamp ?? .distantPast
        }
    }

    private func displayRowScore(_ row: ResultsDisplayRow) -> Double {
        switch row {
        case .single(let r): return score(r)
        case .cluster(let c):
            let t = c.members.reduce(0) { $0 + $1.totalQuestions }
            guard t > 0 else { return 0 }
            let corr = c.members.reduce(0) { $0 + $1.correctAnswers }
            return Double(corr) / Double(t)
        }
    }

    private func practiceDayKey(_ date: Date) -> String {
        let c = Calendar.current
        let d = c.startOfDay(for: date)
        let y = c.component(.year, from: d)
        let m = c.component(.month, from: d)
        let day = c.component(.day, from: d)
        return String(format: "%04d-%02d-%02d", y, m, day)
    }

    private func practiceClusterKey(_ r: TestResult) -> String? {
        guard r.entrySource == "practice_theme" || r.entrySource == "practice_type" else { return nil }
        let src = r.entrySource ?? ""
        let detail = r.practiceDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let day = practiceDayKey(r.timestamp)
        return "\(src)|\(detail)|\(r.language)|\(day)"
    }

    private func buildPracticeDisplayRows(from results: [TestResult]) -> [ResultsDisplayRow] {
        var buckets: [String: [TestResult]] = [:]
        var rest: [TestResult] = []
        for r in results {
            if let k = practiceClusterKey(r) {
                buckets[k, default: []].append(r)
            } else {
                rest.append(r)
            }
        }
        var out: [ResultsDisplayRow] = []
        for (key, group) in buckets {
            let sorted = group.sorted { $0.timestamp > $1.timestamp }
            if sorted.count >= 2 {
                out.append(.cluster(PracticeResultsCluster(id: key, members: sorted)))
            } else if let one = sorted.first {
                out.append(.single(one))
            }
        }
        out.append(contentsOf: rest.map { ResultsDisplayRow.single($0) })
        return out
    }

    private func score(_ r: TestResult) -> Double {
        guard r.totalQuestions > 0 else { return 0 }
        return Double(r.correctAnswers) / Double(r.totalQuestions)
    }

    private func isInSelectedPeriod(_ r: TestResult) -> Bool {
        let cal = Calendar.current
        let ts = r.timestamp
        let todayStart = cal.startOfDay(for: Date())

        switch datePeriod {
        case .all:
            return true
        case .days7:
            guard let from = cal.date(byAdding: .day, value: -7, to: todayStart) else { return true }
            return ts >= from
        case .days30:
            guard let from = cal.date(byAdding: .day, value: -30, to: todayStart) else { return true }
            return ts >= from
        case .days90:
            guard let from = cal.date(byAdding: .day, value: -90, to: todayStart) else { return true }
            return ts >= from
        case .custom:
            let start = cal.startOfDay(for: customStart)
            guard let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEnd)) else { return true }
            return ts >= start && ts < endExclusive
        }
    }

    private var allLanguages: [String] {
        let langs = Set(viewModel.results.map { $0.language })
        return ["Все"] + langs.sorted()
    }

    private var periodCaption: String {
        switch datePeriod {
        case .all: return "Всё время"
        case .days7: return "7 дней"
        case .days30: return "30 дней"
        case .days90: return "90 дней"
        case .custom: return "Свой период"
        }
    }

    private var sortCaption: String {
        sortMode.shortLabel
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ZStack(alignment: .topTrailing) {
                    ExamixStyle.practiceScreenWash
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            resultsFiltersSection
                                .id("resultsFiltersTop")
                                .padding(.horizontal, 20)
                                .padding(.top, 6)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: ResultsFilterVisibilityKey.self,
                                            value: ResultsFilterVisibilityPref(
                                                viewportTopGlobalY: nil,
                                                filtersBottomGlobalY: geo.frame(in: .global).maxY,
                                                filtersMinYInScroll: geo.frame(in: .named("resultsScroll")).minY
                                            )
                                        )
                                    }
                                )

                            if filteredResults.isEmpty {
                                emptyState
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 20)
                                    .padding(.bottom, 40)
                            } else {
                                LazyVStack(spacing: 14) {
                                    ForEach(filteredDisplayRows) { row in
                                        Group {
                                            switch row {
                                            case .single(let result):
                                                NavigationLink(destination: ResultDetailView(result: result)) {
                                                    resultRowCard(result)
                                                }
                                                .buttonStyle(.plain)
                                            case .cluster(let cluster):
                                                practiceClusterSection(cluster)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 32)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .coordinateSpace(name: "resultsScroll")
                    .scrollDismissesKeyboard(.interactively)

                    if showJumpToFilters {
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                scroll.scrollTo("resultsFiltersTop", anchor: .top)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white.opacity(0.95))
                                Text("К фильтрам")
                                    .font(.custom("MontserratAlternates-SemiBold", size: 13))
                                    .tracking(0.2)
                                    .foregroundStyle(.white)
                            }
                            .padding(.leading, 13)
                            .padding(.trailing, 15)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                ExamixStyle.accentCool,
                                                ExamixStyle.accentDeep.opacity(0.92)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.55),
                                                Color.white.opacity(0.12)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: ExamixStyle.accentCool.opacity(0.45), radius: 14, x: 0, y: 6)
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                        .padding(.trailing, 14)
                        .zIndex(50)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .accessibilityLabel("К фильтрам")
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ResultsFilterVisibilityKey.self,
                            value: ResultsFilterVisibilityPref(
                                viewportTopGlobalY: geo.frame(in: .global).minY,
                                filtersBottomGlobalY: nil,
                                filtersMinYInScroll: nil
                            )
                        )
                    }
                )
                .onPreferenceChange(ResultsFilterVisibilityKey.self) { pref in
                    var filtersScrolledAway = false
                    if let top = pref.viewportTopGlobalY, let bottom = pref.filtersBottomGlobalY {
                        filtersScrolledAway = filtersScrolledAway || (bottom < top + 4)
                    }
                    if let minScroll = pref.filtersMinYInScroll {
                        filtersScrolledAway = filtersScrolledAway || (minScroll < -6)
                    }
                    if filtersScrolledAway != showJumpToFilters {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showJumpToFilters = filtersScrolledAway
                        }
                    }
                }
                .navigationTitle("Результаты")
            .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showCustomPeriodSheet) {
                    customPeriodSheet
            }
            .onAppear {
                Task {
                    await viewModel.loadResults()
                }
            }
        }
    }
}

    private var customPeriodSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Учитываются записи с датой сохранения в выбранном диапазоне.")
                    .font(.custom("MontserratAlternates-Regular", size: 14))
                    .foregroundStyle(.secondary)

                DatePicker("С", selection: $customStart, displayedComponents: .date)
                    .font(.custom("MontserratAlternates-Medium", size: 16))
                DatePicker("По", selection: $customEnd, displayedComponents: .date)
                    .font(.custom("MontserratAlternates-Medium", size: 16))

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Свой период")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showCustomPeriodSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        datePeriod = .custom
                        showCustomPeriodSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// Фильтры: предмет, тип заданий, поиск; период и порядок — компактная строка из двух меню.
    private var resultsFiltersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: ExamixStyle.practiceThemesGradientColors.map { $0.opacity(0.38) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ExamixStyle.accentDeep)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Фильтры списка")
                        .font(.custom("MontserratAlternates-Bold", size: 16))
                        .foregroundStyle(Color(.darkAccent))
                    Text("Оставьте только варианты ЦТ или задания из практики")
                        .font(.custom("MontserratAlternates-Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("\(filteredResults.count)")
                    .font(.custom("MontserratAlternates-SemiBold", size: 13))
                    .foregroundStyle(ExamixStyle.accentCool)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ExamixStyle.accentMuted.opacity(0.2))
                    )
            }
            .padding(.bottom, 10)

            filterRowLabel("Предмет", systemImage: "book.closed.fill")
            Picker("Предмет", selection: $selectedLanguageFilter) {
                ForEach(allLanguages, id: \.self) { lang in
                    Text(lang == "Все" ? "Все предметы" : lang).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .tint(ExamixStyle.accentCool)
            .font(.custom("MontserratAlternates-Medium", size: 15))
            .foregroundStyle(Color(.darkAccent))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(filterFieldBackground())
            .padding(.bottom, 10)

            filterRowLabel("Тип заданий", systemImage: "square.stack.3d.up.fill")
            Picker("Тип заданий", selection: $originFilter) {
                ForEach(ResultsOriginFilter.allCases) { item in
                    Text(item.menuTitle).tag(item)
                }
            }
            .pickerStyle(.menu)
            .tint(ExamixStyle.accentCool)
            .font(.custom("MontserratAlternates-Medium", size: 15))
            .foregroundStyle(Color(.darkAccent))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(filterFieldBackground())
            .padding(.bottom, 10)

            filterRowLabel("Поиск", systemImage: "magnifyingglass")
            HStack(spacing: 10) {
                TextField("Язык, вариант или подпись практики", text: $searchText)
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .foregroundStyle(Color(.darkAccent))
                    .examixPlainTextFieldInput()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(filterFieldBackground())
            .padding(.bottom, 8)

            filterRowLabel("Период и порядок", systemImage: "calendar.badge.clock")
            HStack(spacing: 8) {
                Menu {
                    Button("Всё время") { datePeriod = .all }
                    Button("Последние 7 дней") { datePeriod = .days7 }
                    Button("Последние 30 дней") { datePeriod = .days30 }
                    Button("Последние 90 дней") { datePeriod = .days90 }
                    Button("Свой период…") {
                        showCustomPeriodSheet = true
                    }
                } label: {
                    compactMenuLabel(caption: "Период", value: periodCaption)
                }
                .menuStyle(.button)
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button("Дата · сначала новые") { sortMode = .dateNewest }
                    Button("Дата · сначала старые") { sortMode = .dateOldest }
                    Button("Точность · сначала лучшие") { sortMode = .scoreBest }
                    Button("Точность · сначала худшие") { sortMode = .scoreWorst }
                } label: {
                    compactMenuLabel(caption: "Порядок", value: sortCaption)
                }
                .menuStyle(.button)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(filterFieldBackground())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color(red: 0.93, green: 0.96, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: ExamixStyle.practiceTypesGradientColors.map { $0.opacity(0.28) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    private func compactMenuLabel(caption: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(caption.uppercased())
                    .font(.custom("MontserratAlternates-Bold", size: 9))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                    .foregroundStyle(Color(.darkAccent))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ExamixStyle.accentCool.opacity(0.8))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func filterRowLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ExamixStyle.accentCool.opacity(0.85))
            Text(title.uppercased())
                .font(.custom("MontserratAlternates-Bold", size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private func filterFieldBackground() -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ExamixStyle.accentCool.opacity(0.14), lineWidth: 1)
            )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: viewModel.results.isEmpty ? "chart.line.uptrend.xyaxis" : "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(ExamixStyle.accentCool.opacity(0.75))

            Text(viewModel.results.isEmpty ? "Пока нет сохранённых результатов" : "Ничего не найдено")
                .font(.custom("MontserratAlternates-Bold", size: 18))
                .foregroundColor(.darkAccent)
                .multilineTextAlignment(.center)

            Text(viewModel.results.isEmpty
                 ? "Завершите тест или практику — записи появятся здесь."
                 : "Смените период, предмет, тип заданий или поиск.")
                .font(.custom("MontserratAlternates-Regular", size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func practiceClusterSection(_ cluster: PracticeResultsCluster) -> some View {
        let expanded = expandedPracticeClusterIDs.contains(cluster.id)
        let first = cluster.members[0]
        let totalQuestions = cluster.members.reduce(0) { $0 + $1.totalQuestions }
        let totalCorrect = cluster.members.reduce(0) { $0 + $1.correctAnswers }
        let percent: Int? = totalQuestions > 0
            ? Int((Double(totalCorrect) / Double(totalQuestions)) * 100)
            : nil

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    if expanded {
                        expandedPracticeClusterIDs.remove(cluster.id)
                    } else {
                        expandedPracticeClusterIDs.insert(cluster.id)
                    }
                }
            } label: {
                practiceClusterHeaderCard(
                    first: first,
                    memberCount: cluster.members.count,
                    totalCorrect: totalCorrect,
                    totalQuestions: totalQuestions,
                    percent: percent,
                    expanded: expanded
                )
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(cluster.members) { member in
                        NavigationLink(destination: ResultDetailView(result: member)) {
                            practiceClusterMemberRow(member)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.96, green: 0.98, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: {
                            let stripeColors = ExamixStyle.resultStripeColors(
                                entrySource: first.entrySource,
                                uiLearningLanguage: first.uiLearningLanguage,
                                examVariantLanguage: first.language
                            )
                            let strokeColors = stripeColors.map { $0.opacity(0.34) }
                            return [strokeColors[0], strokeColors.count > 1 ? strokeColors[1] : strokeColors[0]]
                        }(),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func practiceClusterHeaderCard(
        first: TestResult,
        memberCount: Int,
        totalCorrect: Int,
        totalQuestions: Int,
        percent: Int?,
        expanded: Bool
    ) -> some View {
        let stripeColors = ExamixStyle.resultStripeColors(
            entrySource: first.entrySource,
            uiLearningLanguage: first.uiLearningLanguage,
            examVariantLanguage: first.language
        )
        return HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: stripeColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)
                .padding(.trailing, 12)

            HStack(alignment: .top, spacing: 14) {
                if let p = percent {
                    ExamixRadialScoreBadge(percent: p)
                } else {
                    ExamixSquircleIcon(systemName: "square.stack.fill", side: 52, iconPointSize: 18)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let kind = first.practiceKindTitle {
                                Text(kind)
                                    .font(.custom("MontserratAlternates-Bold", size: 15))
                                    .foregroundStyle(Color(.darkAccent))
                                if let detail = first.practiceDetail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                                    Text(detail)
                                        .font(.custom("MontserratAlternates-Medium", size: 13))
                                        .foregroundStyle(ExamixStyle.accentCool)
                                        .lineLimit(2)
                                }
                                Text("\(first.language) · \(memberCount) заданий за день")
                                    .font(.custom("MontserratAlternates-Regular", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: 8)

                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }

                    Text("Правильных: \(totalCorrect) из \(totalQuestions)")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundColor(.darkAccent.opacity(0.85))

                    if let p = percent {
                        ProgressView(value: Double(p), total: 100)
                            .progressViewStyle(.linear)
                            .tint(stripeColors.first ?? ExamixStyle.accentCool)
                            .scaleEffect(x: 1, y: 1.4, anchor: .center)
                            .padding(.top, 6)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
    }

    private func practiceClusterMemberRow(_ result: TestResult) -> some View {
        let p = result.totalQuestions > 0
            ? Int((Double(result.correctAnswers) / Double(result.totalQuestions)) * 100)
            : 0
        return HStack(alignment: .center, spacing: 12) {
            ExamixRadialScoreBadge(percent: p)
                .scaleEffect(0.85)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.timestamp.formatted(date: .numeric, time: .shortened))
                    .font(.custom("MontserratAlternates-Medium", size: 12))
                    .foregroundStyle(.secondary)
                Text("Верно \(result.correctAnswers) из \(result.totalQuestions) · вар. \(result.variant)")
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                    .foregroundStyle(Color(.darkAccent))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func resultRowCard(_ result: TestResult) -> some View {
        let percent: Int? = result.totalQuestions > 0
            ? Int((Double(result.correctAnswers) / Double(result.totalQuestions)) * 100)
            : nil
        let stripeColors = ExamixStyle.resultStripeColors(
            entrySource: result.entrySource,
            uiLearningLanguage: result.uiLearningLanguage,
            examVariantLanguage: result.language
        )
        let strokeColors = stripeColors.map { $0.opacity(0.34) }

        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: stripeColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)
                .padding(.trailing, 12)

            HStack(alignment: .top, spacing: 14) {
                if let p = percent {
                    ExamixRadialScoreBadge(percent: p)
                } else {
                    ExamixSquircleIcon(systemName: "doc.text", side: 52, iconPointSize: 18)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let kind = result.practiceKindTitle {
                                Text(kind)
                                    .font(.custom("MontserratAlternates-Bold", size: 15))
                                    .foregroundStyle(Color(.darkAccent))
                                if let detail = result.practiceDetail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                                    Text(detail)
                                        .font(.custom("MontserratAlternates-Medium", size: 13))
                                        .foregroundStyle(ExamixStyle.accentCool)
                                        .lineLimit(2)
                                }
                                Text("\(result.language) · вар. \(result.variant)")
                                    .font(.custom("MontserratAlternates-Regular", size: 12))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(result.language), вариант \(result.variant)")
                                    .font(.custom("MontserratAlternates-Bold", size: 16))
                                    .foregroundStyle(.darkAccent)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Spacer(minLength: 8)

                        Text(result.timestamp.formatted(date: .numeric, time: .shortened))
                            .font(.custom("MontserratAlternates-Regular", size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text("Правильных: \(result.correctAnswers) из \(result.totalQuestions)")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundColor(.darkAccent.opacity(0.85))

                    if let p = percent {
                        ProgressView(value: Double(p), total: 100)
                            .progressViewStyle(.linear)
                            .tint(stripeColors.first ?? ExamixStyle.accentCool)
                            .scaleEffect(x: 1, y: 1.4, anchor: .center)
                            .padding(.top, 6)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.96, green: 0.98, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [strokeColors[0], strokeColors.count > 1 ? strokeColors[1] : strokeColors[0]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

enum ResultsDatePeriod: String, CaseIterable, Hashable {
    case all
    case days7
    case days30
    case days90
    case custom
}

enum ResultsSortMode: String, CaseIterable, Hashable {
    case dateNewest
    case dateOldest
    case scoreBest
    case scoreWorst

    var shortLabel: String {
        switch self {
        case .dateNewest: return "Дата ↓"
        case .dateOldest: return "Дата ↑"
        case .scoreBest: return "% лучше"
        case .scoreWorst: return "% хуже"
        }
    }
}

enum ResultsOriginFilter: String, CaseIterable, Identifiable {
    case all
    case exams
    case practiceAny
    case practiceDaily
    case practiceTheme
    case practiceType

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .all: return "Все записи"
        case .exams: return "Варианты (экзамен)"
        case .practiceAny: return "Вся практика"
        case .practiceDaily: return "Задание дня"
        case .practiceTheme: return "Практика по теме"
        case .practiceType: return "Практика по типу"
        }
    }

    func includes(_ r: TestResult) -> Bool {
        switch self {
        case .all: return true
        case .exams: return r.isFullVariantResult
        case .practiceAny: return r.isPracticeEntry
        case .practiceDaily: return r.entrySource == "practice_daily"
        case .practiceTheme: return r.entrySource == "practice_theme"
        case .practiceType: return r.entrySource == "practice_type"
        }
    }
}

#Preview {
    ResultsView()
}
