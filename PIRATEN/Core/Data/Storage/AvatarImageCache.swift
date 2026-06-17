//
//  AvatarImageCache.swift
//  PIRATEN
//

import Foundation
import UIKit
import CryptoKit

/// Two-tier cache for user avatar images, so they appear instantly when a
/// screen is revisited instead of re-downloading and flashing a placeholder.
///
/// - **Memory tier** (`NSCache`): a synchronous peek (`cachedImage(for:)`) lets
///   a view paint a known avatar on its very first frame, on the main thread.
/// - **Disk tier** (`Caches/avatars`): survives app restarts. The `Caches`
///   directory is the right home for purgeable, re-downloadable derived data.
///
/// No HTTP revalidation: Discourse avatar URLs embed the `avatar_id`, so a new
/// picture means a new URL — a changed avatar naturally misses the cache and
/// downloads fresh, and a stable URL can be served from cache indefinitely.
///
/// Privacy: avatars are personal data, so the cache is cleared on logout via
/// `LogoutOrchestrator` (see `clear()`).
final class AvatarImageCache: @unchecked Sendable {

    // MARK: - Constants

    /// Cap on persisted avatar files; trimmed oldest-first when exceeded.
    private static let maxDiskEntries = 200

    // MARK: - Tiers

    /// `NSCache` is thread-safe, so a non-isolated synchronous read is safe.
    private let memory = NSCache<NSURL, UIImage>()

    private let fileManager = FileManager.default
    private let directory: URL

    /// Serializes disk writes/trims (reads are cheap and tolerate races).
    private let diskQueue = DispatchQueue(label: "de.piraten.avatarcache.disk", qos: .utility)

    // MARK: - Init

    init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("avatars", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Synchronous memory peek

    /// Returns an avatar already held in memory, or `nil`. Synchronous and
    /// safe to call from the main thread so a view can render a cached avatar
    /// on its first frame without a placeholder flash.
    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    // MARK: - Async load (memory → disk → network)

    /// Returns the avatar for `url`, checking memory, then disk, then network.
    /// Each tier populates the faster ones above it. Returns `nil` only if the
    /// image can't be fetched/decoded.
    func image(for url: URL) async -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) {
            return hit
        }

        let fileURL = fileURL(for: url)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memory.setObject(image, forKey: url as NSURL)
            return image
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let image = UIImage(data: data) else {
            return nil
        }

        memory.setObject(image, forKey: url as NSURL)
        diskQueue.async { [directory, fileManager] in
            try? data.write(to: fileURL, options: .atomic)
            Self.trimDisk(in: directory, using: fileManager)
        }
        return image
    }

    // MARK: - Clear (logout)

    /// Empties both tiers. Called from `LogoutOrchestrator` — avatars are
    /// personal data and must not survive a session.
    func clear() {
        memory.removeAllObjects()
        diskQueue.async { [directory, fileManager] in
            guard let entries = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
            for entry in entries {
                try? fileManager.removeItem(at: entry)
            }
        }
    }

    // MARK: - Disk helpers

    /// Maps an avatar URL to a stable on-disk filename (SHA-256 of the absolute
    /// string) so unrelated URLs never collide and the same URL is reused.
    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }

    /// Keeps the avatar directory bounded: when over the cap, deletes the
    /// oldest files (by modification date) first.
    private static func trimDisk(in directory: URL, using fileManager: FileManager) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ), entries.count > maxDiskEntries else { return }

        let sorted = entries.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return lDate < rDate
        }
        for entry in sorted.prefix(entries.count - maxDiskEntries) {
            try? fileManager.removeItem(at: entry)
        }
    }
}
