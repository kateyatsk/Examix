//
//  ContributionHeatmapView.swift
//  Examix
//
//  Карта активности: интенсивность = сумма верно решённых заданий за день
//  по сохранённым результатам тестов. Тап — список тестов за день.
//

import SwiftUI

private struct ContributionDaySelection: Identifiable {
    let id: String
    let date: Date
    let results: [TestResult]

    var title: String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    var totalCorrect: Int {
        results.reduce(0) { $0 + $1.correctAnswers }
    }
}

enum ContributionHeatmapPanelStyle {
    /// Собственный тёмный фон и обводка.
    case standalone
    /// Без внешней рамки — встроена в общую панель активности.
    case embedded
}

struct ContributionHeatmapView: View {
    let results: [TestResult]
    var panelStyle: ContributionHeatmapPanelStyle = .standalone

    @State private var selection: ContributionDaySelection?
    /// Базовый множитель размера клеток (ползунок + итог щипка).
    @State private var gridZoom: CGFloat = 1.35
    @GestureState private var pinchMagnification: CGFloat = 1.0

    private let weeksShown = 53
    private let baseCell: CGFloat = 12
    private let baseGap: CGFloat = 3

    private var effectiveZoom: CGFloat {
        min(max(gridZoom * pinchMagnification, 0.75), 3.5)
    }

