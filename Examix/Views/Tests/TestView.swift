//
//  TestView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI
import UIKit
import FirebaseFirestore
import AlertToast

private enum ExamixKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// `UITextField` без панели подсказок/T9: отключены автокоррекция, inline‑prediction и кнопки над клавиатурой.
private struct PlainAnswerTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isEnabled: Bool

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.delegate = context.coordinator
        tf.textColor = .label
        tf.font = UIFont(name: "MontserratAlternates-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartDashesType = .no
        tf.smartInsertDeleteType = .no
        tf.smartQuotesType = .no
        tf.autocapitalizationType = .none
        tf.keyboardType = .default
        tf.textContentType = .none
        tf.returnKeyType = .done
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        if #available(iOS 17.0, *) {
            tf.inlinePredictionType = .no
        }
        let item = tf.inputAssistantItem
        item.leadingBarButtonGroups = []
        item.trailingBarButtonGroups = []
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PlainAnswerTextField

        init(_ parent: PlainAnswerTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

private struct MultipleChoiceView: View {
    let question: Question
    @ObservedObject var viewModel: TestViewModel
    
    var body: some View {
        ForEach(question.options) { option in
            let isSelected = viewModel.selectedOptions[question.id]?.contains(option) ?? false
            let isCorrect = option.isCorrect
            let isChecked = viewModel.isChecked

            let borderColor: Color = {
                if isChecked {
                    if isCorrect { return Color(red: 0.2, green: 0.62, blue: 0.42) }
                    return isSelected ? Color(red: 0.85, green: 0.32, blue: 0.35) : Color.primary.opacity(0.08)
                }
                return isSelected ? ExamixStyle.accentCool : Color.primary.opacity(0.1)
            }()

            let fillOpacity: Double = isSelected && !isChecked ? 0.08 : (isChecked && isCorrect ? 0.06 : (isChecked && isSelected && !isCorrect ? 0.06 : 0))
            
            Button(action: {
                viewModel.select(option: option, for: question)
            }) {
                HStack(alignment: .center, spacing: 12) {
                    Text(.init(option.text))
                        .font(.custom("MontserratAlternates-Medium", size: 16))
                        .foregroundStyle(Color(.darkAccent))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    
                    Spacer(minLength: 8)
                    
                    if isSelected {
                        Text("✓")
                            .font(.custom("MontserratAlternates-Bold", size: 18))
                            .foregroundStyle(
                                isChecked
                                    ? (isCorrect ? Color.green : Color.red)
                                    : ExamixStyle.accentCool
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ExamixStyle.accentCool.opacity(fillOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isSelected || isChecked ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isChecked)
        }
    }
}

private struct TextAnswerView: View {
    let question: Question
    @ObservedObject var viewModel: TestViewModel

    private var answerBinding: Binding<String> {
        Binding(
            get: { viewModel.textAnswers[question.id, default: ""] },
            set: { viewModel.textAnswers[question.id] = $0 }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlainAnswerTextField(
                placeholder: "Введите ответ",
                text: answerBinding,
                isEnabled: !viewModel.isChecked
            )
            .frame(minHeight: 48)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(ExamixStyle.accentCool.opacity(viewModel.isChecked ? 0.2 : 0.35), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            
            if viewModel.isChecked {
                let correct = question.options.first?.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let userAnswer = viewModel.textAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                
                if userAnswer == correct {
                    Text(viewModel.textAnswers[question.id] ?? "")
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundStyle(Color(.darkAccent))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.2, green: 0.62, blue: 0.42).opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(red: 0.2, green: 0.62, blue: 0.42).opacity(0.45), lineWidth: 1)
                        )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.textAnswers[question.id] ?? "")
                            .font(.custom("MontserratAlternates-Medium", size: 15))
                            .strikethrough(true, color: .secondary)
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    
                    Text("Правильный ответ: \(question.options.first?.text ?? "")")
                            .font(.custom("MontserratAlternates-Medium", size: 14))
                            .foregroundStyle(Color(.darkAccent))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(ExamixStyle.softProfileCard)
                            )
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Готово") {
                        ExamixKeyboard.dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}

private struct HintSheetView: View {
    let explanation: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ExamixStyle.practiceScreenWash
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "lightbulb.circle.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1, green: 0.78, blue: 0.35),
                                            Color(red: 0.95, green: 0.52, blue: 0.18)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Подсказка к заданию")
                                    .font(.custom("MontserratAlternates-Medium", size: 16))
                                    .foregroundStyle(Color(.darkAccent))
                                Text("Кратко о том, на что обратить внимание")
                                    .font(.custom("MontserratAlternates-Medium", size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 4)

                        Text(.init(explanation))
                            .font(.custom("MontserratAlternates-Regular", size: 16))
                            .foregroundStyle(Color(.darkAccent).opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                ExamixStyle.accentCool.opacity(0.22),
                                                Color.white.opacity(0.5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Подсказка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Text("Закрыть")
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundStyle(ExamixStyle.accentCool)
                    }
                }
            }
        }
    }
}

private struct PassageSheetView: View {
    let question: Question
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ExamixStyle.practiceScreenWash
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Задание")
                            .font(.custom("MontserratAlternates-Medium", size: 13))
                            .foregroundStyle(ExamixStyle.accentCool)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Text(.init(question.title))
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundStyle(Color(.darkAccent))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let passage = question.text?.trimmingCharacters(in: .whitespacesAndNewlines), !passage.isEmpty {
                            Text("Текст")
                                .font(.custom("MontserratAlternates-Medium", size: 13))
                                .foregroundStyle(ExamixStyle.accentCool)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.top, 4)

                            Text(.init(passage))
                                .font(.custom("MontserratAlternates-Regular", size: 16))
                                .foregroundStyle(Color(.darkAccent))
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(ExamixStyle.accentCool.opacity(0.14), lineWidth: 1)
                    )
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Текст")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Text("Закрыть")
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundStyle(ExamixStyle.accentCool)
                    }
                }
            }
        }
    }
}

