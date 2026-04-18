//
//  RulesView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 10.05.25.
//

import Foundation
import SwiftUI
import PDFKit

struct RulesView: View {
    let language: Language

    var body: some View {
        if let pdfView = pdfView(for: language) {
            PDFKitView(pdfView: pdfView)
                .navigationTitle("Правила")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("Файл не найден")
                .foregroundColor(.red)
        }
    }

    func pdfView(for language: Language) -> PDFView? {
        let fileName: String
        switch language {
        case .russian: fileName = "russian_rules"
        case .english: fileName = "english_rules"
        case .french: fileName = "french_rules"
        case .german: fileName = "german_rules"
        case .belarusian: fileName = "belarusian_rules"
        }

        if let url = Bundle.main.url(forResource: fileName, withExtension: "pdf"),
           let document = PDFDocument(url: url) {
            let view = PDFView()
            view.document = document
            view.autoScales = true
            return view
        }
        return nil
    }
}

struct PDFKitView: UIViewRepresentable {
    let pdfView: PDFView

    func makeUIView(context: Context) -> PDFView {
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}


