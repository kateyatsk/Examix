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

    private var percentage: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int((Double(correctAnswers) / Double(totalQuestions)) * 100)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Поздравляем!")
                .font(.custom("MontserratAlternates-Bold", size: 28))
                .foregroundColor(.stock)

            Text("Вы завершили тест")
                .font(.custom("MontserratAlternates-Medium", size: 20))
                .foregroundColor(.darkAccent)

            ZStack {
                Circle()
                    .stroke(.secondaryBlue.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: CGFloat(percentage) / 100)
                    .stroke(.stock, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                Text("\(percentage)%")
                    .font(.custom("MontserratAlternates-Bold", size: 32))
                    .foregroundColor(.stock)
            }

            VStack(spacing: 4) {
                Text("Правильных ответов: \(correctAnswers) из \(totalQuestions)")
                    .font(.custom("MontserratAlternates-Medium", size: 18))
                    .foregroundColor(.darkAccent)

                if partialAnswers > 0 {
                    Text("Из них частично верных: \(partialAnswers)")
                        .font(.custom("MontserratAlternates-Medium", size: 16))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Продолжить")
                    .font(.custom("MontserratAlternates-Medium", size: 16))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.stock))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding()
    }
}
