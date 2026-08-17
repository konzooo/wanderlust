import CryptoKit
import Foundation

/// A two-level destination image cache: decoded requests are served from RAM
/// during the session and the original bytes are retained in the system Caches
/// directory for later launches. The OS may purge Caches under storage
/// pressure, which is appropriate because every entry can be downloaded again.
public actor PersistentImageCacheStrategy: ImageCacheStrategy {
    public static let shared = PersistentImageCacheStrategy()

    private let directoryURL: URL?
    private let diskCapacity: Int
    private let memoryCache = NSCache<NSString, NSData>()

    public init(
        directoryURL: URL? = nil,
        memoryCapacity: Int = 40 * 1_024 * 1_024,
        diskCapacity: Int = 200 * 1_024 * 1_024
    ) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            self.directoryURL = try? FileManager.default
                .url(
                    for: .cachesDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                .appendingPathComponent("DestinationImages", isDirectory: true)
        }
        self.diskCapacity = diskCapacity
        memoryCache.totalCostLimit = memoryCapacity

        if let cacheDirectory = self.directoryURL {
            try? FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    public func retrieveData(forKey key: String) -> Data? {
        let memoryKey = key as NSString
        if let cached = memoryCache.object(forKey: memoryKey) {
            return cached as Data
        }

        guard let fileURL = fileURL(forKey: key),
              let data = try? Data(contentsOf: fileURL) else { return nil }

        memoryCache.setObject(data as NSData, forKey: memoryKey, cost: data.count)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        return data
    }

    public func store(_ data: Data, forKey key: String) {
        guard !data.isEmpty else { return }

        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        guard let fileURL = fileURL(forKey: key) else { return }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            trimDiskIfNeeded()
        } catch {
            // A disk-cache failure must never prevent the image from rendering;
            // the in-memory entry above remains valid for this session.
        }
    }

    private func fileURL(forKey key: String) -> URL? {
        guard let directoryURL else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directoryURL.appendingPathComponent(digest).appendingPathExtension("image")
    }

    private func trimDiskIfNeeded() {
        guard diskCapacity > 0, let directoryURL else { return }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        let entries = files.compactMap { url -> (url: URL, size: Int, date: Date)? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > diskCapacity else { return }

        for entry in entries.sorted(by: { $0.date < $1.date }) where totalSize > diskCapacity {
            if (try? FileManager.default.removeItem(at: entry.url)) != nil {
                totalSize -= entry.size
            }
        }
    }
}