    private var cellSide: CGFloat { baseCell * effectiveZoom }
    private var cellGap: CGFloat { max(2, baseGap * effectiveZoom) }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchMagnification) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let next = min(max(gridZoom * value, 0.75), 3.5)
                gridZoom = next
            }
    }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Пн — первая строка сетки
        return c
    }

    private var grid: ContributionGrid {
        ContributionGrid.build(results: results, calendar: calendar, weeks: weeksShown)
    }

    private var heatTitleColor: Color { Color(.darkAccent) }
    private var heatBodyColor: Color { Color.secondary }
    private var heatFaintColor: Color { Color.secondary.opacity(0.75) }

    var body: some View {
        let core = VStack(alignment: .leading, spacing: 14) {
            Text("Активность")
                .font(.custom("MontserratAlternates-Bold", size: 18))
                .foregroundColor(heatTitleColor)

            Text("Интенсивность цвета — сколько заданий решено верно за день. Нажмите на квадрат, чтобы открыть список.")
                .font(.custom("MontserratAlternates-Regular", size: 12))
                .foregroundColor(heatBodyColor)

            Text("Разведите или сведите два пальца на сетке — масштаб. Ниже — ползунок.")
                .font(.custom("MontserratAlternates-Regular", size: 11))
                .foregroundColor(heatFaintColor)

            zoomControls

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 10) {
                    weekdayLabels

                    VStack(alignment: .leading, spacing: 6 * effectiveZoom / 1.35) {
                        monthRow
                        HStack(alignment: .top, spacing: cellGap) {
                            ForEach(0..<grid.weekCount, id: \.self) { week in
                                weekColumn(weekIndex: week)
                            }
                        }
                    }
                }
                .padding(.trailing, 8)
                .simultaneousGesture(pinchGesture)
            }
            .frame(minHeight: (cellSide + cellGap) * 7 + 24 * effectiveZoom / 1.35)

            legend

            Text("Учитываются сохранённые результаты (верные ответы за календарный день).")
                .font(.system(size: 10))
                .foregroundColor(heatFaintColor)
        }

        Group {
            switch panelStyle {
            case .standalone:
                core
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        ExamixStyle.softProfileCard,
                                        Color(red: 0.90, green: 0.94, blue: 0.99)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        ExamixStyle.accentCool.opacity(0.35),
                                        ExamixStyle.accentMuted.opacity(0.28)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            case .embedded:
                core
                    .padding(.top, 4)
            }
        }
        .sheet(item: $selection) { day in
            ContributionDayListSheet(selection: day)
        }
    }

    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: cellGap) {
            Text("")
                .font(.system(size: 9))
                .frame(height: 14 * effectiveZoom / 1.35)
            ForEach(0..<7, id: \.self) { row in
                Text(ContributionGrid.rowLabel(row: row))
                    .font(.system(size: max(9, 9 * effectiveZoom / 1.35), weight: .medium))
                    .foregroundColor(row % 2 == 0 ? heatBodyColor : heatFaintColor)
                    .frame(width: max(32, cellSide * 2.2), height: cellSide, alignment: .trailing)
            }
        }
    }

    private var monthRow: some View {
        HStack(spacing: cellGap) {
            ForEach(0..<grid.weekCount, id: \.self) { week in
                Text(grid.monthLabel(atWeek: week))
                    .font(.system(size: max(8, 9 * effectiveZoom / 1.35), weight: .medium))
                    .foregroundColor(heatBodyColor)
                    .frame(width: cellSide, height: 14 * effectiveZoom / 1.35, alignment: .leading)
            }
        }
    }

    private func weekColumn(weekIndex: Int) -> some View {
        VStack(spacing: cellGap) {
            ForEach(0..<7, id: \.self) { row in
                let cell = grid.cell(week: weekIndex, row: row)
                ContributionCellView(level: cell.level, isFuture: cell.isFuture)
                    .frame(width: cellSide, height: cellSide)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !cell.isFuture, !cell.results.isEmpty else { return }
                        let key = ContributionGrid.dayKey(cell.date)
                        selection = ContributionDaySelection(id: key, date: cell.date, results: cell.results)
                    }
                    .accessibilityLabel(accessibilityLabel(for: cell))
            }
        }
    }

    private func accessibilityLabel(for cell: ContributionCell) -> String {
        if cell.isFuture { return "Будущая дата" }
        if cell.results.isEmpty { return "Нет активности" }
        let n = cell.results.reduce(0) { $0 + $1.correctAnswers }
        return "\(cell.date.formatted(date: .abbreviated, time: .omitted)), верно решено заданий: \(n)"
    }

    private var legend: some View {
        HStack {
            Spacer()
            Text("Меньше")
                .font(.system(size: 10))
                .foregroundColor(heatBodyColor)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(ContributionPalette.color(level: i))
                        .frame(width: 11, height: 11)
                }
            }
            Text("Больше")
                .font(.system(size: 10))
                .foregroundColor(heatBodyColor)
        }
        .padding(.top, 4)
    }

    private var zoomControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Масштаб")
                    .font(.custom("MontserratAlternates-Medium", size: 13))
                    .foregroundColor(heatTitleColor)
                Spacer()
                Text("\(Int((effectiveZoom * 100).rounded()))%")
                    .font(.custom("MontserratAlternates-Bold", size: 13))
                    .foregroundColor(ExamixStyle.accentCool)
                    .monospacedDigit()
            }
            HStack(spacing: 10) {
                Button {
                    gridZoom = max(0.75, gridZoom - 0.2)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(ExamixStyle.accentCool.opacity(0.75))
                }
                .accessibilityLabel("Уменьшить")

                Slider(value: $gridZoom, in: 0.75...3.5, step: 0.05)
                    .tint(ExamixStyle.accentCool)

                Button {
                    gridZoom = min(3.5, gridZoom + 0.2)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(ExamixStyle.accentCool.opacity(0.75))
                }
                .accessibilityLabel("Увеличить")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

private enum ContributionPalette {
    /// Светло-синяя шкала в духе `ExamixStyle` (без тёмно-зелёной сетки).
    static func color(level: Int) -> Color {
        switch level {
        case 0:
            return Color(red: 0.93, green: 0.95, blue: 0.99)
        case 1:
            return Color(red: 0.78, green: 0.86, blue: 0.97)
        case 2:
            return Color(red: 0.58, green: 0.74, blue: 0.92)
        case 3:
            return Color(red: 0.40, green: 0.62, blue: 0.86)
        default:
            return Color(red: 0.28, green: 0.50, blue: 0.78)
        }
    }
}

private struct ContributionCellView: View {
    let level: Int
    let isFuture: Bool

    private var futureFill: Color {
        Color(red: 0.88, green: 0.91, blue: 0.97)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isFuture ? futureFill : ContributionPalette.color(level: level))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(
                        ExamixStyle.accentCool.opacity(isFuture ? 0.12 : 0.18),
                        lineWidth: 0.5
                    )
            )
    }
}

private struct ContributionCell {
    let date: Date
    let level: Int
    let results: [TestResult]
    let isFuture: Bool
}

private struct ContributionGrid {
    let weekCount: Int
    private let cells: [[ContributionCell]]

    init(weekCount: Int, cells: [[ContributionCell]]) {
        self.weekCount = weekCount
        self.cells = cells
    }

