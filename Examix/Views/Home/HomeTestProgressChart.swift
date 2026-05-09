//
//  HomeTestProgressChart.swift
//  Examix
//
//  Прогресс по тестам на главной: зум меняет видимый интервал по оси X (плотность точек),
//  сдвиг пальцем — панорама по времени.
//

import Charts
import SwiftUI

struct ChartData: Identifiable {
    let id = UUID()
    let date: Date
    let percent: Double
}

enum TestProgressChartBuilder {
    static func points(from results: [TestResult], uiLanguageRaw: String) -> (data: [ChartData], xDomain: ClosedRange<Date>?) {
        let trimmed = uiLanguageRaw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ([], nil) }
        let expectedLanguage = trimmed + " язык"
        let filtered = results.filter {
            $0.language.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == expectedLanguage
        }
        let data = filtered.map {
            ChartData(date: $0.timestamp, percent: Double($0.correctAnswers) / Double(max($0.totalQuestions, 1)) * 100)
        }
        guard let minD = data.map(\.date).min(), let maxD = data.map(\.date).max() else {
            return (data, nil)
        }
        return (data, minD...maxD)
    }
}

/// Карточка графика: масштаб по времени (не scaleEffect всего вида).
struct HomeTestProgressChartCard: View {
    let chartData: [ChartData]
    let fullXDomain: ClosedRange<Date>

    @State private var anchorDate: Date
    @State private var xZoom: CGFloat = 1
    @State private var panChunkTranslation: CGFloat = 0
    @GestureState private var pinchScale: CGFloat = 1

    init(chartData: [ChartData], xScale: ClosedRange<Date>) {
        self.chartData = chartData
        self.fullXDomain = xScale
        let lo = xScale.lowerBound.timeIntervalSince1970
        let hi = xScale.upperBound.timeIntervalSince1970
        let mid = Date(timeIntervalSince1970: (lo + hi) / 2)
        _anchorDate = State(initialValue: mid)
    }

    private var paddedFullDomain: ClosedRange<Date> {
        let lo = fullXDomain.lowerBound
        let hi = fullXDomain.upperBound
        if lo == hi {
            let pad: TimeInterval = 86_400
            return lo.addingTimeInterval(-pad)...hi.addingTimeInterval(pad)
        }
        return fullXDomain
    }

    private var fullSpanSeconds: TimeInterval {
        max(paddedFullDomain.upperBound.timeIntervalSince(paddedFullDomain.lowerBound), 60)
    }

    /// 1 = весь период, больше — крупнее по времени (уже окно).
    private var effectiveXZoom: CGFloat {
        min(max(xZoom * pinchScale, 1), 18)
    }

    private var visibleHalfSeconds: TimeInterval {
        (fullSpanSeconds / 2) / Double(effectiveXZoom)
    }

    private var visibleXDomain: ClosedRange<Date> {
        clampVisibleWindow(anchor: anchorDate, halfWidth: visibleHalfSeconds)
    }

    private func clampVisibleWindow(anchor: Date, halfWidth: TimeInterval) -> ClosedRange<Date> {
        let loBound = paddedFullDomain.lowerBound
        let hiBound = paddedFullDomain.upperBound
        var low = anchor.addingTimeInterval(-halfWidth)
        var high = anchor.addingTimeInterval(halfWidth)
        if low < loBound {
            let shift = loBound.timeIntervalSince(low)
            low = loBound
            high = high.addingTimeInterval(shift)
        }
        if high > hiBound {
            let shift = high.timeIntervalSince(hiBound)
            high = hiBound
            low = low.addingTimeInterval(-shift)
        }
        if low < loBound { low = loBound }
        if high > hiBound { high = hiBound }
        return low...high
    }

    private var yDomain: ClosedRange<Double> {
        let percents = chartData.map(\.percent)
        let minP = percents.min() ?? 0
        let maxP = percents.max() ?? 100
        let yLo = max(0, minP - 10)
        let yHi = min(100, maxP + 10)
        return yLo <= yHi ? yLo...yHi : 0...100
    }

    private var averagePercent: Double {
        let p = chartData.map(\.percent)
        guard !p.isEmpty else { return 0 }
        return p.reduce(0, +) / Double(p.count)
    }

