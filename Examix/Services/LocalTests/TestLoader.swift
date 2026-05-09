//
//  TestLoader.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation

enum TestLoader {
    static func loadTest(named filename: String) -> TestVariant? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([TestVariant].self, from: data)
            return decoded.randomElement()
        } catch {
            return nil
        }
    }
}
