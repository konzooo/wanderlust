//
//  FileStoreTests.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato on 7/7/25.
//

import XCTest
@testable import CoreArchitecture

// ---------------------------------------------------------------------------
// MARK: – Mock model used for the tests
// ---------------------------------------------------------------------------

/// A minimal data‑type that satisfies `FilePersistable`.
private struct MockItem: FilePersistable, Equatable {
    typealias DuplicateIdentity = DuplicateKey

    let id: String
    let category: String
    let version: Int
    var name: String
    
    init(category: String, version: Int, name: String) {
        self.id = UUID().uuidString
        self.category = category
        self.version = version
        self.name = name
    }
    
    var groupingFolder: String { category }
    
    struct DuplicateKey: Hashable {
        let category: String
        let version: Int
    }
    var duplicateIdentity: DuplicateIdentity { .init(category: category, version: version) }
    
    // MARK: Sample instances -------------------------------------------------
    
    static let base             = MockItem(category: "FolderA", version: 1, name: "Base")
    static let updatedDuplicate = MockItem(category: "FolderA", version: 1, name: "Updated")
    static let newVersion       = MockItem(category: "FolderA", version: 2, name: "Second Version")
    static let otherCategory    = MockItem(category: "FolderB", version: 1, name: "Other")
}

// ---------------------------------------------------------------------------
// MARK: – Test‑case
// ---------------------------------------------------------------------------

final class FileStoreTests: XCTestCase {
    
    // Store instance injected fresh for every test --------------------------
    
    private var store: FileStore<MockItem>!
    private var rootFolderName: String!
    
    // -----------------------------------------------------------------------
    // Life‑cycle
    // -----------------------------------------------------------------------
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        rootFolderName = "FileStoreGenericTests_\(UUID().uuidString)"
        store = try FileStore<MockItem>(rootFolderName: rootFolderName)
    }
    
    override func tearDownWithError() throws {
        // Remove the entire temporary store directory
        let fm = FileManager.default
        if let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: false) {
            try? fm.removeItem(at: appSupport
                                .appendingPathComponent(rootFolderName,
                                                        isDirectory: true))
        }
        store = nil
        try super.tearDownWithError()
    }
    
    
    // -----------------------------------------------------------------------
    // Actual tests
    // -----------------------------------------------------------------------
    
    /// Saving two items and fetching all should return the same two.
    func testSaveAndFetchAll() throws {
        try store.save(MockItem.base)
        try store.save(MockItem.otherCategory)
        
        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(MockItem.base))
        XCTAssertTrue(all.contains(MockItem.otherCategory))
    }
    
    /// Items must live in folders that match their `category`.
    func testGroupingFolders() throws {
        try store.save(MockItem.base)
        try store.save(MockItem.otherCategory)
        
        let folderA = try store.fetch(inGrouping: "FolderA")
        XCTAssertEqual(folderA.count, 1)
        XCTAssertEqual(folderA.first?.groupingFolder, "FolderA")
        
        let folderB = try store.fetch(inGrouping: "FolderB")
        XCTAssertEqual(folderB.count, 1)
        XCTAssertEqual(folderB.first?.groupingFolder, "FolderB")
    }
    
    /// Writing a second object that has the same `duplicateIdentity`
    /// should overwrite instead of adding a second file.
    func testDuplicateOverwrites() throws {
        try store.save(MockItem.base)
        try store.save(MockItem.updatedDuplicate)           // same category & version
        
        let folderA = try store.fetch(inGrouping: "FolderA")
        XCTAssertEqual(folderA.count, 1,
                       "Duplicate should replace, not append")
        XCTAssertEqual(folderA.first?.name, "Updated",
                       "File contents were not replaced")
    }
    
    /// When duplicateIdentity differs (here the version changes),
    /// both objects must be persisted side‑by‑side.
    func testNonDuplicateCreatesNewFile() throws {
        try store.save(MockItem.base)
        try store.save(MockItem.newVersion)                 // same category, *different* version
        
        let folderA = try store.fetch(inGrouping: "FolderA")
        XCTAssertEqual(folderA.count, 2,
                       "Distinct duplicateIdentity values must create two files")
    }
    
    /// Fetching by `id` should return the correct object.
    func testFetchByID() throws {
        try store.save(MockItem.base)
        guard let fetched = try store.fetch(id: MockItem.base.id) else {
            return XCTFail("fetch(id:) returned nil")
        }
        XCTAssertEqual(fetched, MockItem.base)
    }
}