/// Превью фрагмента чтения: не более четырёх строк, затем ссылка на полный текст.
private struct PassagePreviewBlock: View {
    let passage: String
    let onOpenFull: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.init(passage))
                .font(.custom("MontserratAlternates-Regular", size: 16))
                .foregroundStyle(Color(.darkAccent).opacity(0.85))
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onOpenFull) {
                Text("Открыть текст полностью →")
                    .font(.custom("MontserratAlternates-Medium", size: 16))
                    .foregroundStyle(ExamixStyle.accentCool)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

/// Отступы колонки — отдельный модификатор, чтобы не раздувать тип `ModifiedContent`.
private struct ActiveTestScrollPadModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }
}

/// Реакции на смену варианта / языка / индекса вопроса.
private struct ActiveTestScrollIndexEventsModifier: ViewModifier {
    @ObservedObject var viewModel: TestViewModel
    let test: TestVariant
    @Binding var showPassageSheet: Bool
    @Binding var showHintSheet: Bool
    @Binding var hintsUsedThisSession: Int
    let practiceMode: Bool
    let scheduleDraft: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: test.variant) { _, _ in
                hintsUsedThisSession = 0
            }
            .onChange(of: test.language) { _, _ in
                hintsUsedThisSession = 0
            }
            .onChange(of: viewModel.currentIndex) { _, _ in
                showPassageSheet = false
                showHintSheet = false
                ExamixKeyboard.dismiss()
                if !practiceMode {
                    scheduleDraft()
                }
            }
    }
}

/// Реакции на ответы и завершение — отдельно от индекса, чтобы укоротить цепочку типов.
private struct ActiveTestScrollAnswerEventsModifier: ViewModifier {
    @ObservedObject var viewModel: TestViewModel
    @EnvironmentObject private var userSettings: UserSettings
    let test: TestVariant
    let practiceMode: Bool
    let scheduleDraft: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.isChecked) { _, checked in
                if checked {
                    ExamixKeyboard.dismiss()
                }
                if !practiceMode {
                    scheduleDraft()
                }
            }
            .onChange(of: viewModel.textAnswers) { _, _ in
                if !practiceMode {
                    scheduleDraft()
                }
            }
            .onChange(of: viewModel.selectedOptions) { _, _ in
                if !practiceMode {
                    scheduleDraft()
                }
            }
            .onChange(of: viewModel.finishedResult) { _, newResult in
                guard !practiceMode, newResult != nil else { return }
                let ui = userSettings.selectedLanguage?.rawValue ?? ""
                PendingTestSessionStore.remove(examLanguage: test.language, variant: test.variant, uiLearningLanguage: ui)
            }
    }
}

