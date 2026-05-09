//
//  TestViewLoader.swift
//  Examix
//
//  Created by Kate Yatskevich on 4.05.25.
//

import SwiftUI

struct TestViewLoader: View {
    let language: String
    var variant: Int? = nil

    @EnvironmentObject private var userSettings: UserSettings
    @StateObject private var viewModel = TestViewModel()
    @State private var error: String? = nil
    @State private var loadingTask: Task<Void, Never>? = nil
    @State private var interruptedDraft: PendingTestSession?
    @State private var fetchedVariant: TestVariant?
    @State private var interruptOverlay: InterruptOverlayPhase = .none

    private enum InterruptOverlayPhase: Equatable {
        case none
        case resumeChoice
        case confirmDiscardDraft
    }

    var body: some View {
        Group {
            if let _ = viewModel.test {
                TestView(viewModel: viewModel)
            } else if let error = error {
                ZStack {
                    ExamixStyle.practiceScreenWash
                        .ignoresSafeArea()
                    Text("Ошибка: \(error)")
                        .font(.custom("MontserratAlternates-Medium", size: 15))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.95))
                                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                        )
                        .padding(.horizontal, 24)
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
        .overlay {
            interruptOverlayContent
        }
        .task {
            if viewModel.test == nil {
                loadingTask?.cancel()
                loadingTask = Task {
                    await loadTest()
                }
            }
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }

    @ViewBuilder
    private var interruptOverlayContent: some View {
        switch interruptOverlay {
        case .none:
            EmptyView()
        case .resumeChoice:
            if interruptedDraft != nil, fetchedVariant != nil {
                ExamixModalChoiceOverlay(
                    title: "Незаконченный тест",
                    message: "Вы остановились на этом варианте. Продолжить с сохранённого места или начать заново?",
                    actions: [
                        ExamixModalChoiceAction(id: "continue", title: "Продолжить", role: nil) {
                            applyResumeChoice()
                        },
                        ExamixModalChoiceAction(id: "restart", title: "Начать сначала", role: .cancel) {
                            interruptOverlay = .confirmDiscardDraft
                        }
                    ]
                )
            }
        case .confirmDiscardDraft:
            if let draft = interruptedDraft, fetchedVariant != nil {
                ExamixModalChoiceOverlay(
                    title: "Удалить черновик?",
                    message: "Сохранённый прогресс по варианту «\(draft.displayTitleLine)» будет удалён без восстановления.",
                    actions: [
                        ExamixModalChoiceAction(id: "back", title: "Назад", role: .cancel) {
                            interruptOverlay = .resumeChoice
                        },
                        ExamixModalChoiceAction(id: "delete", title: "Удалить и начать заново", role: .destructive) {
                            discardDraftAndStartFresh(draft: draft)
                        }
                    ]
                )
            }
        }
    }

    private func applyResumeChoice() {
        guard let draft = interruptedDraft, let fetched = fetchedVariant else { return }
        viewModel.setTest(
            fetched,
            persistToFirestore: true,
            entrySource: nil,
            practiceDetail: nil,
            uiLearningLanguage: userSettings.selectedLanguage?.rawValue
        )
        viewModel.applyPendingResume(draft)
        interruptedDraft = nil
        fetchedVariant = nil
        interruptOverlay = .none
    }

    private func discardDraftAndStartFresh(draft: PendingTestSession) {
        guard let fetched = fetchedVariant else { return }
        PendingTestSessionStore.remove(id: draft.id)
        viewModel.setTest(
            fetched,
            persistToFirestore: true,
            entrySource: nil,
            practiceDetail: nil,
            uiLearningLanguage: userSettings.selectedLanguage?.rawValue
        )
        interruptedDraft = nil
        fetchedVariant = nil
        interruptOverlay = .none
    }

    private func loadTest() async {
        do {
            let catalog = VariantCatalogService.shared
            let uiLang = userSettings.selectedLanguage?.rawValue ?? ""

            if let variant = variant {
                let fetched = try await catalog.fetchTest(uiLanguage: language, variant: variant)
                let sid = PendingTestSession.storageId(examLanguage: fetched.language, variant: fetched.variant, uiLearningLanguage: uiLang)
                if let draft = PendingTestSessionStore.load(id: sid), draft.hasMeaningfulProgress {
                    await MainActor.run {
                        self.fetchedVariant = fetched
                        self.interruptedDraft = draft
                        self.interruptOverlay = .resumeChoice
                    }
                    return
                }
                await MainActor.run {
                    viewModel.setTest(
                        fetched,
                        persistToFirestore: true,
                        entrySource: nil,
                        practiceDetail: nil,
                        uiLearningLanguage: userSettings.selectedLanguage?.rawValue
                    )
                }
            } else {
                let lang = language
                let fetched = try await Task.detached(priority: .userInitiated) { @Sendable in
                    try VariantCatalogService.shared.fetchRandomTest(uiLanguage: lang)
                }.value
                guard let fetched else {
                    await MainActor.run {
                        self.error = "Нет вариантов в локальной базе для этого языка. Добавьте в таргет Examix JSON экспорта ЦТ (поля variantId, subjectCode, tasks). Файл может лежать в группе Examix или в папке CTVariants."
                    }
                    return
                }
                let sid = PendingTestSession.storageId(examLanguage: fetched.language, variant: fetched.variant, uiLearningLanguage: uiLang)
                if let draft = PendingTestSessionStore.load(id: sid), draft.hasMeaningfulProgress {
                    await MainActor.run {
                        self.fetchedVariant = fetched
                        self.interruptedDraft = draft
                        self.interruptOverlay = .resumeChoice
                    }
                    return
                }
                await MainActor.run {
                    viewModel.setTest(
                        fetched,
                        persistToFirestore: true,
                        entrySource: nil,
                        practiceDetail: nil,
                        uiLearningLanguage: userSettings.selectedLanguage?.rawValue
                    )
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}
