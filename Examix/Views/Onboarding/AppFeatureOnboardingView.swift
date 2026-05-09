//
//  AppFeatureOnboardingView.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import SwiftUI
import UIKit


private enum OnboardingFont {
    static let nameRegular = "MontserratAlternates-Regular"
    static let nameMedium = "MontserratAlternates-Medium"
    static let nameBold = "MontserratAlternates-Bold"

    static func regular(_ size: CGFloat) -> Font { .custom(nameRegular, size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom(nameMedium, size: size) }
    static func semiBold(_ size: CGFloat) -> Font { .custom(nameMedium, size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom(nameBold, size: size) }
}


enum OnboardingIllustrationAsset: String, CaseIterable {
    case welcome = "onboardingWelcome"
    case home = "onboardingHome"
    case test = "onboardingTest"
    case results = "onboardingResults"
    case profile = "onboardingProfile"
    case settings = "onboardingSettings"
}

private struct FeatureOnboardingPage {
    let illustrationAsset: OnboardingIllustrationAsset
    let title: String
    let subtitle: String
    let bullets: [String]
    let gradient: [Color]
}


private struct OnboardingIllustrationSlot: View {
    let asset: OnboardingIllustrationAsset
    let accentGradient: [Color]
    let side: CGFloat

    private var hasRasterAsset: Bool {
        UIImage(named: asset.rawValue) != nil
    }

    private var corner: CGFloat { min(20, side * 0.11) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

            if hasRasterAsset {
                Image(asset.rawValue)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .padding(side * 0.06)
            } else {
                ZStack {
                    OnboardingIllustrationPlaceholder(accent: accentGradient, side: side)
                    VStack {
                        Spacer()
                        Text("1024 × 1024")
                            .font(OnboardingFont.medium(10))
                            .foregroundStyle(.white.opacity(0.55))
                            .tracking(0.8)
                            .padding(.bottom, side * 0.08)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

private struct OnboardingIllustrationPlaceholder: View {
    let accent: [Color]
    let side: CGFloat

    private var c0: Color { accent.first ?? ExamixStyle.accentCool }
    private var c1: Color { accent.count > 1 ? accent[1] : ExamixStyle.accentMuted }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [c0.opacity(0.45), c1.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: side * 0.62, height: side * 0.62)
                .offset(x: -side * 0.06, y: side * 0.04)

            Circle()
                .stroke(Color.white.opacity(0.45), lineWidth: 2)
                .frame(width: side * 0.36, height: side * 0.36)
                .offset(x: side * 0.14, y: -side * 0.1)

            RoundedRectangle(cornerRadius: side * 0.08, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: side * 0.28, height: side * 0.22)
                .rotationEffect(.degrees(-12))
                .offset(x: side * 0.12, y: side * 0.12)
        }
    }
}

private enum OnboardingLayout {
    static let squareMax: CGFloat = 194
    static let heroVerticalPad: CGFloat = 16
    static let screenHorizontal: CGFloat = 22
    static let skipTop: CGFloat = 14
    static let cardPadding: CGFloat = 18
    static let heroCorner: CGFloat = 28
    static let cardCorner: CGFloat = 24
    static let buttonCorner: CGFloat = 18
}

struct AppFeatureOnboardingView: View {
    var onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages: [FeatureOnboardingPage] = [
        FeatureOnboardingPage(
            illustrationAsset: .welcome,
            title: "Учись спокойнее",
            subtitle: "Examix помогает готовиться к экзаменам: полные варианты, практика и статистика в одном месте.",
            bullets: [
                "Решайте задания как на реальном экзамене",
                "Закрепляйте слабые темы короткими сессиями",
                "Следите за прогрессом по дням и предметам"
            ],
            gradient: [
                Color(red: 0.22, green: 0.38, blue: 0.62),
                Color(red: 0.32, green: 0.52, blue: 0.78)
            ]
        ),
        FeatureOnboardingPage(
            illustrationAsset: .home,
            title: "Все сценарии рядом",
            subtitle: "Быстрая практика, полные варианты и черновики — на главном экране.",
            bullets: [
                "«Задание дня» — короткая сессия каждый день",
                "Полные варианты и практика по темам",
                "Черновики и статистика всегда под рукой"
            ],
            gradient: ExamixStyle.practiceThemesGradientColors
        ),
        FeatureOnboardingPage(
            illustrationAsset: .test,
            title: "Решай без лишнего стресса",
            subtitle: "Во время решения доступны подсказки и закладки.",
            bullets: [
                "Лимит подсказок настраивается в разделе «Настройки»",
                "Сохраняйте сложные вопросы в закладки для повторения",
                "После завершения откроется сводка и разбор ответов"
            ],
            gradient: [
                Color(red: 0.18, green: 0.44, blue: 0.55),
                Color(red: 0.28, green: 0.58, blue: 0.62)
            ]
        ),
        FeatureOnboardingPage(
            illustrationAsset: .results,
            title: "Отслеживай свой прогресс",
            subtitle: "Вся история: экзамены и сессии практики.",
            bullets: [
                "Фильтры по языку, периоду и источнику (вариант / практика)",
                "Поиск по варианту, предмету и деталям практики",
                "Карточка сессии раскрывается на отдельные задания",
                "Внутри — процент, кольцевая диаграмма и подробный разбор"
            ],
            gradient: [
                Color(red: 0.26, green: 0.34, blue: 0.68),
                Color(red: 0.42, green: 0.48, blue: 0.85)
            ]
        ),
        FeatureOnboardingPage(
            illustrationAsset: .profile,
            title: "Собирай достижения",
            subtitle: "Обзор успехов и быстрый доступ к закладкам.",
            bullets: [
                "Средняя точность по полным вариантам и по предметам",
                "Теплокарта активности по календарным дням",
                "Раздел «Закладки» — все сохранённые вопросы с фильтрами"
            ],
            gradient: [
                Color(red: 0.12, green: 0.42, blue: 0.52),
                Color(red: 0.22, green: 0.55, blue: 0.58)
            ]
        ),
        FeatureOnboardingPage(
            illustrationAsset: .settings,
            title: "Настрой под себя",
            subtitle: "Персонализация и справочные материалы.",
            bullets: [
                "Аватар и имя отображаются в профиле",
                "Предмет обучения влияет на каталог вариантов и практику",
                "Подсказки и PDF с правилами для выбранного предмета",
                "Обзор приложения можно открыть здесь в любой момент"
            ],
            gradient: [
                Color(red: 0.20, green: 0.36, blue: 0.58),
                Color(red: 0.35, green: 0.50, blue: 0.72)
            ]
        )
    ]

    private var isLastPage: Bool {
        pageIndex >= pages.count - 1
    }

    private var currentPage: FeatureOnboardingPage {
        pages[min(max(pageIndex, 0), pages.count - 1)]
    }

    private var currentButtonGradient: LinearGradient {
        LinearGradient(
            colors: currentPage.gradient.map { $0.opacity(0.98) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ExamixStyle.screenCanvas,
                    Color(red: 0.86, green: 0.91, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    ExamixStyle.accentCool.opacity(0.12),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 340
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        finish()
                    } label: {
                        Text("Пропустить")
                            .font(OnboardingFont.medium(14))
                            .foregroundStyle(Color(.darkAccent).opacity(0.62))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.56))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                }
                .padding(.horizontal, OnboardingLayout.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageCard(page)
                            .tag(index)
                            .padding(.horizontal, OnboardingLayout.screenHorizontal)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: pageIndex)

                pageIndicator
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                VStack(spacing: 10) {
                    Button {
                        if isLastPage {
                            finish()
                        } else {
                            withAnimation {
                                pageIndex += 1
                            }
                        }
                    } label: {
                        Text(isLastPage ? "Начать" : "Далее")
                            .font(OnboardingFont.semiBold(17))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: OnboardingLayout.buttonCorner, style: .continuous)
                                    .fill(currentButtonGradient)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OnboardingLayout.buttonCorner, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .shadow(color: currentPage.gradient[0].opacity(0.3), radius: 18, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, OnboardingLayout.screenHorizontal)
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func pageScrollableContent(
        page: FeatureOnboardingPage,
        contentW: CGFloat,
        squareSide: CGFloat
    ) -> some View {
        VStack(alignment: .center, spacing: 14) {
            heroPanel(page: page, contentW: contentW, squareSide: squareSide)
            contentCard(page)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func heroPanel(
        page: FeatureOnboardingPage,
        contentW: CGFloat,
        squareSide: CGFloat
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: OnboardingLayout.heroCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: page.gradient.map { $0.opacity(0.94) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OnboardingLayout.heroCorner, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .frame(width: contentW, height: squareSide + OnboardingLayout.heroVerticalPad * 2)
                .shadow(color: page.gradient[0].opacity(0.28), radius: 18, x: 0, y: 10)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 22, height: 6)
                        Capsule()
                            .fill(Color.white.opacity(0.36))
                            .frame(width: 8, height: 6)
                    }
                    .padding(18)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 86, height: 86)
                        .offset(x: 22, y: 26)
                }

            OnboardingIllustrationSlot(
                asset: page.illustrationAsset,
                accentGradient: page.gradient,
                side: squareSide
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func introContent(_ page: FeatureOnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(page.title)
                .font(OnboardingFont.bold(24))
                .foregroundStyle(Color(.darkAccent))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.subtitle)
                .font(OnboardingFont.medium(15))
                .foregroundStyle(Color(.darkAccent).opacity(0.74))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bulletsContent(_ page: FeatureOnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(page.bullets, id: \.self) { line in
                HStack(alignment: .top, spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(ExamixStyle.chipFill)
                            .frame(width: 22, height: 22)
                        Text("✓")
                            .font(OnboardingFont.bold(10))
                            .foregroundStyle(ExamixStyle.accentDeep)
                    }
                    .padding(.top, 1)

                    Text(line)
                        .font(OnboardingFont.regular(14))
                        .foregroundStyle(Color(.darkAccent).opacity(0.76))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func contentCard(_ page: FeatureOnboardingPage) -> some View {
        onboardingCard {
            VStack(alignment: .leading, spacing: 14) {
                introContent(page)

                Divider()
                    .overlay(Color(.darkAccent).opacity(0.08))

                bulletsContent(page)
            }
        }
    }

    private func onboardingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(OnboardingLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OnboardingLayout.cardCorner, style: .continuous)
                    .fill(ExamixStyle.cardFill)
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingLayout.cardCorner, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), ExamixStyle.accentCool.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func pageCard(_ page: FeatureOnboardingPage) -> some View {
        GeometryReader { geo in
            let contentW = max(geo.size.width, 1)
            let squareSide = min(
                OnboardingLayout.squareMax,
                max(96, contentW - OnboardingLayout.heroVerticalPad * 2)
            )

            ViewThatFits(in: .vertical) {
                pageScrollableContent(page: page, contentW: contentW, squareSide: squareSide)

                ScrollView(.vertical, showsIndicators: false) {
                    pageScrollableContent(page: page, contentW: contentW, squareSide: squareSide)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == pageIndex ? ExamixStyle.accentCool : Color.primary.opacity(0.1))
                    .frame(width: i == pageIndex ? 26 : 6, height: i == pageIndex ? 7 : 6)
                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: pageIndex)
                if i < pages.count - 1 {
                    Spacer()
                        .frame(width: 7)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private func finish() {
        onFinish()
    }
}


enum OnboardingImagePrompts {
    static let sharedStylePrefix = """
    Единый стиль для набора иллюстраций онбординга мобильного приложения Examix (подготовка к языковым экзаменам). \
    Современный плоский или мягкий 2.5D UI-иллюстративный стиль, холодная палитра: сине-бирюзовые, лавандовые и белые тона, без жёлто-коричневых акцентов. \
    Без текста, букв и цифр на картинке. Без логотипов брендов. Светлый воздушный фон или прозрачный (альфа), центральная композиция, хорошо читается в квадрате ~1024×1024. \
    Дружелюбно, минималистично, как в премиальном edtech-приложении.
    """

    static let welcome = sharedStylePrefix + """
     Сцена: абстрактное ощущение старта обучения — мягкое сияние, лёгкие искры или звёздочки, намёк на открытую книгу или тетрадь силуэтом, \
    дорожка прогресса или восходящая дуга. Настроение: вдохновение и начало пути.
    """

    static let home = sharedStylePrefix + """
     Сцена: домашний экран / дашборд в абстрактном виде: карточки-плитки, маленький календарик или метка «день», \
    мини-график тренда, иконка молнии или таймера как «задание дня». Показать ощущение «всё в одном месте», без реального интерфейса приложения.
    """

    static let test = sharedStylePrefix + """
     Сцена: экзаменационный лист или бланк в стилизованном виде, увеличительное стекло над вопросом, \
    маленькая лампочка как подсказка, закладка-ленточка на углу. Акцент на внимательном чтении заданий и помощи во время теста.
    """

    static let results = sharedStylePrefix + """
     Сцена: абстрактные результаты — кольцевая или круговая диаграмма, ряд звёзд или галочек, \
    столбики статистики в мягких цветах, стопка аккуратных карточек. Ощущение подведения итогов и истории попыток.
    """

    static let profile = sharedStylePrefix + """
     Сцена: силуэт пользователя в круге или мягкий аватар-плейсхолдер, рядом абстрактная тепловая сетка из квадратиков (календарь активности), \
    маленькая закладка или лента. Тема: профиль, прогресс во времени и сохранённые материалы.
    """

    static let settings = sharedStylePrefix + """
     Сцена: аккуратная шестерёнка или ползунки настроек в UI-метафоре, рядом флажки как выбор языка (без конкретных государственных флагов — только абстрактные цветные метки), \
    тонкая рамка документа как «правила». Спокойная техническая иллюстрация про персонализацию.
    """
}

extension OnboardingIllustrationAsset {
    var imageGenerationPrompt: String {
        switch self {
        case .welcome: return OnboardingImagePrompts.welcome
        case .home: return OnboardingImagePrompts.home
        case .test: return OnboardingImagePrompts.test
        case .results: return OnboardingImagePrompts.results
        case .profile: return OnboardingImagePrompts.profile
        case .settings: return OnboardingImagePrompts.settings
        }
    }
}

#Preview {
    AppFeatureOnboardingView(onFinish: {})
}
