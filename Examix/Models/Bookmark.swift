//
//  Bookmark.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation

struct Bookmark: Identifiable, Hashable {
    var id: String { firebaseDocumentId }

    let firebaseDocumentId: String
    let questionId: String
    let title: String
    let text: String
    let userTextAnswer: String
    let userSelectedOptions: [String]
    let options: [String]
    let correctAnswers: [String]
    let language: String
    let variant: Int
    let questionType: String
    var userComment: String
    let bookmarkedAt: Date

    var compositeLine: String {
        "\(language) · вар. \(variant)"
    }
}
