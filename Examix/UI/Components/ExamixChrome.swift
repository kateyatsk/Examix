//
//  ExamixChrome.swift
//  Examix
//
//  Общие визуальные элементы: холодная палитра без акцента stock («жёлто-коричневого»).
//

import SwiftUI
import Charts

enum ExamixStyle {
    /// Холодный фон экрана (вместо тёплого cream `lightBack`).
    static let screenCanvas = Color(red: 0.92, green: 0.93, blue: 0.96)
    /// Карточка как в «Подробных ответах» (`systemBackground`).
    static let cardFill = Color(.systemBackground)
    /// Единая тёмная панель с теплокартой активности.
    static let activityPanel = Color(red: 0.09, green: 0.11, blue: 0.14)
    /// Мягкая карточка профиля (не чистый белый и не тёмная панель).
    static let softProfileCard = Color(red: 0.94, green: 0.96, blue: 0.99)

    static let accentDeep = Color(.darkAccent)
    static let accentCool = Color(red: 0.30, green: 0.50, blue: 0.60)
    static let accentMuted = Color(.secondaryBlue)

    // MARK: Градиенты как на главной («По темам» / «По типу»)

    static let practiceThemesGradientColors: [Color] = [
        Color(red: 0.25, green: 0.42, blue: 0.62),
        Color(red: 0.38, green: 0.55, blue: 0.78)
    ]

    static let practiceTypesGradientColors: [Color] = [
        Color(red: 0.22, green: 0.48, blue: 0.52),
        Color(red: 0.32, green: 0.62, blue: 0.58)
    ]

