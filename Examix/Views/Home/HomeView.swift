//
//  HomeView.swift
//  Examix
//
//  Created by Kate Yatskevich on 10.04.25.
//

import Foundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var path = NavigationPath()

    @State private var dailyDone = false
    @State private var testsToday = 0
    @State private var totalTests = 0
    @State private var correctToday = 0
    @State private var questionsToday = 0
    @State private var practiceSolvedCount = 0
    @State private var practiceRefsTotal = 0
    @State private var weakThemes: [(title: String, solved: Int, total: Int)] = []
    @State private var progressChartResults: [TestResult] = []
    @State private var pendingTestSessions: [PendingTestSession] = []
    @State private var pendingDeleteSession: PendingTestSession?

    private var practiceLang: String {
        userSettings.selectedLanguage?.rawValue ?? ""
    }

    private var userName: String {
        do {
            let authData = try authManager.getAuthenticatedUser()
            return authData.name ?? "Пользователь"
        } catch {
            return "Пользователь"
        }
    }

    private var activityToday: Bool {
        dailyDone || testsToday > 0
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ExamixStyle.practiceScreenWash
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 22) {
                            headerWelcome

                            HomePracticeModesRow(
                                practiceLang: practiceLang,
                                onThemes: { path.append(Path.practiceThemes) },
                                onTypes: { path.append(Path.practiceTypes) }
                            )

                            HomeTestPromoBlock(
                                activityToday: activityToday,
                                onSolveTest: { path.append(Path.languageDetail) }
                            )

                            if !pendingTestSessions.isEmpty {
                                HomePendingTestsBlock(
                                    sessions: pendingTestSessions,
                                    onContinue: { session in
                                        userSettings.selectedVariant = session.variant
                                        path.append(Path.testView)
                                    },
                                    onRequestDeleteDraft: { session in
                                        pendingDeleteSession = session
                                    }
                                )
                            }

                            HomeDailyMissionBlock(
                                practiceLang: practiceLang,
                                dailyDone: dailyDone,
                                onOpenDaily: { path.append(Path.practiceDaily) }
                            )

                            HomeStatsBlock(
                                practiceSolved: practiceSolvedCount,
                                practiceTotal: practiceRefsTotal,
                                totalTests: totalTests,
                                testsToday: testsToday,
                                correctToday: correctToday,
                                questionsToday: questionsToday,
                                weakThemes: weakThemes,
                                onPracticeWeakTheme: { title in
                                    path.append(Path.practiceThemeSession([title]))
                                }
                            )

                            homeProgressChartSection
                        }
                        .frame(width: max(0, geo.size.width - 40), alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                    }
                }
                .clipped()
                .onAppear {
                    loadDashboard()
                }

                if let target = pendingDeleteSession {
                    ExamixModalChoiceOverlay(
                        title: "Удалить черновик?",
                        message: "Прогресс по «\(target.displayTitleLine)» будет удалён без восстановления.",
                        actions: [
                            ExamixModalChoiceAction(id: "cancel", title: "Отмена", role: .cancel) {
                                pendingDeleteSession = nil
                            },
                            ExamixModalChoiceAction(id: "delete", title: "Удалить", role: .destructive) {
                                PendingTestSessionStore.remove(id: target.id)
                                pendingDeleteSession = nil
                                loadDashboard()
                            }
                        ]
                    )
                    .allowsHitTesting(true)
                }
            }
            .onChange(of: path.count) { _, new in
                if new == 0 {
                    loadDashboard()
                }
            }
            .onChange(of: userSettings.selectedLanguage) { _, _ in
                path = NavigationPath()
                loadDashboard()
            }
            .navigationDestination(for: Path.self) { route in
                switch route {
                case .languageDetail:
                    LanguageDetailView(path: $path, language: userSettings.selectedLanguage?.rawValue ?? "")
                case .testView:
                    if let language = userSettings.selectedLanguage?.rawValue {
                        if let variant = userSettings.selectedVariant {
                            TestViewLoader(language: language, variant: variant)
                        } else {
                            TestViewLoader(language: language)
                        }
                    } else {
                        Text("Язык не выбран")
                    }
                case .chooseVariant: ChooseVariantView(language: userSettings.selectedLanguage?.rawValue ?? "", path: $path)
                case .practiceDaily:
                    PracticeDailyView(uiLanguage: userSettings.selectedLanguage?.rawValue ?? "")
                case .practiceTypes:
                    PracticeTypePickerView(path: $path, uiLanguage: userSettings.selectedLanguage?.rawValue ?? "")
                case .practiceTypeSession(let typeCodes):
                    PracticeByTypeSessionView(path: $path, typeCodes: typeCodes, uiLanguage: userSettings.selectedLanguage?.rawValue ?? "")
                case .practiceThemes:
                    PracticeThemeListView(path: $path, uiLanguage: userSettings.selectedLanguage?.rawValue ?? "")
                case .practiceThemeSession(let themeTitles):
                    PracticeByThemeSessionView(path: $path, themeTitles: themeTitles, uiLanguage: userSettings.selectedLanguage?.rawValue ?? "")
                case .modeSelection, .forChoice, .test, .result:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var homeProgressChartSection: some View {
        let pack = TestProgressChartBuilder.points(from: progressChartResults, uiLanguageRaw: practiceLang)
        if practiceLang.isEmpty {
            EmptyView()
        } else if pack.data.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Прогресс по тестам")
                    .font(.custom("MontserratAlternates-Bold", size: 17))
                    .foregroundStyle(Color(.darkAccent))
                Text("После сохранённых результатов по выбранному языку здесь появится график точности по датам.")
                    .font(.custom("MontserratAlternates-Regular", size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ExamixStyle.accentCool.opacity(0.18), lineWidth: 1)
            )
        } else if let domain = pack.xDomain {
            HomeTestProgressChartCard(chartData: pack.data, xScale: domain)
        } else {
            EmptyView()
        }
    }

    private var headerWelcome: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Привет,")
                    .font(.custom("MontserratAlternates-Regular", size: 14))
                    .foregroundStyle(.secondary)
                Text(userName)
                    .font(.custom("MontserratAlternates-Bold", size: 26))
                    .foregroundStyle(Color(.darkAccent))
            }
            Spacer()
            if let languageFlag = userSettings.selectedLanguage?.flagName {
                Image(languageFlag)
                    .resizable()
                    .frame(width: 40, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    private func loadDashboard() {
        guard !practiceLang.isEmpty else {
            dailyDone = false
            testsToday = 0
            totalTests = 0
            correctToday = 0
            questionsToday = 0
            practiceSolvedCount = 0
            practiceRefsTotal = 0
            weakThemes = []
            progressChartResults = []
            pendingTestSessions = []
            return
        }

        Task {
            let lk = VariantCatalogService.shared.firestoreLanguageKey(from: practiceLang)
            let dk = PracticeLibrary.calendarDayKey()
            let bucket = PracticeLibrary.dailyProgressBucket(dayKey: dk, languageKey: lk)
            let store = PracticeProgressStore.shared

            var dd = false
            var pp = 0
            var pt = 0
            var wt: [(String, Int, Int)] = []

            if let variants = try? VariantCatalogService.shared.fetchAllLocalVariants(uiLanguage: practiceLang) {
                let refs = PracticeLibrary.allRefs(from: variants)
                pt = refs.count
                if let ref = PracticeLibrary.dailyRef(forDayKey: dk, languageKey: lk, refs: refs) {
                    dd = store.solvedKeys(for: bucket).contains(ref.stableKey)
                }
                for ref in refs {
                    guard let v = variants.first(where: { $0.language == ref.language && $0.variant == ref.variant }),
                          ref.questionIndex < v.questions.count else { continue }
                    let qid = v.questions[ref.questionIndex].id
                    let b = PracticeLibrary.bucketForTypeCode(qid)
                    if store.solvedKeys(for: b).contains(ref.stableKey) {
                        pp += 1
                    }
                }
                var scores: [(String, Int, Int)] = []
                for (title, _) in PracticeLibrary.themeRows(from: variants) {
                    let (s, t) = PracticeLibrary.themeProgress(themeDisplayTitle: title, variants: variants, store: store)
                    guard t >= 2 else { continue }
                    scores.append((title, s, t))
                }
                scores.sort { a, b in
                    let ra = Double(a.1) / Double(a.2)
                    let rb = Double(b.1) / Double(b.2)
                    return ra < rb
                }
                wt = Array(scores.prefix(3).map { ($0.0, $0.1, $0.2) })
            }

            var tt = 0
            var td = 0
            var ct = 0
            var qt = 0
            var chartRes: [TestResult] = []
            if let uid = try? AuthenticationManager.shared.getAuthenticatedUser().uid,
               let res = try? await FirestoreService().fetchResults(for: uid) {
                chartRes = res
                tt = res.count
                let start = Calendar.current.startOfDay(for: Date())
                let todayResults = res.filter { $0.timestamp >= start }
                td = todayResults.count
                ct = todayResults.reduce(0) { $0 + $1.correctAnswers }
                qt = todayResults.reduce(0) { $0 + $1.totalQuestions }
            }

            let pending = PendingTestSessionStore.sessions(uiLearningLanguage: practiceLang)

            await MainActor.run {
                dailyDone = dd
                testsToday = td
                totalTests = tt
                correctToday = ct
                questionsToday = qt
                practiceSolvedCount = pp
                practiceRefsTotal = pt
                weakThemes = wt
                progressChartResults = chartRes
                pendingTestSessions = pending
            }
        }
    }
}


private struct HomePendingTestsBlock: View {
    let sessions: [PendingTestSession]
    let onContinue: (PendingTestSession) -> Void
    let onRequestDeleteDraft: (PendingTestSession) -> Void

    private static let rowFont = Font.custom("MontserratAlternates-Medium", size: 14)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Продолжить")
                .font(.custom("MontserratAlternates-Bold", size: 17))
                .foregroundStyle(Color(.darkAccent))

            Text("Сохранённый прогресс по вариантам. Нажмите, чтобы вернуться к вопросу.")
                .font(Self.rowFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(sessions) { session in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.examLanguage)
                                .font(Self.rowFont)
                                .foregroundStyle(ExamixStyle.accentCool)
                            Text(session.displayTitleLine)
                                .font(Self.rowFont)
                                .foregroundStyle(Color(.darkAccent))
                                .lineLimit(2)
                            Text("Вопрос \(min(session.currentIndex + 1, max(1, session.totalQuestions))) из \(session.totalQuestions)")
                                .font(Self.rowFont)
                                .foregroundStyle(.secondary)
                            Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(Self.rowFont)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 8) {
                            Button {
                                onContinue(session)
                            } label: {
                                Text("Продолжить")
                                    .font(Self.rowFont)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(ExamixStyle.accentCool)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                onRequestDeleteDraft(session)
                            } label: {
                                Text("Удалить")
                                    .font(Self.rowFont)
                                    .foregroundStyle(Color(red: 0.75, green: 0.2, blue: 0.22))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.95))
                            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(ExamixStyle.accentCool.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), Color(red: 0.93, green: 0.96, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ExamixStyle.accentCool.opacity(0.22), lineWidth: 1)
        )
    }
}


