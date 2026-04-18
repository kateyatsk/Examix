//
//  ChooseVariantRoute.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 25.04.25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChooseVariantView: View {
    var language: String
    @Binding var path: NavigationPath
    @EnvironmentObject var userSettings: UserSettings

    @State private var availableVariants: [Int] = []
    @State private var completedVariants: Set<Int> = []
    @State private var variantScores: [Int: Int] = [:]
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            Color(.lightBack).ignoresSafeArea()

            if isLoading {
                ProgressView("Загрузка...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .brown))
            } else {
                VStack(spacing: 20) {

                    Text("Выберите какой вариант\nхотите решить?")
                        .font(.custom("MontserratAlternates-Medium", size: 20))
                        .foregroundColor(.darkAccent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    Text("Язык: \(language)")
                        .font(.custom("MontserratAlternates-Bold", size: 16))
                        .foregroundColor(.gray)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(availableVariants, id: \ .self) { variant in
                            VariantButton(
                                variant: variant,
                                isCompleted: completedVariants.contains(variant),
                                score: variantScores[variant]
                            ) {
                                userSettings.selectedVariant = variant
                                path.append(HomeView.Path.testView)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding()
            }
        }
        .onAppear(perform: loadVariants)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.mainBack)
                    .overlay {
                        Image(systemName: "arrow.backward")
                            .imageScale(.large)
                            .foregroundStyle(.darkAccent)
                    }
                    .onTapGesture {
                        path.removeLast()
                    }
            }
        }
    }

    private func loadVariants() {
        Task {
            do {
                let db = Firestore.firestore()
                let firestoreLanguage = language + " язык"

                let snapshot = try await db.collection("tests")
                    .whereField("language", isEqualTo: firestoreLanguage)
                    .getDocuments()

                let variants = snapshot.documents.compactMap {
                    ($0.data()["variant"] as? NSNumber)?.intValue
                }

                DispatchQueue.main.async {
                    self.availableVariants = Array(Set(variants)).sorted()
                }

                // Загружаем завершённые варианты из коллекции results
                if let userId = AuthenticationManager.shared.user?.uid {
                    let resultsSnap = try await db.collection("users")
                        .document(userId)
                        .collection("results")
                        .whereField("language", isEqualTo: firestoreLanguage)
                        .getDocuments()

                    var completed: Set<Int> = []
                    var scores: [Int: Int] = [:]

                    for doc in resultsSnap.documents {
                        if let variant = doc["variant"] as? Int,
                           let correct = doc["correctAnswers"] as? Int,
                           let total = doc["totalQuestions"] as? Int, total > 0 {
                            completed.insert(variant)
                            let percentage = Int((Double(correct) / Double(total)) * 100)
                            scores[variant] = percentage
                        }
                    }

                    DispatchQueue.main.async {
                        self.completedVariants = completed
                        self.variantScores = scores
                    }
                }

                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } catch {
                print("Ошибка загрузки вариантов: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

private struct VariantButton: View {
    let variant: Int
    let isCompleted: Bool
    let score: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 16)
                .fill(isCompleted ? Color.green.opacity(0.7) : Color.orange.opacity(0.3))
                .frame(height: 80)
                .overlay(
                    VStack {
                        Text("\(variant)")
                            .foregroundColor(.darkAccent)
                            .font(.custom("MontserratAlternates-SemiBold", size: 20))
                        if let score {
                            Text("\(score)%")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
