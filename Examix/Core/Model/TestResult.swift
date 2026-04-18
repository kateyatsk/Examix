//
//  TestResult.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 2.05.25.
//

import Foundation

struct TestResult: Codable, Identifiable {
    var id: String = UUID().uuidString
    let userId: String
    let language: String
    let variant: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let timestamp: Date
    let answers: [String: String]
    let allQuestionIDs: [String]
    let questionTypesById: [String: String]?
    let correctOptionsById: [String: [String]]?
}