    static var practiceThemesGradient: LinearGradient {
        LinearGradient(
            colors: practiceThemesGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var practiceTypesGradient: LinearGradient {
        LinearGradient(
            colors: practiceTypesGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Мягкий «голубой» фон в духе экранов практики (типы / темы).
    static var practiceScreenWash: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.96, blue: 1.0),
                Color(red: 0.90, green: 0.94, blue: 0.99),
                screenCanvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Полоска / обводка строки «Результаты»

    private static func languageStudyAccentPair(uiLearningLanguage: String?, examVariantLanguage: String) -> (Color, Color) {
        let key = (uiLearningLanguage ?? examVariantLanguage).lowercased()
        if key.contains("беларус") {
            return (
                Color(red: 0.10, green: 0.55, blue: 0.42),
                Color(red: 0.28, green: 0.72, blue: 0.55)
            )
        }
        if key.contains("русск") {
            return (
                Color(red: 0.20, green: 0.36, blue: 0.72),
                Color(red: 0.40, green: 0.55, blue: 0.88)
            )
        }
        if key.contains("англ") || key.contains("english") {
            return (
                Color(red: 0.28, green: 0.32, blue: 0.62),
                Color(red: 0.44, green: 0.48, blue: 0.82)
            )
        }
        return (accentCool, accentMuted)
    }

    /// Цвета вертикальной полоски: практика (день / тема / тип) или оттенок по языку обучения / языку варианта.
    static func resultStripeColors(entrySource: String?, uiLearningLanguage: String?, examVariantLanguage: String) -> [Color] {
        switch entrySource {
        case "practice_daily":
            return [
                Color(red: 0.12, green: 0.42, blue: 0.38),
                Color(red: 0.28, green: 0.62, blue: 0.52)
            ]
        case "practice_theme":
            return practiceThemesGradientColors
        case "practice_type":
            return practiceTypesGradientColors
        default:
            let p = languageStudyAccentPair(uiLearningLanguage: uiLearningLanguage, examVariantLanguage: examVariantLanguage)
            return [p.0, p.1]
        }
    }

    static var chartLine: LinearGradient {
        LinearGradient(
            colors: [accentDeep, accentCool, accentMuted],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var chartFill: LinearGradient {
        LinearGradient(
            colors: [accentCool.opacity(0.28), accentMuted.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var squircleFill: LinearGradient {
        LinearGradient(
            colors: [accentDeep.opacity(0.95), accentCool.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Статистика ответов: зелёный / холодный «частично» / приглушённый красный.
    static let statCorrect = Color(red: 0.14, green: 0.52, blue: 0.46)
    static let statPartial = Color(red: 0.34, green: 0.46, blue: 0.62)
    static let statWrong = Color(red: 0.55, green: 0.28, blue: 0.36)

    static var chipFill: LinearGradient {
        LinearGradient(
            colors: [accentMuted.opacity(0.22), accentCool.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Линия графика на тёмном фоне (профиль внутри панели активности).
    static var chartLineOnDark: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.95),
                accentMuted.opacity(0.9),
                accentCool.opacity(0.85)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var chartFillOnDark: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.18), Color.white.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Карточка в стиле «Подробный ответ» (нейтральная обводка)

struct ExamixDetailAnswerChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ExamixStyle.cardFill)
                    .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [ExamixStyle.accentCool.opacity(0.32), Color.gray.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func examixDetailAnswerChrome() -> some View {
        modifier(ExamixDetailAnswerChrome())
    }
}

// MARK: - Иконка в скруглённом квадрате

struct ExamixSquircleIcon: View {
    let systemName: String
    var side: CGFloat = 44
    var iconPointSize: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ExamixStyle.squircleFill)
                .frame(width: side, height: side)
                .shadow(color: ExamixStyle.accentDeep.opacity(0.2), radius: 8, x: 0, y: 4)
            Image(systemName: systemName)
                .font(.system(size: iconPointSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }
}

// MARK: - Кольцевая диаграмма + легенда

struct ExamixStatRingSlice: Identifiable {
    let id: String
    let label: String
    let value: Double
    let color: Color
}

struct ExamixStatRingChart: View {
    let slices: [ExamixStatRingSlice]
    let centerTitle: String
    var centerSubtitle: String?

    private var chartSlices: [ExamixStatRingSlice] {
        slices.filter { $0.value > 0 }
    }

    private var total: Double {
        chartSlices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                if total <= 0 {
                    Circle()
                        .stroke(ExamixStyle.screenCanvas, lineWidth: 8)
                        .frame(width: 108, height: 108)
                    Text("—")
                        .font(.custom("MontserratAlternates-Bold", size: 24))
                        .foregroundStyle(.secondary)
                } else {
                    Chart(chartSlices) { s in
                        SectorMark(
                            angle: .value("Кол-во", s.value),
                            innerRadius: .ratio(0.56),
                            angularInset: 1.4
                        )
                        .cornerRadius(4)
                        .foregroundStyle(s.color)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 118, height: 118)

                    VStack(spacing: 2) {
                        Text(centerTitle)
                            .font(.custom("MontserratAlternates-Bold", size: 17))
                            .foregroundStyle(ExamixStyle.accentDeep)
                        if let sub = centerSubtitle, !sub.isEmpty {
                            Text(sub)
                                .font(.custom("MontserratAlternates-Regular", size: 10))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .frame(width: 54)
                }
            }
            .frame(width: 124, height: 124)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(slices) { s in
                    HStack(spacing: 10) {
                        Capsule()
                            .fill(s.value > 0 ? s.color : s.color.opacity(0.25))
                            .frame(width: 22, height: 6)
                        Text("\(s.label): \(Int(s.value))")
                            .font(.custom("MontserratAlternates-Medium", size: 13))
                            .foregroundStyle(s.value > 0 ? Color(.darkAccent) : Color.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Вертикальные столбики (альтернатива «плоским» барам)

struct ExamixBarStat: Identifiable {
    let id: String
    let title: String
    let value: Double
    let color: Color
}

struct ExamixVerticalBarChart: View {
    let bars: [ExamixBarStat]
    var height: CGFloat = 172

    var body: some View {
        Chart(bars) { b in
            BarMark(
                x: .value("Категория", b.title),
                y: .value("Количество", b.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [b.color.opacity(0.95), b.color.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(10)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.custom("MontserratAlternates-Medium", size: 11))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Радиальный бейдж процента (список результатов)

struct ExamixRadialScoreBadge: View {
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(ExamixStyle.screenCanvas.opacity(0.95), lineWidth: 5)
                .frame(width: 52, height: 52)

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
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 52, height: 52)

            Text("\(percent)")
                .font(.custom("MontserratAlternates-Bold", size: 13))
                .foregroundStyle(Color(.darkAccent))
        }
    }
}

// MARK: - Кастомный диалог (Montserrat, как в остальном приложении)

/// Кнопка для `ExamixModalChoiceOverlay`.
struct ExamixModalChoiceAction: Identifiable {
    let id: String
    let title: String
    var role: ButtonRole? = nil
    let action: () -> Void
}

/// Полупрозрачный фон + карточка с текстом и кнопками (вместо системного `Alert` с чужим шрифтом).
struct ExamixModalChoiceOverlay: View {
    let title: String
    let message: String
    let actions: [ExamixModalChoiceAction]

    private static let buttonFont = Font.custom("MontserratAlternates-SemiBold", size: 16)

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(.custom("MontserratAlternates-Bold", size: 18))
                    .foregroundStyle(Color(.darkAccent))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.custom("MontserratAlternates-Medium", size: 15))
                    .foregroundStyle(Color(.darkAccent).opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(actions) { action in
                        Button {
                            action.action()
                        } label: {
                            Text(action.title)
                                .font(Self.buttonFont)
                                .foregroundStyle(labelColor(for: action.role))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(fillColor(for: action.role))
                                )
                        }
                        .font(Self.buttonFont)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ExamixStyle.accentCool.opacity(0.22), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func labelColor(for role: ButtonRole?) -> Color {
        switch role {
        case .destructive: return Color(red: 0.75, green: 0.2, blue: 0.22)
        case .cancel: return Color(.darkAccent).opacity(0.75)
        default: return .white
        }
    }

    private func fillColor(for role: ButtonRole?) -> Color {
        switch role {
        case .destructive: return Color.red.opacity(0.12)
        case .cancel: return Color.primary.opacity(0.07)
        default:
            return ExamixStyle.accentCool
        }
    }
}