    static func rowLabel(row: Int) -> String {
        let labels = ["Пн", "", "Ср", "", "Пт", "", "Вс"]
        guard row >= 0, row < labels.count else { return "" }
        return labels[row]
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func build(results: [TestResult], calendar: Calendar, weeks: Int) -> ContributionGrid {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let oldestMonday = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: thisMonday) else {
            return ContributionGrid(weekCount: weeks, cells: emptyCells(weeks: weeks, today: today))
        }

        let byDay = aggregate(results: results, calendar: calendar)
        let maxCount = byDay
            .filter { $0.key >= oldestMonday && $0.key <= today }
            .values
            .map(dayTotalCorrect)
            .max() ?? 0

        var cols: [[ContributionCell]] = []
        for week in 0..<weeks {
            var col: [ContributionCell] = []
            for row in 0..<7 {
                let d = calendar.date(byAdding: .day, value: week * 7 + row, to: oldestMonday) ?? today
                let start = calendar.startOfDay(for: d)
                let isFuture = start > today
                let list = byDay[start] ?? []
                let count = dayTotalCorrect(list)
                let level = isFuture ? 0 : intensityLevel(count: count, maxCount: maxCount)
                col.append(ContributionCell(date: start, level: level, results: list, isFuture: isFuture))
            }
            cols.append(col)
        }
        return ContributionGrid(weekCount: weeks, cells: cols)
    }

    private static func emptyCells(weeks: Int, today: Date) -> [[ContributionCell]] {
        (0..<weeks).map { _ in
            (0..<7).map { _ in
                ContributionCell(date: today, level: 0, results: [], isFuture: false)
            }
        }
    }

    private static func aggregate(results: [TestResult], calendar: Calendar) -> [Date: [TestResult]] {
        var dict: [Date: [TestResult]] = [:]
        for r in results {
            let k = calendar.startOfDay(for: r.timestamp)
            dict[k, default: []].append(r)
        }
        return dict
    }

    private static func dayTotalCorrect(_ list: [TestResult]) -> Int {
        list.reduce(0) { $0 + $1.correctAnswers }
    }

    private static func intensityLevel(count: Int, maxCount: Int) -> Int {
        guard count > 0 else { return 0 }
        guard maxCount > 0 else { return 1 }
        let scaled = 4.0 * Double(count) / Double(maxCount)
        return min(4, max(1, Int(ceil(scaled))))
    }

    func cell(week: Int, row: Int) -> ContributionCell {
        guard week >= 0, week < cells.count, row < 7 else {
            return ContributionCell(date: Date(), level: 0, results: [], isFuture: false)
        }
        return cells[week][row]
    }

    func monthLabel(atWeek week: Int) -> String {
        guard week < cells.count, let first = cells[week].first?.date else { return "" }
        if week == 0 { return Self.monthShort(first) }
        guard week > 0, let prev = cells[week - 1].first?.date else { return Self.monthShort(first) }
        let m = Calendar.current.component(.month, from: first)
        let pm = Calendar.current.component(.month, from: prev)
        return m != pm ? Self.monthShort(first) : ""
    }

    private static func monthShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.setLocalizedDateFormatFromTemplate("MMM")
        return f.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}

private struct ContributionDayListSheet: View {
    let selection: ContributionDaySelection
    @Environment(\.dismiss) private var dismiss

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Верно решено заданий за день: \(selection.totalCorrect)")
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                        .foregroundColor(.secondary)
                }

                Section("Тесты") {
                    ForEach(selection.results.sorted { $0.timestamp > $1.timestamp }) { r in
                        NavigationLink {
                            ResultDetailView(result: r)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Вариант \(r.variant)")
                                        .font(.custom("MontserratAlternates-Bold", size: 16))
                                    Spacer()
                                    Text("\(r.correctAnswers)/\(r.totalQuestions)")
                                        .font(.custom("MontserratAlternates-Medium", size: 14))
                                        .foregroundColor(.secondaryBlue)
                                }
                                Text(r.language)
                                    .font(.custom("MontserratAlternates-Regular", size: 13))
                                    .foregroundColor(.secondary)
                                Text(Self.timeFormatter.string(from: r.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Подробные результаты")
                                    .font(.custom("MontserratAlternates-Medium", size: 12))
                                    .foregroundColor(.secondaryBlue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(selection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