    private var lastPointPercent: Double? {
        chartData.max(by: { $0.date < $1.date })?.percent
    }

    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()

    var body: some View {
        let avg = averagePercent

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Прогресс по тестам")
                        .font(.custom("MontserratAlternates-Bold", size: 17))
                        .foregroundStyle(.white.opacity(0.95))
                    Text("Точность по датам · щипок и ползунок — по оси времени, сдвиг — листать период")
                        .font(.custom("MontserratAlternates-Regular", size: 11))
                        .foregroundStyle(.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "средн. %.0f%%", avg))
                        .font(.custom("MontserratAlternates-Bold", size: 14))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0.95, blue: 1), ExamixStyle.accentCool],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    if let last = lastPointPercent {
                        Text(String(format: "последн. %.0f%%", last))
                            .font(.custom("MontserratAlternates-Medium", size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            GeometryReader { geo in
                let chartW = max(geo.size.width, 1)
                let span = visibleXDomain.upperBound.timeIntervalSince(visibleXDomain.lowerBound)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.05, green: 0.07, blue: 0.12),
                                    Color(red: 0.09, green: 0.11, blue: 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    ExamixStyle.accentCool.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )

                    Chart(chartData.sorted(by: { $0.date < $1.date })) {
                        AreaMark(
                            x: .value("Дата", $0.date),
                            y: .value("Процент", $0.percent)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.75, blue: 0.92).opacity(0.35),
                                    Color(red: 0.1, green: 0.35, blue: 0.55).opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Дата", $0.date),
                            y: .value("Процент", $0.percent)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.95, blue: 1),
                                    ExamixStyle.accentCool
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Дата", $0.date),
                            y: .value("Процент", $0.percent)
                        )
                        .symbolSize(effectiveXZoom > 2.2 ? 120 : 72)
                        .foregroundStyle(Color.white.opacity(0.92))

                        RuleMark(y: .value("Среднее", avg))
                            .foregroundStyle(Color.white.opacity(0.18))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartXScale(domain: visibleXDomain)
                    .chartYScale(domain: yDomain)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: min(5, max(3, Int(effectiveXZoom) + 2)))) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.35, dash: [2, 4]))
                                .foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.35))
                                .foregroundStyle(Color.white.opacity(0.05))
                            AxisValueLabel()
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.42))
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.padding(EdgeInsets(top: 6, leading: 4, bottom: 2, trailing: 4))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 12, coordinateSpace: .local)
                            .onChanged { value in
                                let dx = value.translation.width - panChunkTranslation
                                panChunkTranslation = value.translation.width
                                let secondsVisible = span
                                let deltaSeconds = -(Double(dx) / Double(chartW)) * secondsVisible
                                anchorDate = anchorDate.addingTimeInterval(deltaSeconds)
                            }
                            .onEnded { _ in
                                panChunkTranslation = 0
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .updating($pinchScale) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                let next = min(max(xZoom * value, 1), 18)
                                xZoom = next
                            }
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text(intervalCaption(for: visibleXDomain))
                        .font(.custom("MontserratAlternates-Medium", size: 10))
                        .foregroundStyle(.white.opacity(0.38))
                        .padding(.leading, 12)
                        .padding(.bottom, 6)
                }
            }
            .frame(height: 210)

            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                Slider(value: $xZoom, in: 1...16, step: 0.08)
                    .tint(Color(red: 0.45, green: 0.92, blue: 1))
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.13, blue: 0.22),
                            Color(red: 0.06, green: 0.08, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    ExamixStyle.accentCool.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        )
        .onChange(of: chartData.count) { _, _ in
            let lo = paddedFullDomain.lowerBound.timeIntervalSince1970
            let hi = paddedFullDomain.upperBound.timeIntervalSince1970
            anchorDate = Date(timeIntervalSince1970: (lo + hi) / 2)
            xZoom = 1
        }
    }

    private func intervalCaption(for range: ClosedRange<Date>) -> String {
        let a = Self.chartDateFormatter.string(from: range.lowerBound)
        let b = Self.chartDateFormatter.string(from: range.upperBound)
        let days = max(1, Int(ceil(range.upperBound.timeIntervalSince(range.lowerBound) / 86_400)))
        return "\(a) — \(b) · \(days) дн."
    }
}