private struct ActiveTestScrollSheetsModifier: ViewModifier {
    @ObservedObject var viewModel: TestViewModel
    let test: TestVariant
    @Binding var showPassageSheet: Bool
    @Binding var showHintSheet: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showPassageSheet) {
                PassageSheetView(
                    question: test.questions[viewModel.currentIndex],
                    onClose: { showPassageSheet = false }
                )
            }
            .sheet(isPresented: $showHintSheet) {
                HintSheetView(
                    explanation: test.questions[viewModel.currentIndex].explanation ?? "",
                    onClose: { showHintSheet = false }
                )
            }
    }
}

struct TestView: View {
    @ObservedObject var viewModel: TestViewModel
    @EnvironmentObject private var userSettings: UserSettings
    /// Одно задание подряд: компактный итог и колбэк вместо полного экрана результатов.
    var practiceMode: Bool = false
    /// Узкая полоска «верно / неверно» + «Далее» без экрана «Поздравляем».
    var practiceInlineFeedback: Bool = false
    var practiceOnFinished: (() -> Void)? = nil
    /// Для практики по темам/типам: доля решённых по всему выбранному каталогу (а не ответ на одном вопросе).
    var practiceCatalogSolved: Int? = nil
    var practiceCatalogTotal: Int? = nil

    @State private var showSummary = false
    @State private var showPassageSheet = false
    @State private var showHintSheet = false
    /// Сколько раз за текущий проход теста пользователь открыл подсказку (учитывается при лимите из настроек).
    @State private var hintsUsedThisSession = 0
    @State private var isBookmarked = false
    @State private var showBookmarkToast = false
    @State private var bookmarkTask: Task<Void, Never>? = nil
    @State private var pendingDraftSaveTask: Task<Void, Never>? = nil
    
    var body: some View {
        if let test = viewModel.test {
            content(test: test)
                .onDisappear {
                    bookmarkTask?.cancel()
                    pendingDraftSaveTask?.cancel()
                    if !practiceMode, let t = viewModel.test {
                        flushPendingDraftSave(test: t)
                    }
                }
        } else {
            ZStack {
                ExamixStyle.practiceScreenWash
                    .ignoresSafeArea()
                ProgressView("Загрузка теста…")
                    .tint(ExamixStyle.accentCool)
                    .font(.custom("MontserratAlternates-Medium", size: 15))
            }
        }
        
    }
    
    @ViewBuilder
    private func content(test: TestVariant) -> some View {
        if practiceMode, let result = viewModel.finishedResult {
            if practiceInlineFeedback {
                practiceInlineFeedbackPanel(result: result)
            } else {
                practiceResultPanel(result: result)
            }
        } else if showSummary {
            if let result = viewModel.finishedResult {
                ResultSummaryView(
                    correctAnswers: result.correctAnswers,
                    totalQuestions: result.totalQuestions,
                    partialAnswers: viewModel.partialCount(for: result)
                ) {
                    showSummary = false
                }
            }
        } else if let result = viewModel.finishedResult {
            ResultDetailView(result: result)
        } else {
            activeTestTakingRoot(test: test)
        }
    }


