//
//  LocalTestDatabase.swift
//  Examix
//
//  SQLite storage for TestVariant payloads (imported from JSON).
//

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class LocalTestDatabase {
    static let shared = LocalTestDatabase()

    /// Open SQLite connection handle (avoid naming it `db` — clashes with some toolchains / overlays).
    private var databaseHandle: OpaquePointer?
    private let queue = DispatchQueue(label: "examix.localtests.sqlite")

    private init() {
        queue.sync {
            self.openIfNeeded()
            self.migrate()
        }
    }

    private func openIfNeeded() {
        guard databaseHandle == nil else { return }
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Examix", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("local_tests.sqlite")
        var connection: OpaquePointer?
        if sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK {
            databaseHandle = connection
        } else {
            databaseHandle = nil
        }
    }

    private func migrate() {
        guard let handle = databaseHandle else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS variants (
            language TEXT NOT NULL,
            variant INTEGER NOT NULL,
            payload TEXT NOT NULL,
            PRIMARY KEY (language, variant)
        );
        """
        sqlite3_exec(handle, sql, nil, nil, nil)
    }

    func upsert(_ test: TestVariant) throws {
        try queue.sync {
            try self.upsertSync(test)
        }
    }

    private func upsertSync(_ test: TestVariant) throws {
        guard let handle = databaseHandle else { throw LocalTestDatabaseError.databaseClosed }
        let data = try JSONEncoder().encode(test)
        guard let json = String(data: data, encoding: .utf8) else {
            throw LocalTestDatabaseError.encodingFailed
        }
        let sql = "INSERT OR REPLACE INTO variants (language, variant, payload) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalTestDatabaseError.prepareFailed
        }
        sqlite3_bind_text(statement, 1, test.language, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(test.variant))
        sqlite3_bind_text(statement, 3, json, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LocalTestDatabaseError.executeFailed
        }
    }

    func fetch(language: String, variant: Int) throws -> TestVariant? {
        try queue.sync {
            try self.fetchSync(language: language, variant: variant)
        }
    }

    private func fetchSync(language: String, variant: Int) throws -> TestVariant? {
        guard let handle = databaseHandle else { throw LocalTestDatabaseError.databaseClosed }
        let sql = "SELECT payload FROM variants WHERE language = ? AND variant = ? LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalTestDatabaseError.prepareFailed
        }
        sqlite3_bind_text(statement, 1, language, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(variant))
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let cstr = sqlite3_column_text(statement, 0) else { return nil }
        let json = String(cString: cstr)
        guard let data = json.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(TestVariant.self, from: data)
    }

    func fetchRandom(language: String) throws -> TestVariant? {
        try queue.sync {
            try self.fetchRandomSync(language: language)
        }
    }

    private func fetchRandomSync(language: String) throws -> TestVariant? {
        guard let handle = databaseHandle else { throw LocalTestDatabaseError.databaseClosed }
        let sql = "SELECT payload FROM variants WHERE language = ? ORDER BY RANDOM() LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalTestDatabaseError.prepareFailed
        }
        sqlite3_bind_text(statement, 1, language, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let cstr = sqlite3_column_text(statement, 0) else { return nil }
        let json = String(cString: cstr)
        guard let data = json.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(TestVariant.self, from: data)
    }

    func listVariantNumbers(language: String) throws -> [Int] {
        try queue.sync {
            try self.listVariantNumbersSync(language: language)
        }
    }

    /// Все варианты для языка (ключ как в Firestore, например «Русский язык»).
    func fetchAll(language: String) throws -> [TestVariant] {
        try queue.sync {
            try self.fetchAllSync(language: language)
        }
    }

    private func fetchAllSync(language: String) throws -> [TestVariant] {
        guard let handle = databaseHandle else { throw LocalTestDatabaseError.databaseClosed }
        let sql = "SELECT payload FROM variants WHERE language = ? ORDER BY variant;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalTestDatabaseError.prepareFailed
        }
        sqlite3_bind_text(statement, 1, language, -1, SQLITE_TRANSIENT)
        var out: [TestVariant] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cstr = sqlite3_column_text(statement, 0) else { continue }
            let json = String(cString: cstr)
            guard let data = json.data(using: .utf8) else { continue }
            out.append(try JSONDecoder().decode(TestVariant.self, from: data))
        }
        return out
    }

    private func listVariantNumbersSync(language: String) throws -> [Int] {
        guard let handle = databaseHandle else { throw LocalTestDatabaseError.databaseClosed }
        let sql = "SELECT variant FROM variants WHERE language = ? ORDER BY variant;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalTestDatabaseError.prepareFailed
        }
        sqlite3_bind_text(statement, 1, language, -1, SQLITE_TRANSIENT)
        var out: [Int] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            out.append(Int(sqlite3_column_int(statement, 0)))
        }
        return out
    }
}

enum LocalTestDatabaseError: Error {
    case databaseClosed
    case encodingFailed
    case prepareFailed
    case executeFailed
}
