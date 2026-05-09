//
//  ResultDetailView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 2.05.25.
//

import Foundation
import SwiftUI
import Charts

// MARK: - Модель строки и детального листа

private enum ResultAnswerStatus {
    case correct
    case partial
    case wrong

    var title: String {
        switch self {
        case .correct: return "Верно"
        case .partial: return "Частично верно"
        case .wrong: return "Неверно"
        }
    }

    var symbolName: String {
        switch self {
        case .correct: return "checkmark.circle.fill"
        case .partial: return "minus.circle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .correct: return ExamixStyle.statCorrect
        case .partial: return ExamixStyle.statPartial
        case .wrong: return ExamixStyle.statWrong
        }
    }
}

private struct QuestionResultDetailItem: Identifiable, Hashable {
    /// Уникален в списке (при повторяющихся кодах типа A1/B1 в одном варианте).
    let rowIndex: Int
    /// Код типа задания для словарей в `TestResult` и бейджа в UI.
    let typeCode: String
    var id: String { "row_\(rowIndex)_\(typeCode)" }

    let question: Question?
    let userAnswerDisplay: String
    let correctAnswerDisplay: String
    let status: ResultAnswerStatus
    let questionType: String?
}

// MARK: - Карточка в списке

private struct ResultAnswerCard: View {
    let item: QuestionResultDetailItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(item.typeCode)
                        .font(.custom("MontserratAlternates-Bold", size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ExamixStyle.squircleFill)
                        )

                    Image(systemName: item.status.symbolName)
                        .font(.title3)
                        .foregroundColor(item.status.accentColor)

                    Text(item.status.title)
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundColor(item.status.accentColor)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }

                if let q = item.question {
                    Text(.init(q.title))
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                } else {
                    Text("Задание \(item.typeCode)")
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    labeledRow(title: "Ваш ответ", value: item.userAnswerDisplay, tint: .primary)
                    labeledRow(title: "Правильный ответ", value: item.correctAnswerDisplay, tint: ExamixStyle.statCorrect)
                }
                .padding(.top, 4)
            }
            .examixDetailAnswerChrome()
        }
        .buttonStyle(.plain)
    }

    private func labeledRow(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("MontserratAlternates-Regular", size: 11))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.custom("MontserratAlternates-Medium", size: 14))
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Подробный лист (анимация появления)

private struct QuestionResultDetailSheet: View {
    let item: QuestionResultDetailItem
    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusHeader

