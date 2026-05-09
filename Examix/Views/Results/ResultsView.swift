//
//  ResultsView.swift
//  Examix
//
//  Created by Kate Yatskevich on 17.04.25.
//

import SwiftUI

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


private struct PracticeResultsCluster: Identifiable {
    let id: String
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

private enum LeaderboardDisplayRow: Identifiable {
    case user(LeaderboardUserResult)
    case separator

    var id: String {
        switch self {
        case .user(let row): return row.id
        case .separator: return "leaderboard-separator"
        }
    }
}

private enum ResultsScreenMode: String, CaseIterable, Identifiable {
    case mine
    case leaderboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mine: return "Результаты"
        case .leaderboard: return "Топ пользователей"
        }
    }
}

struct ResultsView: View {
    @StateObject private var viewModel = ResultsViewModel()
    @State private var selectedMode: ResultsScreenMode = .mine
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

    private var displayedLeaderboardRows: [LeaderboardDisplayRow] {
        let topTen = viewModel.leaderboard.prefix(10).map { LeaderboardDisplayRow.user($0) }
        guard let currentUserRow = viewModel.leaderboard.first(where: \.isCurrentUser),
              currentUserRow.rank > 10 else {
            return topTen
        }

        if currentUserRow.rank == 11 {
            return topTen + [.user(currentUserRow)]
        }

        return topTen + [.separator, .user(currentUserRow)]
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ZStack(alignment: .topTrailing) {
                    ExamixStyle.practiceScreenWash
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            resultsHeaderSection
                                .padding(.horizontal, 20)

                            if selectedMode == .mine {
                                resultsFiltersSection
                                    .id("resultsFiltersTop")
                                    .padding(.horizontal, 20)
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
                            } else {
                                leaderboardSection
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 32)
                            }
                        }
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .coordinateSpace(name: "resultsScroll")
                    .scrollDismissesKeyboard(.interactively)

                    if showJumpToFilters && selectedMode == .mine {
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
                                    .font(.custom("MontserratAlternates-Bold", size: 13))
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
                    if selectedMode != .mine {
                        filtersScrolledAway = false
                    }
                    if filtersScrolledAway != showJumpToFilters {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showJumpToFilters = filtersScrolledAway
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ExamixToolbarTitle(text: "Результаты")
                    }
                }
                .sheet(isPresented: $showCustomPeriodSheet) {
                    customPeriodSheet
            }
            .onAppear {
                Task {
                    await viewModel.loadResults()
                    await viewModel.loadMonthlyLeaderboard()
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

    private var resultsHeaderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ResultsModeSegmentedControl(selection: $selectedMode)
        }
    }

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ExamixSquircleIcon(systemName: "trophy.fill", side: 44, iconPointSize: 17)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Рейтинг за месяц")
                            .font(.custom("MontserratAlternates-Bold", size: 17))
                            .foregroundStyle(Color(.darkAccent))
                        Text("Место считается по точности с начала текущего месяца")
                            .font(.custom("MontserratAlternates-Regular", size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                    .overlay(ExamixStyle.accentCool.opacity(0.18))

                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ExamixStyle.accentCool)
                    Text("Период обновляется каждый день")
                        .font(.custom("MontserratAlternates-Medium", size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    LeaderboardMidnightCountdown()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ExamixStyle.accentCool.opacity(0.18), lineWidth: 1)
            )

            if viewModel.leaderboard.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(ExamixStyle.accentCool.opacity(0.72))
                    Text("Топ за месяц ещё пуст")
                        .font(.custom("MontserratAlternates-Bold", size: 18))
                        .foregroundStyle(Color(.darkAccent))
                    Text("Когда пользователи сохранят результаты в текущем месяце, здесь появятся места в рейтинге.")
                        .font(.custom("MontserratAlternates-Regular", size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(displayedLeaderboardRows) { row in
                        switch row {
                        case .user(let userRow):
                            leaderboardRow(userRow)
                        case .separator:
                            leaderboardSeparator
                        }
                    }
                }
            }
        }
    }

    private var leaderboardSeparator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(ExamixStyle.accentCool.opacity(0.42))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .accessibilityLabel("Пропущенные места рейтинга")
    }

    private func leaderboardRow(_ row: LeaderboardUserResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(row.isCurrentUser ? ExamixStyle.squircleFill : ExamixStyle.chipFill)
                    .frame(width: 46, height: 46)
                Text("\(row.rank)")
                    .font(.custom("MontserratAlternates-Bold", size: 17))
                    .foregroundStyle(row.isCurrentUser ? .white : ExamixStyle.accentDeep)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(row.displayName)
                    .font(.custom("MontserratAlternates-Bold", size: 15))
                    .foregroundStyle(Color(.darkAccent))
                Text("\(row.correctAnswers) из \(row.totalQuestions) · \(row.attempts) записей")
                    .font(.custom("MontserratAlternates-Regular", size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(row.accuracy)%")
                .font(.custom("MontserratAlternates-Bold", size: 20))
                .foregroundStyle(row.isCurrentUser ? ExamixStyle.statCorrect : ExamixStyle.accentCool)
                .monospacedDigit()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(row.isCurrentUser ? Color.white : Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(row.isCurrentUser ? 0.08 : 0.05), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(row.isCurrentUser ? ExamixStyle.statCorrect.opacity(0.32) : ExamixStyle.accentCool.opacity(0.16), lineWidth: 1)
        )
    }

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
                    .font(.custom("MontserratAlternates-Bold", size: 13))
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
            Menu {
                ForEach(allLanguages, id: \.self) { lang in
                    Button(lang == "Все" ? "Все предметы" : lang) {
                        selectedLanguageFilter = lang
                    }
                }
            } label: {
                filterSelectionLabel(value: selectedLanguageFilter == "Все" ? "Все предметы" : selectedLanguageFilter)
            }
            .tint(ExamixStyle.accentCool)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(filterFieldBackground())
            .padding(.bottom, 10)

            filterRowLabel("Тип заданий", systemImage: "square.stack.3d.up.fill")
            Menu {
                ForEach(ResultsOriginFilter.allCases) { item in
                    Button(item.menuTitle) {
                        originFilter = item
                    }
                }
            } label: {
                filterSelectionLabel(value: originFilter.menuTitle)
            }
            .tint(ExamixStyle.accentCool)
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

    private func filterSelectionLabel(value: String) -> some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.custom("MontserratAlternates-Medium", size: 15))
                .foregroundStyle(Color(.darkAccent))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ExamixStyle.accentCool.opacity(0.8))
        }
        .contentShape(Rectangle())
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

private struct ResultsModeSegmentedControl: View {
    @Binding var selection: ResultsScreenMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ResultsScreenMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selection = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.custom("MontserratAlternates-Bold", size: 14))
                        .foregroundStyle(selection == mode ? .white : ExamixStyle.accentDeep.opacity(0.76))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selection == mode ? ExamixStyle.squircleFill : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ExamixStyle.accentCool.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct LeaderboardMidnightCountdown: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = Self.secondsUntilEndOfCalendarDay(from: context.date)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Self.formatHMS(seconds))
                    .font(.custom("MontserratAlternates-Bold", size: 13))
                    .foregroundStyle(ExamixStyle.accentCool)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
        }
    }

    private static func secondsUntilEndOfCalendarDay(from date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let next = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return max(0, Int(next.timeIntervalSince(date)))
    }

    private static func formatHMS(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
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
