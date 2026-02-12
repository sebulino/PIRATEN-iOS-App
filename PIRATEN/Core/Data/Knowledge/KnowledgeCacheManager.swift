//
//  KnowledgeCacheManager.swift
//  PIRATEN
//

import Foundation

/// Manages file-based caching of Knowledge Hub content in the Caches directory.
/// Uses atomic writes (temp file + rename) for data safety.
/// Returns nil on read errors — never throws.
final class KnowledgeCacheManager {

    private let fileManager: FileManager
    private let cacheDirectoryURL: URL
    private let topicsDirectoryURL: URL
    private let indexFileURL: URL

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectoryURL = cachesURL.appendingPathComponent("Knowledge", isDirectory: true)
        self.topicsDirectoryURL = cacheDirectoryURL.appendingPathComponent("topics", isDirectory: true)
        self.indexFileURL = cacheDirectoryURL.appendingPathComponent("index.json")
    }

    // MARK: - Index

    func readIndex() -> KnowledgeIndex? {
        guard let data = try? Data(contentsOf: indexFileURL) else { return nil }
        return try? decoder.decode(KnowledgeIndex.self, from: data)
    }

    func writeIndex(_ index: KnowledgeIndex) {
        guard let data = try? encoder.encode(index) else { return }
        ensureDirectoryExists(cacheDirectoryURL)
        atomicWrite(data: data, to: indexFileURL)
    }

    // MARK: - Topic Content

    func readTopicContent(topicId: String) -> TopicContent? {
        let fileURL = topicFileURL(for: topicId)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(TopicContent.self, from: data)
    }

    func writeTopicContent(_ content: TopicContent) {
        guard let data = try? encoder.encode(content) else { return }
        ensureDirectoryExists(topicsDirectoryURL)
        atomicWrite(data: data, to: topicFileURL(for: content.topicId))
    }

    // MARK: - Clear

    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectoryURL)
    }

    // MARK: - Private Helpers

    private func topicFileURL(for topicId: String) -> URL {
        topicsDirectoryURL.appendingPathComponent("\(topicId).json")
    }

    private func ensureDirectoryExists(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func atomicWrite(data: Data, to destinationURL: URL) {
        let tempURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: tempURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: tempURL)
        }
    }
}
