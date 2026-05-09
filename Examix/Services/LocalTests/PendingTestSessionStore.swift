//
//  PendingTestSessionStore.swift
//  Examix
//
//  Created by Kate Yatskevich on 9.05.26.
//

import Foundation

enum PendingTestSessionStore {
    private static let defaultsKey = "examix.pendingTestSessions.v1"

    static func allSessions() -> [PendingTestSession] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let list = try? JSONDecoder().decode([PendingTestSession].self, from: data) else { return [] }
        return list.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func sessions(uiLearningLanguage: String) -> [PendingTestSession] {
        allSessions().filter { $0.uiLearningLanguage == uiLearningLanguage }
    }

    static func load(id: String) -> PendingTestSession? {
        allSessions().first { $0.id == id }
    }

    static func upsert(_ session: PendingTestSession) {
        var list = allSessions().filter { $0.id != session.id }
        list.append(session)
        persist(list)
    }

    static func remove(id: String) {
        let list = allSessions().filter { $0.id != id }
        persist(list)
    }

    static func remove(examLanguage: String, variant: Int, uiLearningLanguage: String) {
        remove(id: PendingTestSession.storageId(examLanguage: examLanguage, variant: variant, uiLearningLanguage: uiLearningLanguage))
    }

    private static func persist(_ list: [PendingTestSession]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
