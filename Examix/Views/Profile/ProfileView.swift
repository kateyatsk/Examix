//
//  ProfileView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    private struct SubjectAccuracyRow: Identifiable {
        var id: String { languageKey }
        let languageKey: String
        let percent: Int
        let sessions: Int
    }

    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var userSettings: UserSettings
    @State private var showingLogoutAlert = false
    @State private var avatarImage: Image? = nil
    @State private var results: [TestResult] = []
    @State private var isLoading = false

    private var userName: String {
        (try? authManager.getAuthenticatedUser().name) ?? "Пользователь"
    }

    private var userEmail: String {
        (try? authManager.getAuthenticatedUser().email) ?? "-"
    }

    private var selectedLanguageName: String {
        userSettings.selectedLanguage?.rawValue ?? "Не выбран"
    }

    private var heatmapResults: [TestResult] {
        let expectedLanguage = selectedLanguageName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + " язык"
        return results.filter {
            $0.language.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == expectedLanguage
        }
    }

    /// Средняя точность по всем полным вариантам за всё время (все предметы).
    private var lifetimeAverageAccuracyPercent: Int? {
        let full = results.filter { $0.isFullVariantResult }
        guard !full.isEmpty else { return nil }
        let sum = full.reduce(0.0) { acc, r in
            acc + Double(r.correctAnswers) / Double(max(r.totalQuestions, 1)) * 100.0
        }
        return Int((sum / Double(full.count)).rounded())
    }

    /// Средняя по каждому предмету (`language` из результата), только полные варианты.
    private var lifetimePerSubjectRows: [SubjectAccuracyRow] {
        let full = results.filter { $0.isFullVariantResult }
        let grouped = Dictionary(grouping: full, by: \.language)
        return grouped.map { key, rows in
            let sum = rows.reduce(0.0) { acc, r in
                acc + Double(r.correctAnswers) / Double(max(r.totalQuestions, 1)) * 100.0
            }
            let pct = Int((sum / Double(rows.count)).rounded())
            return SubjectAccuracyRow(languageKey: key, percent: pct, sessions: rows.count)
        }
        .sorted {
            Self.subjectDisplayTitle($0.languageKey).localizedCaseInsensitiveCompare(Self.subjectDisplayTitle($1.languageKey)) == .orderedAscending
        }
    }

    private static func subjectDisplayTitle(_ languageKey: String) -> String {
        let suffix = " язык"
        if languageKey.hasSuffix(suffix) {
            return String(languageKey.dropLast(suffix.count))
        }
        return languageKey
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ExamixStyle.practiceScreenWash
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 18) {
                        profileIdentityCard

                        if let avg = lifetimeAverageAccuracyPercent {
                            lifetimeAccuracySection(
                                percent: avg,
                                sessionsCount: results.filter { $0.isFullVariantResult }.count,
                                perSubject: lifetimePerSubjectRows
                            )
                        }

                        NavigationLink(destination: BookmarksView()) {
                            HStack(spacing: 14) {
                                ExamixSquircleIcon(systemName: "bookmark.fill", side: 44, iconPointSize: 17)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Закладки")
                                        .font(.custom("MontserratAlternates-Medium", size: 16))
                                        .foregroundStyle(Color(.darkAccent))
                                    Text("Сохранённые задания")
                                        .font(.custom("MontserratAlternates-Regular", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .examixDetailAnswerChrome()
                        }
                        .buttonStyle(.plain)

                        if isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(ExamixStyle.accentCool)
                                Text("Загрузка…")
                                    .font(.custom("MontserratAlternates-Medium", size: 15))
                                    .foregroundStyle(Color(.darkAccent))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(softCardBackground())
                        } else {
                            ContributionHeatmapView(results: heatmapResults, panelStyle: .standalone)
                        }

                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Выйти из аккаунта")
                                    .font(.custom("MontserratAlternates-Medium", size: 15))
                            }
                            .foregroundStyle(Color.secondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
            .alert("Подтверждение выхода", isPresented: $showingLogoutAlert) {
                Button("Выйти", role: .destructive) {
                    do {
                        try authManager.signOut()
                        userSettings.selectedLanguage = nil
                    } catch {
                        print("Ошибка при выходе: \(error.localizedDescription)")
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Вы уверены, что хотите выйти из аккаунта?")
            }
            .task {
                loadAvatar()
                await loadResults()
            }
        }
    }

    private func lifetimeAccuracySection(percent: Int, sessionsCount: Int, perSubject: [SubjectAccuracyRow]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Средняя точность")
                .font(.custom("MontserratAlternates-Bold", size: 16))
                .foregroundStyle(Color(.darkAccent))

            Text("Общий средний процент по всем полным вариантам; ниже — отдельно по каждому предмету.")
                .font(.custom("MontserratAlternates-Regular", size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                        .frame(width: 108, height: 108)
                    Circle()
                        .trim(from: 0, to: CGFloat(percent) / 100)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    ExamixStyle.accentDeep,
                                    ExamixStyle.accentCool,
                                    ExamixStyle.accentMuted,
                                    ExamixStyle.accentDeep
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 108, height: 108)
                    VStack(spacing: 2) {
                        Text("\(percent)%")
                            .font(.custom("MontserratAlternates-Bold", size: 26))
                            .foregroundStyle(Color(.darkAccent))
                        Text("в среднем")
                            .font(.custom("MontserratAlternates-Medium", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Вариантов в расчёте: \(sessionsCount)")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundStyle(Color(.darkAccent))
                    Text("Каждый сохранённый результат полного варианта даёт одну долю в общем среднем.")
                        .font(.custom("MontserratAlternates-Regular", size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !perSubject.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("По предметам")
                        .font(.custom("MontserratAlternates-SemiBold", size: 13))
                        .foregroundStyle(Color(.darkAccent).opacity(0.85))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(perSubject) { row in
                                SubjectAccuracyMiniRing(
                                    title: Self.subjectDisplayTitle(row.languageKey),
                                    percent: row.percent,
                                    sessionsCount: row.sessions
                                )
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softCardBackground())
    }

    private var profileIdentityCard: some View {
        HStack(alignment: .center, spacing: 16) {
            Group {
                if let image = avatarImage {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle()
                            .fill(ExamixStyle.squircleFill)
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(ExamixStyle.accentMuted.opacity(0.35), lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(userName)
                    .font(.custom("MontserratAlternates-Bold", size: 20))
                    .foregroundStyle(Color(.darkAccent))
                    .lineLimit(2)
                Text(userEmail)
                    .font(.custom("MontserratAlternates-Regular", size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(selectedLanguageName)
                    .font(.custom("MontserratAlternates-Medium", size: 12))
                    .foregroundStyle(Color(.darkAccent))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ExamixStyle.chipFill))
                    .overlay(
                        Capsule()
                            .stroke(ExamixStyle.accentMuted.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softCardBackground())
    }

    private func softCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white, ExamixStyle.softProfileCard],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                ExamixStyle.practiceThemesGradientColors[1].opacity(0.35),
                                ExamixStyle.practiceTypesGradientColors[0].opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func loadAvatar() {
        if let data = UserDefaults.standard.data(forKey: "localAvatar"),
           let uiImage = UIImage(data: data) {
            self.avatarImage = Image(uiImage: uiImage)
            return
        }
    }

    private func loadResults() async {
        do {
            isLoading = true
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let snapshot = try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("results")
                .order(by: "timestamp", descending: false)
                .getDocuments()

            let loaded = snapshot.documents.compactMap { doc in
                try? doc.data(as: TestResult.self)
            }

            await MainActor.run {
                self.results = loaded
                self.isLoading = false
            }
        } catch {
            print("❌ Ошибка загрузки результатов: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
}

/// Компактное кольцо средней точности по одному предмету (профиль).
private struct SubjectAccuracyMiniRing: View {
    let title: String
    let percent: Int
    let sessionsCount: Int

    private static func variantSessionsLabel(_ n: Int) -> String {
        let m10 = n % 10
        let m100 = n % 100
        if m100 >= 11 && m100 <= 14 { return "\(n) вариантов" }
        if m10 == 1 { return "\(n) вариант" }
        if m10 >= 2 && m10 <= 4 { return "\(n) варианта" }
        return "\(n) вариантов"
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [
                                ExamixStyle.accentDeep.opacity(0.9),
                                ExamixStyle.accentCool,
                                ExamixStyle.accentMuted
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                Text("\(percent)%")
                    .font(.custom("MontserratAlternates-Bold", size: 11))
                    .foregroundStyle(Color(.darkAccent))
            }

            Text(title)
                .font(.custom("MontserratAlternates-Medium", size: 10))
                .foregroundStyle(Color(.darkAccent))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(width: 78)

            Text(Self.variantSessionsLabel(sessionsCount))
                .font(.custom("MontserratAlternates-Regular", size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(width: 84)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(UserSettings())
    }
}
