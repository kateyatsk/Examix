//
//  ResultDetailView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 2.05.25.
//

import Foundation
import SwiftUI
import Charts

struct ResultDetailView: View {
    let result: TestResult
    
    var partAStats: (total: Int, correct: Int, partial: Int, wrong: Int) {
        let ids = result.allQuestionIDs.filter { id in
            guard let first = id.first else { return false }
            let letter = String(first).lowercased()
            return letter == "a" || letter == "а"
        }
        let filtered = ids.filter { result.questionTypesById?[$0] != "text" }
        
        var correct = 0
        var partial = 0
        var wrong = 0
        
        for id in filtered {
            let type = result.questionTypesById?[id]
            let correctSet = Set(result.correctOptionsById?[id] ?? [])
            let userAnswer = result.answers[id]
            
            if userAnswer == nil {
                correct += 1
            } else if (result.language == "Русский язык" || result.language == "Белорусский язык") && type == "multi" {
                let selected = Set(userAnswer!.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                
                if !selected.isEmpty,
                   selected.isSubset(of: correctSet),
                   selected.count < correctSet.count {
                    partial += 1
                } else {
                    wrong += 1
                }
            } else {
                wrong += 1
            }
        }
        
        return (filtered.count, correct, partial, wrong)
    }
    
    var partBStats: (total: Int, correct: Int, wrong: Int) {
        let ids = result.allQuestionIDs.filter { $0.lowercased().starts(with: "b") }
        
        var correct = 0
        var wrong = 0
        
        for id in ids {
            if result.answers[id] == nil {
                correct += 1
            } else {
                wrong += 1
            }
        }
        
        return (ids.count, correct, wrong)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Результаты: вариант \(result.variant)")
                    .font(.custom("MontserratAlternates-Bold", size: 20))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Статистика по части A")
                        .font(.custom("MontserratAlternates-Bold", size: 18))
                    Text("Всего: \(partAStats.total), верно: \(partAStats.correct), частично: \(partAStats.partial), ошибки: \(partAStats.wrong)")
                        .font(.custom("MontserratAlternates-Medium", size: 16))
                    
                    Chart {
                        BarMark(x: .value("Тип", "✅ Верно"), y: .value("Количество", partAStats.correct))
                            .foregroundStyle(.green)
                        if result.language == "Русский язык" || result.language == "Белорусский язык" {
                            BarMark(x: .value("Тип", "🟡 Частично"), y: .value("Количество", partAStats.partial))
                                .foregroundStyle(.orange)
                        }
                        BarMark(x: .value("Тип", "❌ Ошибки"), y: .value("Количество", partAStats.wrong))
                            .foregroundStyle(.red)
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Статистика по части B")
                        .font(.custom("MontserratAlternates-Bold", size: 18))
                    Text("Всего: \(partBStats.total), верно: \(partBStats.correct), ошибки: \(partBStats.wrong)")
                        .font(.custom("MontserratAlternates-Medium", size: 16))
                    
                    Chart {
                        BarMark(x: .value("Тип", "✅ Верно"), y: .value("Количество", partBStats.correct))
                            .foregroundStyle(.green)
                        BarMark(x: .value("Тип", "❌ Ошибки"), y: .value("Количество", partBStats.wrong))
                            .foregroundStyle(.red)
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Подробные ответы")
                        .font(.custom("MontserratAlternates-Bold", size: 18))
                    
                    ForEach(result.allQuestionIDs, id: \.self) { id in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Задание \(id)")
                                .font(.custom("MontserratAlternates-Bold", size: 16))
                            
                            if let answer = result.answers[id] {
                                let selected = Set(answer.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                                let correct = Set(result.correctOptionsById?[id] ?? [])
                                let isPartial = (result.language == "Русский язык" ||
                                result.language == "Белорусский язык") &&
                                result.questionTypesById?[id] == "multi" &&
                                !selected.isEmpty &&
                                selected.isSubset(of: correct) &&
                                selected.count < correct.count
                                
                                if isPartial {
                                    Text("🟡 Частично верно: \(answer)")
                                        .foregroundColor(.orange)
                                        .font(.custom("MontserratAlternates-Medium", size: 14))
                                } else {
                                    Text("❌ Ваш ответ: \(answer)")
                                        .foregroundColor(.red)
                                        .font(.custom("MontserratAlternates-Medium", size: 14))
                                }
                            } else {
                                Text("✅ Ответ верный")
                                    .foregroundColor(.green)
                                    .font(.custom("MontserratAlternates-Medium", size: 14))
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Результаты тестов")
                    .font(.custom("MontserratAlternates-Bold", size: 20))
                    .foregroundColor(.primary)
            }
        }
    }
}

extension TestResult {
    var totalQuestionsIDs: [String] {
        allQuestionIDs
    }
}
