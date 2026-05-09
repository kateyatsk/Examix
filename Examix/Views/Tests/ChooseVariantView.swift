//
//  ChooseVariantView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 25.04.25.
//

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

private struct VariantListItem: Identifiable, Hashable {
    let id: Int
    let variant: Int
    let sourceTitle: String?
    /// Год из подписи (для сортировки); 0 — если не удалось извлечь.
    let sortYear: Int
}

private enum VariantTitleParsing {
    /// Первый год вида 19xx/20xx в строке.
    static func year(from sourceTitle: String?) -> Int {
        let s = sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !s.isEmpty,
              let range = s.range(of: #"\b(?:19|20)\d{2}\b"#, options: .regularExpression) else { return 0 }
        return Int(s[range]) ?? 0
    }
}

struct ChooseVariantView: View {
    var language: String
    @Binding var path: NavigationPath
    @EnvironmentObject var userSettings: UserSettings

    @State private var variantRows: [VariantListItem] = []
    @State private var completedVariants: Set<Int> = []
    @State private var variantScores: [Int: Int] = [:]
    @State private var isLoading = true

    var body: some View {
        ZStack {
            ExamixStyle.practiceScreenWash
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Загрузка…")
                    .tint(ExamixStyle.accentCool)
                    .font(.custom("MontserratAlternates-Medium", size: 15))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Выбор варианта")
                                .font(.custom("MontserratAlternates-SemiBold", size: 12))
                                .foregroundStyle(ExamixStyle.accentCool)
                                .textCase(.uppercase)
                                .tracking(0.9)

                            Text("Какой вариант хотите решить?")
                                .font(.custom("MontserratAlternates-Bold", size: 24))
                                .foregroundStyle(Color(.darkAccent))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(language)
                                .font(.custom("MontserratAlternates-Medium", size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        LazyVStack(spacing: 12) {
                            ForEach(variantRows) { item in
                                VariantChoiceCell(
                                    variant: item.variant,
                                    sourceTitle: item.sourceTitle,
                                    sortYear: item.sortYear,
                                    isCompleted: completedVariants.contains(item.variant),
                                    score: variantScores[item.variant]
                                ) {
                                    userSettings.selectedVariant = item.variant
                                    path.append(HomeView.Path.testView)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear(perform: loadVariants)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    path.removeLast()
                } label: {
                    HStack(spacing: 6) {
                        Text("‹")
                            .font(.custom("MontserratAlternates-Bold", size: 20))
                        Text("Назад")
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                    }
                    .foregroundStyle(ExamixStyle.accentCool)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadVariants() {
        Task {
            do {
                let firestoreLanguage = language + " язык"
                let rows: [VariantListItem]
                let localAll = try VariantCatalogService.shared.fetchAllLocalVariants(uiLanguage: language)
                if !localAll.isEmpty {
                    rows = localAll.map { v in
                        let y = VariantTitleParsing.year(from: v.sourceTitle)
                        return VariantListItem(id: v.variant, variant: v.variant, sourceTitle: v.sourceTitle, sortYear: y)
                    }
                    .sorted { a, b in
                        if a.sortYear != b.sortYear { return a.sortYear > b.sortYear }
                        return a.variant < b.variant
                    }
                } else {
                    let nums = try await VariantCatalogService.shared.listVariantNumbers(uiLanguage: language)
                    rows = nums
                        .sorted()
                        .map { VariantListItem(id: $0, variant: $0, sourceTitle: nil, sortYear: 0) }
                }

                await MainActor.run {
                    self.variantRows = rows
                }

                if let userId = AuthenticationManager.shared.user?.uid {
                    let resultsSnap = try await Firestore.firestore()
                        .collection("users")
                        .document(userId)
                        .collection("results")
                        .whereField("language", isEqualTo: firestoreLanguage)
                        .getDocuments()

                    var completed: Set<Int> = []
                    var scores: [Int: Int] = [:]

                    for doc in resultsSnap.documents {
                        if doc["entrySource"] != nil { continue }
                        if let variant = doc["variant"] as? Int,
                           let correct = doc["correctAnswers"] as? Int,
                           let total = doc["totalQuestions"] as? Int, total > 0 {
                            completed.insert(variant)
                            let percentage = Int((Double(correct) / Double(total)) * 100)
                            scores[variant] = percentage
                        }
                    }

                    await MainActor.run {
                        self.completedVariants = completed
                        self.variantScores = scores
                    }
                }

                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                print("Ошибка загрузки вариантов: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

private struct VariantChoiceCell: View {
    let variant: Int
    let sourceTitle: String?
    let sortYear: Int
    let isCompleted: Bool
    let score: Int?
    let onTap: () -> Void

    private var trimmedSource: String {
        sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var titleText: String {
        trimmedSource.isEmpty ? "Вариант \(variant)" : trimmedSource
    }

    private var showVariantNumber: Bool {
        !trimmedSource.isEmpty
    }

    private var accessibilityCardTitle: String {
        if let score {
            return "\(titleText), лучший результат \(score) процентов"
        }
        if isCompleted {
            return "\(titleText), уже решали"
        }
        return titleText
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if sortYear > 0 {
                        Text(verbatim: "\(sortYear)")
                            .font(.custom("MontserratAlternates-Bold", size: 12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(ExamixStyle.practiceThemesGradient)
                            )
                    }

                    if showVariantNumber {
                        Text("Вариант \(variant)")
                            .font(.custom("MontserratAlternates-SemiBold", size: 15))
                            .foregroundStyle(ExamixStyle.accentCool)
                    }
                }

                Text(verbatim: titleText)
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .foregroundStyle(Color(.darkAccent))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                if let score {
                    Text("Лучший результат · \(score)%")
                        .font(.custom("MontserratAlternates-Medium", size: 13))
                        .foregroundStyle(.secondary)
                } else if isCompleted {
                    HStack(spacing: 6) {
                        Text("✓")
                            .font(.custom("MontserratAlternates-Bold", size: 13))
                            .foregroundStyle(Color(red: 0.2, green: 0.58, blue: 0.4))
                        Text("Уже решали")
                            .font(.custom("MontserratAlternates-Medium", size: 13))
                            .foregroundStyle(Color(red: 0.2, green: 0.58, blue: 0.4))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("›")
                .font(.custom("MontserratAlternates-Bold", size: 18))
                .foregroundStyle(ExamixStyle.accentCool.opacity(0.5))
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isCompleted
                            ? [
                                Color(red: 0.22, green: 0.62, blue: 0.45).opacity(0.4),
                                Color(red: 0.22, green: 0.62, blue: 0.45).opacity(0.12)
                            ]
                            : [
                                Color.white.opacity(0.95),
                                ExamixStyle.accentCool.opacity(0.22)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityCardTitle)
        .accessibilityAddTraits(.isButton)
    }
}
