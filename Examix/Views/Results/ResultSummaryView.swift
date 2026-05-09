//
//  ResultSummaryView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.05.25.
//

import SwiftUI

struct ResultSummaryView: View {
    let correctAnswers: Int
    let totalQuestions: Int
    let partialAnswers: Int
    let onContinue: () -> Void

    @State private var headlineVisible = false
    @State private var ringProgress: CGFloat = 0
    @State private var statsVisible = false
    @State private var buttonVisible = false
    @State private var glowPulse = false

    private var percentage: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int((Double(correctAnswers) / Double(totalQuestions)) * 100)
    }

    private var encouragement: String {
        switch percentage {
        case 90...100: return "Блестяще!"
        case 75..<90: return "Очень хороший результат"
        case 60..<75: return "Хорошая работа"
        case 40..<60: return "Есть куда расти — вы справились"
        default: return "Главное — вы прошли до конца"
        }
    }

    var body: some View {
        ZStack {
            ExamixStyle.practiceScreenWash
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    ExamixStyle.accentCool.opacity(glowPulse ? 0.22 : 0.12),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            RadialGradient(
                colors: [
                    ExamixStyle.accentMuted.opacity(glowPulse ? 0.14 : 0.08),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 20) {
                    ZStack {
                        ForEach(0..<10, id: \.self) { i in
                            Circle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 4, height: 4)
                                .offset(
                                    x: CGFloat(cos(Double(i) / 10 * .pi * 2)) * 118,
                                    y: CGFloat(sin(Double(i) / 10 * .pi * 2)) * 118
                                )
                                .opacity(headlineVisible ? 0.55 : 0)
                                .scaleEffect(headlineVisible ? 1 : 0.3)
                        }

                        Image(systemName: percentage >= 70 ? "checkmark.seal.fill" : "flag.checkered")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [ExamixStyle.accentCool, ExamixStyle.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: ExamixStyle.accentCool.opacity(0.45), radius: 16, x: 0, y: 6)
                            .scaleEffect(headlineVisible ? 1 : 0.4)
                            .opacity(headlineVisible ? 1 : 0)
                    }
                    .frame(height: 96)

                    VStack(spacing: 8) {
                        Text("Тест завершён")
                            .font(.custom("MontserratAlternates-Bold", size: 30))
                            .foregroundStyle(Color(.darkAccent))
                            .multilineTextAlignment(.center)

                        Text(encouragement)
                            .font(.custom("MontserratAlternates-SemiBold", size: 16))
                            .foregroundStyle(ExamixStyle.accentCool)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(headlineVisible ? 1 : 0)
                    .offset(y: headlineVisible ? 0 : 18)

                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 18)
                            .frame(width: 196, height: 196)

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
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 196, height: 196)

                        VStack(spacing: 4) {
                            Text("\(percentage)%")
                                .font(.custom("MontserratAlternates-Bold", size: 40))
                                .foregroundStyle(Color(.darkAccent))
                                .contentTransition(.numericText())
                            Text("точность")
                                .font(.custom("MontserratAlternates-Medium", size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            summaryChip(
                                title: "Верно",
                                value: "\(correctAnswers) / \(totalQuestions)",
                                tint: ExamixStyle.statCorrect
                            )
                            if partialAnswers > 0 {
                                summaryChip(
                                    title: "Частично",
                                    value: "\(partialAnswers)",
                                    tint: ExamixStyle.statPartial
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if partialAnswers > 0 {
                            Text("Частично засчитаны задания с неполным, но допустимым выбором.")
                                .font(.custom("MontserratAlternates-Regular", size: 12))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .opacity(statsVisible ? 1 : 0)
                    .offset(y: statsVisible ? 0 : 14)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                Button(action: onContinue) {
                    Text("Смотреть разбор")
                        .font(.custom("MontserratAlternates-SemiBold", size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            ExamixStyle.accentCool,
                                            ExamixStyle.accentDeep.opacity(0.92)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: ExamixStyle.accentCool.opacity(0.42), radius: 18, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 24)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
                headlineVisible = true
            }
            withAnimation(.easeOut(duration: 1.05).delay(0.12)) {
                ringProgress = CGFloat(percentage) / 100
            }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86).delay(0.35)) {
                statsVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.88).delay(0.55)) {
                buttonVisible = true
            }
        }
    }

    private func summaryChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.custom("MontserratAlternates-Medium", size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("MontserratAlternates-SemiBold", size: 16))
                .foregroundStyle(Color(.darkAccent))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