                    Group {
                        sectionTitle("Формулировка")
                        if let q = item.question {
                            Text(.init(q.title))
                                .font(.custom("MontserratAlternates-Medium", size: 16))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Текст задания недоступен (вариант не загружен).")
                                .font(.custom("MontserratAlternates-Medium", size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 12)

                    if let q = item.question, let passage = q.text?.trimmingCharacters(in: .whitespacesAndNewlines), !passage.isEmpty {
                        Group {
                            sectionTitle("Текст / фрагмент")
                            Text(.init(passage))
                                .font(.custom("MontserratAlternates-Regular", size: 16))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 14)
                    }

                    Group {
                        sectionTitle("Ответы")
                        VStack(alignment: .leading, spacing: 12) {
                            answerPill(label: "Ваш ответ", text: item.userAnswerDisplay, role: .user)
                            answerPill(label: "Эталон", text: item.correctAnswerDisplay, role: .correct)
                        }
                    }
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 16)

                    if let q = item.question, !q.options.isEmpty, q.type != "text" {
                        Group {
                            sectionTitle("Варианты")
                            optionsBlock(question: q)
                        }
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 18)
                    }

                    if let q = item.question, let exp = q.explanation?.trimmingCharacters(in: .whitespacesAndNewlines), !exp.isEmpty {
                        Group {
                            sectionTitle("Пояснение")
                            Text(.init(exp))
                                .font(.custom("MontserratAlternates-Regular", size: 16))
                                .foregroundColor(.primary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(ExamixStyle.accentMuted.opacity(0.14))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(ExamixStyle.accentCool.opacity(0.28), lineWidth: 1)
                                )
                        }
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 20)
                    } else {
                        Group {
                            sectionTitle("Пояснение")
                            Text("Для этого задания в базе нет отдельного пояснения.")
                                .font(.custom("MontserratAlternates-Medium", size: 14))
                                .foregroundColor(.secondary)
                        }
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 20)
                    }

                    if let t = item.questionType {
                        Text("Тип ответа в тесте: \(t)")
                            .font(.custom("MontserratAlternates-Regular", size: 12))
                            .foregroundColor(.secondary)
                            .opacity(revealed ? 1 : 0)
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Задание \(item.typeCode)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .font(.custom("MontserratAlternates-SemiBold", size: 16))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78, blendDuration: 0.15)) {
                revealed = true
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.status.accentColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: item.status.symbolName)
                    .font(.system(size: 28))
                    .foregroundColor(item.status.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.status.title)
                    .font(.custom("MontserratAlternates-Bold", size: 20))
                    .foregroundColor(.primary)
                Text("Нажмите «Готово», чтобы вернуться к списку.")
                    .font(.custom("MontserratAlternates-Regular", size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .scaleEffect(revealed ? 1 : 0.92)
        .opacity(revealed ? 1 : 0)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.custom("MontserratAlternates-Bold", size: 13))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    private enum AnswerPillRole { case user, correct }

    private func answerPill(label: String, text: String, role: AnswerPillRole) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("MontserratAlternates-Regular", size: 11))
                .foregroundColor(.secondary)
            Text(text)
                .font(.custom("MontserratAlternates-Medium", size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(role == .correct ? Color.green.opacity(0.12) : Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(role == .correct ? Color.green.opacity(0.35) : Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func optionsBlock(question: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(question.options) { opt in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: opt.isCorrect ? "checkmark.seal.fill" : "circle")
                        .foregroundColor(opt.isCorrect ? .green : .secondary)
                        .font(.body)
                    Text(.init(opt.text))
                        .font(.custom("MontserratAlternates-Regular", size: 15))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(opt.isCorrect ? Color.green.opacity(0.06) : Color(.secondarySystemBackground))
                )
            }
        }
    }
}

// MARK: - Построение строк из результата

private enum ResultDetailBuilders {

    static func shortLanguageForFetch(_ stored: String) -> String {
        let suffix = " язык"
        if stored.hasSuffix(suffix) {
            return String(stored.dropLast(suffix.count))
        }
        return stored
    }

    static func status(for id: String, result: TestResult) -> ResultAnswerStatus {
        guard let answer = result.answers[id] else { return .correct }
        let selected = Set(answer.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        let correct = Set(result.correctOptionsById?[id] ?? [])
        let type = result.questionTypesById?[id]
        let isPartial = (result.language == "Русский язык" || result.language == "Белорусский язык")
            && type == "multi"
            && !selected.isEmpty
            && selected.isSubset(of: correct)
            && selected.count < correct.count
        if isPartial { return .partial }
        return .wrong
    }

    static func userAnswerLine(result: TestResult, id: String) -> String {
        if let a = result.answers[id] { return a }
        return "Совпадает с правильным ответом"
    }

    static func correctAnswerLine(question: Question?, id: String, result: TestResult) -> String {
        if let q = question {
            if q.type == "text" {
                return q.options.first?.text ?? "—"
            }
            let texts = q.options.filter(\.isCorrect).map(\.text)
            if !texts.isEmpty { return texts.joined(separator: ", ") }
        }
        if let arr = result.correctOptionsById?[id], !arr.isEmpty {
            return arr.joined(separator: ", ")
        }
        return "—"
    }

    static func questionAtListIndex(result: TestResult, test: TestVariant?, listIndex: Int, typeCode: String) -> Question? {
        guard let test else { return nil }
        if let indices = result.questionIndicesInVariant,
           indices.count == result.allQuestionIDs.count,
           listIndex < indices.count {
            let vi = indices[listIndex]
            if vi >= 0, vi < test.questions.count { return test.questions[vi] }
        }
        return test.questions.first { $0.id == typeCode }
    }

    static func buildItems(result: TestResult, test: TestVariant?) -> [QuestionResultDetailItem] {
        result.allQuestionIDs.enumerated().map { (listIndex, typeCode) in
            let q = questionAtListIndex(result: result, test: test, listIndex: listIndex, typeCode: typeCode)
            return QuestionResultDetailItem(
                rowIndex: listIndex,
                typeCode: typeCode,
                question: q,
                userAnswerDisplay: userAnswerLine(result: result, id: typeCode),
                correctAnswerDisplay: correctAnswerLine(question: q, id: typeCode, result: result),
                status: status(for: typeCode, result: result),
                questionType: result.questionTypesById?[typeCode]
            )
        }
    }
}

// MARK: - Геро-блок итога (анимация при открытии разбора)

private struct ResultDetailHeroCard: View {
    let result: TestResult
    let ringProgress: CGFloat