    @ViewBuilder
    private func checkActionButtonFill(canAct: Bool) -> some View {
        if canAct {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ExamixStyle.accentCool, ExamixStyle.accentDeep.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.38))
        }
    }

    @ViewBuilder
    private func activeTestTakingRoot(test: TestVariant) -> some View {
        let question = test.questions[viewModel.currentIndex]
        let catSolved = practiceCatalogSolved
        let catTotal = practiceCatalogTotal
        let useCatalogProgress: (solved: Int, total: Int)? = {
            guard let t = catTotal, let s = catSolved, t > 0 else { return nil }
            return (solved: s, total: t)
        }()
        let progressPercent: Int = {
            if let c = useCatalogProgress {
                return min(100, max(0, Int((Double(c.solved) / Double(c.total) * 100.0).rounded())))
            }
            return viewModel.progress
        }()
        ZStack {
            ExamixStyle.practiceScreenWash
                .ignoresSafeArea()
            activeTestScrollArea(
                test: test,
                question: question,
                useCatalogProgress: useCatalogProgress,
                progressPercent: progressPercent
            )
        }
    }

    private func activeTestScrollArea(
        test: TestVariant,
        question: Question,
        useCatalogProgress: (solved: Int, total: Int)?,
        progressPercent: Int
    ) -> some View {
            ScrollView {
            activeTestMainColumn(
                test: test,
                question: question,
                useCatalogProgress: useCatalogProgress,
                progressPercent: progressPercent
            )
            .modifier(ActiveTestScrollPadModifier())
            .modifier(
                ActiveTestScrollIndexEventsModifier(
                    viewModel: viewModel,
                    test: test,
                    showPassageSheet: $showPassageSheet,
                    showHintSheet: $showHintSheet,
                    hintsUsedThisSession: $hintsUsedThisSession,
                    practiceMode: practiceMode,
                    scheduleDraft: { schedulePendingDraftSave(test: test) }
                )
            )
            .modifier(
                ActiveTestScrollAnswerEventsModifier(
                    viewModel: viewModel,
                    test: test,
                    practiceMode: practiceMode,
                    scheduleDraft: { schedulePendingDraftSave(test: test) }
                )
            )
            .modifier(
                ActiveTestScrollSheetsModifier(
                    viewModel: viewModel,
                    test: test,
                    showPassageSheet: $showPassageSheet,
                    showHintSheet: $showHintSheet
                )
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .toast(isPresenting: $showBookmarkToast) {
            AlertToast(
                type: .complete(.green),
                title: "Добавлено в закладки"
            )
        }
    }

    @ViewBuilder
    private func activeTestMainColumn(
        test: TestVariant,
        question: Question,
        useCatalogProgress: (solved: Int, total: Int)?,
        progressPercent: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            activeTestScrollTopSection(
                test: test,
                question: question,
                useCatalogProgress: useCatalogProgress,
                progressPercent: progressPercent
            )
            activeTestScrollQuestionCard(test: test, question: question)
            activeTestScrollBottomSection(test: test, question: question)
        }
    }

    @ViewBuilder
    private func activeTestScrollTopSection(
        test: TestVariant,
        question: Question,
        useCatalogProgress: (solved: Int, total: Int)?,
        progressPercent: Int
    ) -> some View {
        Text("Предмет")
            .font(.custom("MontserratAlternates-Medium", size: 13))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)

        Text(verbatim: test.language)
            .font(.custom("MontserratAlternates-Medium", size: 16))
            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(ExamixStyle.accentCool)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 6) {
            variantTitleBlock(for: test)
            Text(practiceMode ? "Практика" : "Централизованное тестирование")
                .font(.custom("MontserratAlternates-Medium", size: 14))
                .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Прогресс")
                            .font(.custom("MontserratAlternates-Medium", size: 14))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let c = useCatalogProgress {
                            Text("\(c.solved)/\(c.total) · \(progressPercent)%")
                                .font(.custom("MontserratAlternates-Medium", size: 16))
                                .foregroundStyle(ExamixStyle.accentCool)
                        } else {
                            Text("\(progressPercent)%")
                                .font(.custom("MontserratAlternates-Medium", size: 16))
                                .foregroundStyle(ExamixStyle.accentCool)
                        }
                    }
                    ProgressView(value: Float(progressPercent) / 100.0)
                        .tint(ExamixStyle.accentCool)
                        .scaleEffect(x: 1, y: 1.25, anchor: .center)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if hintAllowed(for: question) {
                    HStack(spacing: 8) {
                        Button {
                            openHintSheet()
                        } label: {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(hintButtonEnabled ? ExamixStyle.accentCool : Color.gray.opacity(0.4))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!hintButtonEnabled)
                        .accessibilityLabel("Подсказка, \(hintQuotaInline)")

                        Text(hintQuotaInline)
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundStyle(hintButtonEnabled ? Color(.darkAccent).opacity(0.55) : .secondary)
                            .fixedSize()
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func activeTestScrollQuestionCard(test: TestVariant, question: Question) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(question.id)
                            .font(.custom("MontserratAlternates-Medium", size: 14))
                            .foregroundStyle(ExamixStyle.accentDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(ExamixStyle.accentCool.opacity(0.16))
                            )

                        Text(.init(question.title))
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundStyle(Color(.darkAccent))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 48)
                    }

                    if let text = question.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                        PassagePreviewBlock(passage: text) {
                            ExamixKeyboard.dismiss()
                            showPassageSheet = true
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if question.type == "multi" || question.type == "single" {
                        MultipleChoiceView(question: question, viewModel: viewModel)
                    } else if question.type == "text" {
                        TextAnswerView(question: question, viewModel: viewModel)
                    }
                }

                Button {
                    bookmarkTask?.cancel()
                    bookmarkTask = Task {
                        await toggleBookmark(question, test: test)
                    }
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(ExamixStyle.accentCool)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закладка")
                .padding(.top, 2)
                .padding(.trailing, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                ExamixStyle.accentCool.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .task(id: question.id) {
                await checkIfBookmarked(question, test: test)
            }
        }
    }

    @ViewBuilder
    private func nextAfterCheckButtonBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.62, blue: 0.45),
                        Color(red: 0.12, green: 0.48, blue: 0.38)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    private func activeTestScrollBottomSection(test: TestVariant, question: Question) -> some View {
                    if !viewModel.isChecked {
            let canAct = viewModel.isAnswerGiven(for: question) || question.id.lowercased().contains("текст")
                            Button(action: {
                                if question.id.lowercased().contains("текст") {
                                    if viewModel.isLastQuestion {
                                        viewModel.nextQuestion()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showSummary = true
                                        }
                                    } else {
                                        viewModel.nextQuestion()
                                    }
                                } else {
                                    viewModel.isChecked = true
                                }
                            }) {
                                Text(question.id.lowercased().contains("текст") ? "Далее" : "Проверить")
                    .font(.custom("MontserratAlternates-SemiBold", size: 17))
                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(checkActionButtonFill(canAct: canAct))
                    .shadow(color: canAct ? ExamixStyle.accentCool.opacity(0.35) : .clear, radius: 12, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(!canAct)
            .padding(.top, 4)
                    } else {
                            Button(action: {
                                viewModel.isChecked = false
                                if viewModel.isLastQuestion {
                                    viewModel.nextQuestion()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showSummary = true
                                    }
                                } else {
                                    viewModel.nextQuestion()
                                }
                                isBookmarked = false
                            }) {
                                Text(viewModel.isLastQuestion ? "Завершить" : "Следующий")
                    .font(.custom("MontserratAlternates-SemiBold", size: 17))
                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(nextAfterCheckButtonBackground())
                    .shadow(color: Color(red: 0.2, green: 0.55, blue: 0.4).opacity(0.35), radius: 12, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }

        if question.type == "text", !viewModel.isChecked {
            Color.clear
                .frame(minHeight: 120)
                .contentShape(Rectangle())
                .onTapGesture {
                    ExamixKeyboard.dismiss()
                }
        }
    }

    private func schedulePendingDraftSave(test: TestVariant) {
        guard !practiceMode else { return }
        guard test.questions.count > 1 else { return }
        let ui = userSettings.selectedLanguage?.rawValue ?? ""
        pendingDraftSaveTask?.cancel()
        pendingDraftSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            flushPendingDraftSave(test: test, uiLearningLanguageOverride: ui)
        }
    }

    private func flushPendingDraftSave(test: TestVariant, uiLearningLanguageOverride: String? = nil) {
        guard !practiceMode else { return }
        guard test.questions.count > 1 else { return }
        guard viewModel.finishedResult == nil else { return }
        let ui = uiLearningLanguageOverride ?? (userSettings.selectedLanguage?.rawValue ?? "")
        guard let draft = viewModel.snapshotPendingSession(uiLearningLanguage: ui) else { return }
        PendingTestSessionStore.upsert(draft)
    }

    @ViewBuilder
    private func variantTitleBlock(for test: TestVariant) -> some View {
        let trimmed = test.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let v = test.variant
        if trimmed.isEmpty {
            Text(verbatim: "Вариант \(v)")
                                        .font(.custom("MontserratAlternates-Medium", size: 16))
                .foregroundStyle(Color(.darkAccent))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(verbatim: "\(trimmed) · вариант \(v)")
                                            .font(.custom("MontserratAlternates-Medium", size: 16))
                .foregroundStyle(Color(.darkAccent))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hintAllowed(for question: Question) -> Bool {
        let trimmed = question.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return false }
        return userSettings.maxHintsPerTest != 0
    }

    private var hintButtonEnabled: Bool {
        let cap = userSettings.maxHintsPerTest
        if cap < 0 { return true }
        if cap == 0 { return false }
        return hintsUsedThisSession < cap
    }

    /// Компактный счётчик подсказок в строке с прогрессом (осталось/всего; без лимита — «∞»).
    private var hintQuotaInline: String {
        let cap = userSettings.maxHintsPerTest
        if cap < 0 { return "∞" }
        let left = max(0, cap - hintsUsedThisSession)
        return "\(left)/\(cap)"
    }

    private func openHintSheet() {
        guard hintButtonEnabled else { return }
        ExamixKeyboard.dismiss()
        hintsUsedThisSession += 1
        showHintSheet = true
    }

    @ViewBuilder
    private func practiceResultPanel(result: TestResult) -> some View {
        ResultSummaryView(
            correctAnswers: result.correctAnswers,
            totalQuestions: result.totalQuestions,
            partialAnswers: viewModel.partialCount(for: result)
        ) {
            practiceOnFinished?()
        }
    }

    @ViewBuilder
    private func practiceInlineFeedbackPanel(result: TestResult) -> some View {
        let ok = result.correctAnswers == result.totalQuestions
        let partial = viewModel.partialCount(for: result)
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                Text(ok ? "✓" : (partial > 0 ? "±" : "✗"))
                    .font(.custom("MontserratAlternates-Bold", size: 36))
                    .foregroundColor(ok ? .green : (partial > 0 ? .orange : .red))
                VStack(alignment: .leading, spacing: 4) {
                    Text(ok ? "Верно" : (partial > 0 ? "Частично верно" : "Неверно"))
                        .font(.custom("MontserratAlternates-Bold", size: 20))
                        .foregroundColor(.darkAccent)
                    Text("Правильно \(result.correctAnswers) из \(result.totalQuestions)")
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ok ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ok ? Color.green.opacity(0.35) : Color.orange.opacity(0.4), lineWidth: 1)
                    )
            )

            Button(action: { practiceOnFinished?() }) {
                Text("Далее")
                    .font(.custom("MontserratAlternates-SemiBold", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [ExamixStyle.accentCool, ExamixStyle.accentDeep.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: ExamixStyle.accentCool.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private func toggleBookmark(_ question: Question, test: TestVariant) async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let bookmarkId = "\(question.id)_\(test.variant)_\(test.language)"
            let docRef = Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmarkId)
            
            let snapshot = try await docRef.getDocument()
            
            if snapshot.exists {
                try await docRef.delete()
                await MainActor.run {
                    isBookmarked = false
                }
            } else {
                try await BookmarkService().addBookmark(
                    question,
                    language: test.language,
                    variant: test.variant,
                    for: userId,
                    userTextAnswer: viewModel.textAnswers[question.id],
                    userSelectedOptions: viewModel.selectedOptions[question.id]?.map(\.text) ?? []
                )
                await MainActor.run {
                    isBookmarked = true
                    showBookmarkToast = true
                }
            }
        } catch {
            print("Ошибка при переключении закладки: \(error)")
        }
    }
    
    private func checkIfBookmarked(_ question: Question, test: TestVariant) async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let bookmarkId = "\(question.id)_\(test.variant)_\(test.language)"
            let docRef = Firestore.firestore()
                .collection("users").document(userId)
                .collection("bookmarks").document(bookmarkId)
            
            let snapshot = try await docRef.getDocument()
            await MainActor.run {
                isBookmarked = snapshot.exists
            }
        } catch {
            print("Ошибка при проверке закладки: \(error)")
            await MainActor.run {
                isBookmarked = false
            }
        }
    }
}

#Preview {
    ResultSummaryView(correctAnswers: 8, totalQuestions: 10, partialAnswers: 2) {
        print("Продолжить")
    }
}
