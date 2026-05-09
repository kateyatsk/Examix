//
//  ResultsViewModel.swift
//  Examix
//
//  Created by Kate Yatskevich on 2.05.25.
//

import Foundation

struct LeaderboardUserResult: Identifiable, Equatable {
    let id: String
    let rank: Int
    let userId: String
    let correctAnswers: Int
    let totalQuestions: Int
    let attempts: Int
    let isCurrentUser: Bool

    var accuracy: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int((Double(correctAnswers) / Double(totalQuestions)) * 100)
    }

    var displayName: String {
        if isCurrentUser { return "Вы" }
        let suffix = String(userId.suffix(4)).uppercased()
        return suffix.isEmpty ? "Участник" : "Участник \(suffix)"
    }
}

final class ResultsViewModel: ObservableObject {
    @Published var results: [TestResult] = []
    @Published var leaderboard: [LeaderboardUserResult] = []
    private let firestoreService = FirestoreService()
    
    func loadResults() async {
        do {
            let userId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let fetchedResults = try await firestoreService.fetchResults(for: userId)
            await MainActor.run {
                self.results = fetchedResults
            }
        } catch {
        }
    }

    func loadMonthlyLeaderboard() async {
        do {
            let currentUserId = try AuthenticationManager.shared.getAuthenticatedUser().uid
            let period = Self.currentMonthPeriod()
            let currentUserResults = (try? await firestoreService.fetchResults(for: currentUserId)) ?? []
            let allResults: [TestResult]

            do {
                let fetched = try await firestoreService.fetchResultsForAllUsers(from: period.start, to: period.end)
                allResults = Self.mergedResults(fetched, withCurrentUserResults: currentUserResults)
            } catch {
                allResults = currentUserResults
            }

            let ranked = Self.rankedLeaderboard(
                from: allResults,
                currentUserId: currentUserId,
                start: period.start,
                end: period.end
            )

            await MainActor.run {
                self.leaderboard = ranked
            }
        } catch {
            await MainActor.run {
                self.leaderboard = []
            }
        }
    }

    private static func currentMonthPeriod(calendar: Calendar = .current, now: Date = Date()) -> (start: Date, end: Date) {
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return (start, end)
    }

    private static func mergedResults(_ allResults: [TestResult], withCurrentUserResults currentUserResults: [TestResult]) -> [TestResult] {
        var merged = allResults
        var knownIds = Set(allResults.map(\.id))

        for result in currentUserResults where !knownIds.contains(result.id) {
            merged.append(result)
            knownIds.insert(result.id)
        }

        return merged
    }

    private static func rankedLeaderboard(
        from results: [TestResult],
        currentUserId: String,
        start: Date,
        end: Date
    ) -> [LeaderboardUserResult] {
        let grouped = Dictionary(
            grouping: results.filter { result in
                result.totalQuestions > 0
                    && result.timestamp >= start
                    && result.timestamp <= end
            },
            by: { $0.userId }
        )

        return grouped.map { userId, items in
            (
                userId: userId,
                correct: items.reduce(0) { $0 + $1.correctAnswers },
                total: items.reduce(0) { $0 + $1.totalQuestions },
                attempts: items.count
            )
        }
        .filter { $0.total > 0 }
        .sorted { lhs, rhs in
            let leftAccuracy = Double(lhs.correct) / Double(lhs.total)
            let rightAccuracy = Double(rhs.correct) / Double(rhs.total)
            if leftAccuracy == rightAccuracy {
                if lhs.correct == rhs.correct {
                    return lhs.total > rhs.total
                }
                return lhs.correct > rhs.correct
            }
            return leftAccuracy > rightAccuracy
        }
        .enumerated()
        .map { index, item in
            LeaderboardUserResult(
                id: item.userId,
                rank: index + 1,
                userId: item.userId,
                correctAnswers: item.correct,
                totalQuestions: item.total,
                attempts: item.attempts,
                isCurrentUser: item.userId == currentUserId
            )
        }
    }
}