    private var overallPercent: Int {
        guard result.totalQuestions > 0 else { return 0 }
        return Int((Double(result.correctAnswers) / Double(result.totalQuestions)) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let kind = result.practiceKindTitle {
                        Text(kind)
                            .font(.custom("MontserratAlternates-Bold", size: 22))
                            .foregroundStyle(Color(.darkAccent))
                        if let detail = result.practiceDetail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                            Text(detail)
                                .font(.custom("MontserratAlternates-Medium", size: 14))
                                .foregroundStyle(ExamixStyle.accentCool)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("\(result.language) · вариант \(result.variant)")
                            .font(.custom("MontserratAlternates-Regular", size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Вариант \(result.variant)")
                            .font(.custom("MontserratAlternates-Bold", size: 26))
                            .foregroundStyle(Color(.darkAccent))
                        Text(result.language)
                            .font(.custom("MontserratAlternates-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Text(result.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.custom("MontserratAlternates-Regular", size: 12))
                        .foregroundStyle(ExamixStyle.accentCool.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.07), lineWidth: 10)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: ringProgress)
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
                        .frame(width: 100, height: 100)
                    VStack(spacing: 0) {
                        Text("\(overallPercent)%")
                            .font(.custom("MontserratAlternates-Bold", size: 20))
                            .foregroundStyle(Color(.darkAccent))
                        Text("итог")
                            .font(.custom("MontserratAlternates-Medium", size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                heroPill(
                    icon: "checkmark.circle.fill",
                    text: "\(result.correctAnswers) из \(result.totalQuestions)",
                    color: ExamixStyle.statCorrect
                )
                if result.correctAnswers < result.totalQuestions {
                    heroPill(
                        icon: "exclamationmark.circle.fill",
                        text: "разбор ниже",
                        color: ExamixStyle.accentCool
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            ExamixStyle.accentCool.opacity(0.06),
                            ExamixStyle.accentMuted.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            ExamixStyle.accentCool.opacity(0.35),
                            ExamixStyle.accentMuted.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: ExamixStyle.accentCool.opacity(0.12), radius: 20, x: 0, y: 10)
    }

    private func heroPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.custom("MontserratAlternates-SemiBold", size: 13))
                .foregroundStyle(Color(.darkAccent))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Главный экран

struct ResultDetailView: View {
    let result: TestResult

    @State private var loadedTest: TestVariant?
    @State private var loadFailed = false
    @State private var detailItem: QuestionResultDetailItem?
    @State private var heroReveal = false
    @State private var heroRingProgress: CGFloat = 0
    @State private var chartsReveal = false
    @State private var listReveal = false

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

    private var answerCards: [QuestionResultDetailItem] {
        ResultDetailBuilders.buildItems(result: result, test: loadedTest)
    }

    private var partARingSlices: [ExamixStatRingSlice] {
        var list: [ExamixStatRingSlice] = [
            ExamixStatRingSlice(id: "ok", label: "Верно", value: Double(partAStats.correct), color: ExamixStyle.statCorrect)
        ]
        if result.language == "Русский язык" || result.language == "Белорусский язык" {
            list.append(ExamixStatRingSlice(id: "part", label: "Частично", value: Double(partAStats.partial), color: ExamixStyle.statPartial))
        }
        list.append(ExamixStatRingSlice(id: "bad", label: "Ошибки", value: Double(partAStats.wrong), color: ExamixStyle.statWrong))
        return list
    }

    private var partBBarItems: [ExamixBarStat] {
        [
            ExamixBarStat(id: "ok", title: "Верно", value: Double(partBStats.correct), color: ExamixStyle.statCorrect),
            ExamixBarStat(id: "bad", title: "Ошибки", value: Double(partBStats.wrong), color: ExamixStyle.statWrong)
        ]
    }

    private func statCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ExamixStyle.cardFill)
                    .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [ExamixStyle.accentMuted.opacity(0.4), ExamixStyle.accentCool.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var overallAccuracyPercent: Int {
        guard result.totalQuestions > 0 else { return 0 }
        return Int((Double(result.correctAnswers) / Double(result.totalQuestions)) * 100)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ResultDetailHeroCard(result: result, ringProgress: heroRingProgress)
                    .opacity(heroReveal ? 1 : 0)
                    .offset(y: heroReveal ? 0 : 26)
                    .scaleEffect(heroReveal ? 1 : 0.94)

                Group {
                    statCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Часть A")
                                .font(.custom("MontserratAlternates-Bold", size: 18))
                                .foregroundStyle(Color(.darkAccent))

                            Text("Заданий с выбором ответа: \(partAStats.total) · верно \(partAStats.correct), частично \(partAStats.partial), ошибок \(partAStats.wrong)")
                                .font(.custom("MontserratAlternates-Regular", size: 13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ExamixStatRingChart(
                                slices: partARingSlices,
                                centerTitle: "\(partAStats.total)",
                                centerSubtitle: "в части A"
                            )
                        }
                    }

                    statCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Часть B")
                                .font(.custom("MontserratAlternates-Bold", size: 18))
                                .foregroundStyle(Color(.darkAccent))

                            Text("Письменные ответы: \(partBStats.total) · верно \(partBStats.correct), ошибок \(partBStats.wrong)")
                                .font(.custom("MontserratAlternates-Regular", size: 13))
                                .foregroundStyle(.secondary)

                            ExamixStatRingChart(
                                slices: [
                                    ExamixStatRingSlice(id: "bok", label: "Верно", value: Double(partBStats.correct), color: ExamixStyle.statCorrect),
                                    ExamixStatRingSlice(id: "bbad", label: "Ошибки", value: Double(partBStats.wrong), color: ExamixStyle.statWrong)
                                ],
                                centerTitle: "\(partBStats.total)",
                                centerSubtitle: "в части B"
                            )

                            ExamixVerticalBarChart(bars: partBBarItems, height: 140)
                        }
                    }
                }
                .opacity(chartsReveal ? 1 : 0)
                .offset(y: chartsReveal ? 0 : 18)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Подробные ответы")
                            .font(.custom("MontserratAlternates-Bold", size: 18))
                        Spacer()
                        if loadedTest == nil, !loadFailed {
                            ProgressView()
                                .scaleEffect(0.9)
                        }
                    }

                    if loadFailed {
                        Text("Не удалось загрузить вариант для подробностей. Показаны только сохранённые ответы.")
                            .font(.custom("MontserratAlternates-Medium", size: 14))
                            .foregroundColor(.secondary)
                    }

                    Text("Нажмите на карточку, чтобы открыть пояснение и полную информацию.")
                        .font(.custom("MontserratAlternates-Regular", size: 13))
                        .foregroundColor(.secondary)

                    LazyVStack(spacing: 14) {
                        ForEach(answerCards) { item in
                            ResultAnswerCard(item: item) {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                    detailItem = item
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
                .opacity(listReveal ? 1 : 0)
                .offset(y: listReveal ? 0 : 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(
            ZStack {
                ExamixStyle.screenCanvas
                LinearGradient(
                    colors: [
                        ExamixStyle.accentCool.opacity(0.08),
                        Color.clear,
                        ExamixStyle.accentMuted.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Разбор теста")
                    .font(.custom("MontserratAlternates-Bold", size: 18))
                    .foregroundColor(.darkAccent)
            }
        }
        .sheet(item: $detailItem) { item in
            QuestionResultDetailSheet(item: item)
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                heroReveal = true
            }
            let target = CGFloat(overallAccuracyPercent) / 100
            withAnimation(.easeOut(duration: 0.95).delay(0.06)) {
                heroRingProgress = target
            }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86).delay(0.22)) {
                chartsReveal = true
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88).delay(0.38)) {
                listReveal = true
            }
        }
        .task {
            await loadTestVariant()
        }
    }

    @MainActor
    private func loadTestVariant() async {
        let ui = ResultDetailBuilders.shortLanguageForFetch(result.language)
        do {
            let t = try await VariantCatalogService.shared.fetchTest(uiLanguage: ui, variant: result.variant)
            loadedTest = t
        } catch {
            loadFailed = true
        }
    }
}

