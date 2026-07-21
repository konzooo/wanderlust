//
//  FileStore.swift
//  CoreArchitecture
//
//  A *generic* file–based persistence layer that works for **any**
//  `Codable & Identifiable` model that can tell the store
//  1) in which *folder* it should live (to keep data grouped) and
//  2) how to decide whether a newly‑saved instance is a *duplicate*
//     and must overwrite a previous file, or should be stored separately.
//
//  The generic store is declared first.  Trip then conforms to the
//  `FilePersistable` protocol so you get a ready‑to‑use `TripStore`.
//
//  Created by Rodrigo Mato on 7/7/25.
//

import Foundation

// MARK: - 1. Requirements every storable model must meet
// ------------------------------------------------------

/// Anything you want to save to disk must:
///  • be `Codable`                                  – so we can JSON‑encode it
///  • be `Identifiable`                             – exposes a stable `id`
///  • expose                                        –
///     • a *folder* name (e.g. “Barcelona_Spain”)   – used to group files
///     • a *duplicateIdentity*                      – used to detect replacements
public protocol FilePersistable: Codable, Identifiable {
    /// The folder inside the store’s *root* directory where this object lives.
    /// For `Trip` we choose the destination name, sanitised for the file system.
    var groupingFolder: String { get }
    
    /// Two objects whose `duplicateIdentity` values are equal are considered
    /// *the same logical item*; the newer one *replaces* the older on save.
    associatedtype DuplicateIdentity: Hashable
    var duplicateIdentity: DuplicateIdentity { get }
}

/// Convenience default for anything whose logical identity is its own `id`.
public extension FilePersistable where DuplicateIdentity == ID, ID: Hashable {
    var duplicateIdentity: ID { id }
}


// MARK: - 2. Generic on‑disk store
// --------------------------------

public final class FileStore<Model: FilePersistable> {
    
    /// Where all data for *this* model type is kept (…/Application Support/<Root>)
    public let rootURL: URL
    
    public init(rootFolderName: String = String(describing: Model.self) + "Store") throws {
        let fm = FileManager.default
        // ~/Library/Application Support/<App>/<rootFolderName>
        let base = try fm.url(for: .applicationSupportDirectory,
                              in: .userDomainMask,
                              appropriateFor: nil,
                              create: true)
        rootURL = base.appendingPathComponent(rootFolderName, isDirectory: true)
        try fm.createDirectory(at: rootURL,
                               withIntermediateDirectories: true,
                               attributes: nil)
    }
    
    /// Save (create or replace) a single model instance.
    /// Replacement happens when another file in the same folder has the *same* duplicateIdentity.
    /// If multiple duplicate files are found (data corruption or older bug), the first one is
    /// overwritten and the extras are removed to restore a single‑source of truth.
    @discardableResult
    public func save(_ value: Model) throws -> URL {
        let folder = try folderURL(for: value)
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        
        // Look for existing files with the same duplicateIdentity to overwrite
        let duplicateURLs = try urlsOfDuplicates(of: value, in: folder)
        if let primary = duplicateURLs.first {
            // Preserve primary filename for stability, just overwrite its content
            try encode(value).write(to: primary, options: .atomic)
            // Clean up any stale duplicates beyond the primary
            for stale in duplicateURLs.dropFirst() {
                try? fm.removeItem(at: stale)
            }
            return primary
        }
        
        // Otherwise create a new file: <UUID>.json
        let fileURL = folder.appendingPathComponent("\(value.id).json")
        try encode(value).write(to: fileURL, options: .atomic)
        return fileURL
    }
    
    /// Fetch *all* stored objects.
    public func fetchAll() throws -> [Model] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: rootURL,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles])
        else { return [] }
        
        var result: [Model] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "json",
               let data = try? Data(contentsOf: fileURL),
               let decoded = try? decode(data) {
                result.append(decoded)
            }
        }
        return result
    }
    
    /// Fetch every object whose folder equals the supplied *destination*.
    public func fetch(inGrouping groupingFolder: String) throws -> [Model] {
        let folder = rootURL.appendingPathComponent(sanitise(groupingFolder), isDirectory: true)
        return try decodeAll(in: folder)
    }
    
    /// Fetch a single object by `id`.
    public func fetch(id: Model.ID) throws -> Model? where Model.ID: LosslessStringConvertible {
        let fm = FileManager.default
        let pattern = "\(id).json"
        guard let enumerator = fm.enumerator(at: rootURL,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles])
        else { return nil }
        
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == pattern {
            let data = try Data(contentsOf: fileURL)
            return try decode(data)
        }
        return nil
    }
    
    /// Delete a model instance by finding its file using duplicateIdentity.
    public func delete(_ value: Model) throws {
        let folder = try folderURL(for: value)
        let duplicates = try urlsOfDuplicates(of: value, in: folder)
        for url in duplicates {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    
    // MARK: Private helpers ---------------------------------------------------
    
    private func encode(_ value: Model) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    
    private func decode(_ data: Data) throws -> Model {
        try JSONDecoder().decode(Model.self, from: data)
    }
    
    private func decodeAll(in folder: URL) throws -> [Model] {
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: folder,
                                                               includingPropertiesForKeys: nil,
                                                               options: [.skipsHiddenFiles])
        return urls.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            return try? decode(Data(contentsOf: url))
        }
    }
    
    /// Folder path for a given model (…/root/<groupingFolder>)
    private func folderURL(for value: Model) throws -> URL {
        rootURL.appendingPathComponent(sanitise(value.groupingFolder), isDirectory: true)
    }
    
    /// If files with the same `duplicateIdentity` already exist in `folder`, return all their URLs.
    /// This can happen if older app versions failed to de‑dupe correctly. We use this to both
    /// choose a primary to overwrite and to delete the extras.
    private func urlsOfDuplicates(of value: Model, in folder: URL) throws -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else { return [] }
        let urls = try fm.contentsOfDirectory(at: folder,
                                              includingPropertiesForKeys: nil,
                                              options: [])
        var matches: [URL] = []
        for url in urls where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let existing = try? decode(data),
               existing.duplicateIdentity == value.duplicateIdentity {
                matches.append(url)
            }
        }
        return matches
    }
    
    /// Simplistic folder‑name sanitiser.
    private func sanitise(_ raw: String) -> String {
        raw.replacingOccurrences(of: "[^A-Za-z0-9_\\-]", with: "_", options: .regularExpression)
    }
}
