//
//  ResultsView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI

struct ResultsView: View {
    @StateObject private var viewModel = ResultsViewModel()
    @State private var searchText = ""
    @State private var selectedLanguageFilter: String = "Все"
    @State private var sortOption: SortOption = .byDate

    private var filteredResults: [TestResult] {
        var results = viewModel.results

        if selectedLanguageFilter != "Все" {
            results = results.filter { $0.language == selectedLanguageFilter }
        }

        if !searchText.isEmpty {
            results = results.filter { $0.language.lowercased().contains(searchText.lowercased()) }
        }
        
        switch sortOption {
        case .byDate:
            results = results.sorted(by: { $0.timestamp > $1.timestamp })
        case .byAccuracy:
            results = results.sorted {
                let percent0 = Double($0.correctAnswers) / Double($0.totalQuestions)
                let percent1 = Double($1.correctAnswers) / Double($1.totalQuestions)
                return percent0 > percent1
            }
        }

        return results
    }

    private var allLanguages: [String] {
        let langs = Set(viewModel.results.map { $0.language })
        return ["Все"] + langs.sorted()
    }

    var body: some View {
        NavigationView {
            VStack {

                VStack(spacing: 10) {
                    TextField("Поиск по языку...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    HStack {
                        Picker("Сортировка", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)

                        Menu {
                            ForEach(allLanguages, id: \.self) { lang in
                                Button(lang) {
                                    selectedLanguageFilter = lang
                                }
                            }
                        } label: {
                            Label("Фильтр: \(selectedLanguageFilter)", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.subheadline)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)

                List(filteredResults) { result in
                    NavigationLink(destination: ResultDetailView(result: result)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(result.language), вариант \(result.variant)")
                                    .font(.custom("MontserratAlternates-Bold", size: 16))
                                    .foregroundStyle(.darkAccent)
                                Spacer()
                                Text(result.timestamp.formatted(date: .numeric, time: .shortened))
                                    .font(.custom("MontserratAlternates-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }

                            Text("Правильных: \(result.correctAnswers) из \(result.totalQuestions)")
                                .font(.custom("MontserratAlternates-Medium", size: 14))
                                .foregroundColor(.stock)

                            if result.totalQuestions > 0 {
                                let percent = Int((Double(result.correctAnswers) / Double(result.totalQuestions)) * 100)
                                Text("Процент: \(percent)%")
                                    .font(.custom("MontserratAlternates-Medium", size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Результаты тестов")
                        .font(.custom("MontserratAlternates-Bold", size: 20))
                        .foregroundColor(.primary)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadResults()
                }
            }
        }
    }
}

enum SortOption: String, CaseIterable {
    case byDate
    case byAccuracy

    var title: String {
        switch self {
        case .byDate: return "По дате"
        case .byAccuracy: return "По точности"
        }
    }
}


#Preview {
    ResultsView()
}