private struct HomeMidnightCountdown: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let sec = Self.secondsUntilEndOfCalendarDay(from: context.date)
            Text(Self.formatHMS(sec))
                .font(.custom("MontserratAlternates-Bold", size: 28))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity, alignment: .leading)
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


private struct HomeDailyMissionBlock: View {
    let practiceLang: String
    let dailyDone: Bool
    let onOpenDaily: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: dailyDone ? "checkmark.seal.fill" : "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.95))
                Text("Задание дня")
                    .font(.custom("MontserratAlternates-Bold", size: 20))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
            }

            if practiceLang.isEmpty {
                Text("Выберите язык в настройках — и появится ежедневное задание.")
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                    .foregroundStyle(.white.opacity(0.75))
            } else if dailyDone {
                Text("Ты молодец! Сегодняшнее задание уже решено.")
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Новое задание появится после полуночи.")
                    .font(.custom("MontserratAlternates-Regular", size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                Text("Успей сегодня: одно задание, после полуночи — другое.")
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .foregroundStyle(.white.opacity(0.92))
                Text("До конца дня осталось")
                    .font(.custom("MontserratAlternates-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }

            if !practiceLang.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(practiceLang.isEmpty ? "" : (dailyDone ? "До нового задания" : "Осталось времени"))
                        .font(.custom("MontserratAlternates-Medium", size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                    HomeMidnightCountdown()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            }

            if !practiceLang.isEmpty {
                Button(action: onOpenDaily) {
                    Text(dailyDone ? "Посмотреть задание" : "Перейти к заданию")
                        .font(.custom("MontserratAlternates-Bold", size: 16))
                        .foregroundStyle(ExamixStyle.accentDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: practiceLang.isEmpty
                            ? [Color.gray.opacity(0.45), Color.gray.opacity(0.35)]
                            : (dailyDone
                                ? [Color(red: 0.18, green: 0.48, blue: 0.42), Color(red: 0.23, green: 0.38, blue: 0.50)]
                                : [Color(red: 0.18, green: 0.32, blue: 0.48), Color(red: 0.35, green: 0.58, blue: 0.62)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
}


private struct HomeTestPromoBlock: View {
    let activityToday: Bool
    let onSolveTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                DailyPracticeIllustration()
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 8) {
                    Text(activityToday ? "Так держи!" : "Ты ещё не занимался?")
                        .font(.custom("MontserratAlternates-Bold", size: 20))
                        .foregroundStyle(Color(.darkAccent))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        activityToday
                        ? "Сегодня уже есть прогресс — продолжай в том же духе."
                        : "Ежедневная практика и тесты приближают цель."
                    )
                    .font(.custom("MontserratAlternates-Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }

            Button(action: onSolveTest) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Решить тест")
                        .font(.custom("MontserratAlternates-Bold", size: 16))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.18, green: 0.34, blue: 0.50),
                                    Color(red: 0.34, green: 0.56, blue: 0.61)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color(red: 0.34, green: 0.56, blue: 0.61).opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ExamixStyle.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [ExamixStyle.accentMuted.opacity(0.35), Color.black.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}

private struct DailyPracticeIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.96, blue: 1.0),
                            Color(red: 0.84, green: 0.91, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ExamixStyle.accentMuted.opacity(0.32), lineWidth: 1)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .frame(width: 66, height: 72)
                .shadow(color: Color.black.opacity(0.08), radius: 7, x: 0, y: 4)
                .rotationEffect(.degrees(-5))
                .offset(x: -4, y: 0)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(index == 0 ? ExamixStyle.statCorrect : ExamixStyle.accentMuted.opacity(0.45))
                            .frame(width: 7, height: 7)
                        Capsule()
                            .fill(ExamixStyle.accentCool.opacity(index == 0 ? 0.45 : 0.18))
                            .frame(width: index == 1 ? 34 : 42, height: 5)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 16)
            .frame(width: 66, height: 72, alignment: .topLeading)
            .rotationEffect(.degrees(-5))
            .offset(x: -4, y: 0)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.52, blue: 0.46),
                                Color(red: 0.34, green: 0.64, blue: 0.60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)

                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(x: 24, y: 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}


private struct HomeStatsBlock: View {
    let practiceSolved: Int
    let practiceTotal: Int
    let totalTests: Int
    let testsToday: Int
    let correctToday: Int
    let questionsToday: Int
    let weakThemes: [(title: String, solved: Int, total: Int)]
    let onPracticeWeakTheme: (String) -> Void

    private var todayAccuracyText: String {
        guard questionsToday > 0 else { return "—" }
        return "\(Int((Double(correctToday) / Double(questionsToday)) * 100))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Сегодня в обучении")
                .font(.custom("MontserratAlternates-Bold", size: 17))
                .foregroundStyle(Color(.darkAccent))

            HStack(spacing: 0) {
                statPill(title: "Сегодня тестов", value: "\(testsToday)", icon: "calendar")
                Divider().frame(height: 36)
                statPill(title: "Всего тестов", value: "\(totalTests)", icon: "star.fill")
                Divider().frame(height: 36)
                statPill(title: "Точность сегодня", value: todayAccuracyText, icon: "target")
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(ExamixStyle.actionAqua.opacity(0.16))
                                .frame(width: 30, height: 30)
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ExamixStyle.actionBlue)
                        }
                        Text("На что обратить внимание")
                            .font(.custom("MontserratAlternates-Bold", size: 14))
                            .foregroundStyle(Color(.darkAccent))
                    }
                    Spacer()
                    Text("по твоей практике")
                        .font(.custom("MontserratAlternates-Regular", size: 11))
                        .foregroundStyle(ExamixStyle.accentCool.opacity(0.72))
                }

                if weakThemes.isEmpty {
                    Text("Пока мало данных: решай задания по темам или типам, и здесь появятся точные подсказки.")
                        .font(.custom("MontserratAlternates-Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.62))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(ExamixStyle.accentMuted.opacity(0.18), lineWidth: 1)
                        )
                } else {
                    ForEach(weakThemes.indices, id: \.self) { i in
                        Button {
                            onPracticeWeakTheme(weakThemes[i].title)
                        } label: {
                            weakThemeRow(
                                index: i,
                                title: weakThemes[i].title,
                                solved: weakThemes[i].solved,
                                total: weakThemes[i].total
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                Color(red: 0.88, green: 0.94, blue: 1.0).opacity(0.58)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ExamixStyle.actionAqua.opacity(0.16), lineWidth: 1)
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            Color(red: 0.91, green: 0.96, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ExamixStyle.accentMuted.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func statPill(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ExamixStyle.accentCool)
            Text(value)
                .font(.custom("MontserratAlternates-Bold", size: 16))
                .foregroundStyle(Color(.darkAccent))
            Text(title)
                .font(.custom("MontserratAlternates-Regular", size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func weakThemeRow(index: Int, title: String, solved: Int, total: Int) -> some View {
        let ratio = total > 0 ? Double(solved) / Double(total) : 0
        let tint = weakThemeTint(index: index)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(index + 1)")
                    .font(.custom("MontserratAlternates-Bold", size: 12))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(tint)
                    )
                Text(title)
                    .font(.custom("MontserratAlternates-Medium", size: 13))
                    .foregroundStyle(Color(.darkAccent))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text("\(solved)/\(total)")
                    .font(.custom("MontserratAlternates-Medium", size: 12))
                    .foregroundStyle(tint)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.8))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint.opacity(0.36)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(ratio)))
                }
            }
            .frame(height: 7)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func weakThemeTint(index: Int) -> Color {
        switch index % 3 {
        case 0: return ExamixStyle.actionBlue
        case 1: return Color(red: 0.12, green: 0.56, blue: 0.58)
        default: return Color(red: 0.46, green: 0.48, blue: 0.78)
        }
    }
}


private struct HomePracticeModesRow: View {
    let practiceLang: String
    let onThemes: () -> Void
    let onTypes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Практика")
                .font(.custom("MontserratAlternates-Bold", size: 17))
                .foregroundStyle(Color(.darkAccent))

            HStack(alignment: .top, spacing: 12) {
                practiceTile(
                    title: "По темам",
                    subtitle: "Выбери тему и количество заданий",
                    icon: "books.vertical.fill",
                    gradient: ExamixStyle.practiceThemesGradientColors,
                    action: onThemes
                )
                practiceTile(
                    title: "По типу",
                    subtitle: "A1, B1 и другие коды заданий",
                    icon: "square.grid.3x3.fill",
                    gradient: ExamixStyle.practiceTypesGradientColors,
                    action: onTypes
                )
            }
        }
        .padding(.top, 4)
    }

    private func practiceTile(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.95))
                Text(title)
                    .font(.custom("MontserratAlternates-Bold", size: 17))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.custom("MontserratAlternates-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack {
                    Text("Открыть")
                        .font(.custom("MontserratAlternates-Bold", size: 13))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.95))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(practiceLang.isEmpty)
        .opacity(practiceLang.isEmpty ? 0.45 : 1)
    }
}

extension HomeView {
    enum Path: Hashable {
        case modeSelection
        case forChoice
        case test
        case result
        case languageDetail
        case testView
        case chooseVariant
        case practiceDaily
        case practiceTypes
        case practiceTypeSession([String])
        case practiceThemes
        case practiceThemeSession([String])
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(UserSettings())
            .environmentObject(AuthenticationManager.shared)
    }
}
