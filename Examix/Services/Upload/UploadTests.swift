//
//  UploadTests.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 3.05.25.
//

import Foundation
import FirebaseFirestore

struct UploadableTest: Codable {
    let language: String
    let variant: Int
    let progress: Int
    let questions: [UploadableQuestion]
}

struct UploadableQuestion: Codable {
    let id: String
    let title: String
    let text: String?       
    let type: String
    let options: [UploadableOption]
}

struct UploadableOption: Codable {
    let text: String
    let isCorrect: Bool
}

final class TestUploader {

    static func uploadTest(named fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Файл «\(fileName).json» не найден в бандле")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let tests = try JSONDecoder().decode([UploadableTest].self, from: data)

            let db = Firestore.firestore()

            try tests.forEach { test in
                let docRef = db.collection("tests").document("\(test.language)_\(test.variant)")
                try docRef.setData(from: test)
            }

            print("\(tests.count) тест(ов) успешно загружено в Firestore")
        } catch {
            print("Ошибка: \(error.localizedDescription)")
        }
    }
}
