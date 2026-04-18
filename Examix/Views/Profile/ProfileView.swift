
//
//  ProfileView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//


import SwiftUI
import FirebaseFirestore
import Charts

struct ProfileView: View {
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

    private var chartData: [ChartData] {
        let expectedLanguage = selectedLanguageName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + " язык"
        let filtered = results.filter {
            $0.language.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == expectedLanguage
        }
        return filtered.map {
            ChartData(date: $0.timestamp, percent: Double($0.correctAnswers) / Double($0.totalQuestions) * 100)
        }
    }

    private var xScale: ClosedRange<Date>? {
        guard let min = chartData.map(\ .date).min(),
              let max = chartData.map(\ .date).max() else { return nil }
        return min...max
    }

    private var yScale: ClosedRange<Double>? {
        guard let min = chartData.map(\ .percent).min(),
              let max = chartData.map(\ .percent).max() else { return nil }
        return min...max
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        if let image = avatarImage {
                            image
                                .resizable()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                        }

                        Text(userName)
                            .font(.custom("MontserratAlternates-Bold", size: 20))
                        Text(userEmail)
                            .foregroundColor(.gray)
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                        Text("Язык изучения: \(selectedLanguageName)")
                            .foregroundColor(.stock)
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    NavigationLink(destination: BookmarksView()) {
                        HStack {
                            Image(systemName: "bookmark")
                            Text("Мои закладки")
                        }
                        .font(.custom("MontserratAlternates-Medium", size: 16))
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    if isLoading {
                        ProgressView("Загрузка результатов...")
                            .padding()
                    } else if !chartData.isEmpty, let xScale, let yScale {
                        Text("Прогресс по тестам")
                            .font(.custom("MontserratAlternates-Bold", size: 18))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Chart(chartData) {
                            LineMark(
                                x: .value("Дата", $0.date),
                                y: .value("Процент", $0.percent)
                            )
                            .foregroundStyle(.stock)
                        }
                        .chartXAxisLabel("Дата")
                        .chartYAxisLabel("% правильных")
                        .chartXScale(domain: xScale)
                        .chartYScale(domain: yScale)
                        .frame(height: 220)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        Text("Нет результатов по выбранному языку")
                            .font(.custom("MontserratAlternates-Regular", size: 14))
                            .foregroundColor(.gray)
                    }

                    Spacer(minLength: 40)

                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                                .font(.custom("MontserratAlternates-Medium", size: 16))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.stock))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
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
                }
                .task {
                    loadAvatar()
                    await loadResults()
                }
                .padding()
            }
        }
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

struct ChartData: Identifiable {
    let id = UUID()
    let date: Date
    let percent: Double
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(UserSettings())
    }
}
