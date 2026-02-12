//
//  RealKnowledgeRepository.swift
//  PIRATEN
//

import Foundation

/// Production implementation of KnowledgeRepository.
/// Orchestrates GitHubAPIClient, FrontmatterParser, ContentSectionParser,
/// and KnowledgeCacheManager to provide cache-first content with GitHub fallback.
@MainActor
final class RealKnowledgeRepository: KnowledgeRepository {

    // MARK: - Properties

    private let apiClient: GitHubAPIClient
    private let cacheManager: KnowledgeCacheManager
    private let cacheTTL: TimeInterval

    /// Directories to ignore when listing categories from the repo root.
    private static let ignoredDirectories: Set<String> = ["_shared"]

    // MARK: - Initialization

    init(
        apiClient: GitHubAPIClient,
        cacheManager: KnowledgeCacheManager,
        cacheTTL: TimeInterval = 24 * 60 * 60
    ) {
        self.apiClient = apiClient
        self.cacheManager = cacheManager
        self.cacheTTL = cacheTTL
    }

    // MARK: - KnowledgeRepository

    func fetchIndex(forceRefresh: Bool) async throws -> KnowledgeIndex {
        // Cache-first: return cached index if still fresh
        if !forceRefresh, let cached = cacheManager.readIndex() {
            if Date().timeIntervalSince(cached.lastFetched) < cacheTTL {
                return cached
            }
        }

        // Try fetching from GitHub
        do {
            let index = try await fetchIndexFromGitHub()
            cacheManager.writeIndex(index)
            return index
        } catch {
            // Graceful fallback: return cached data on network failure
            if let cached = cacheManager.readIndex() {
                return cached
            }
            throw mapError(error)
        }
    }

    func fetchTopicContent(topicId: String) async throws -> TopicContent {
        // Cache-first
        if let cached = cacheManager.readTopicContent(topicId: topicId) {
            return cached
        }

        // Need the index to find the topic's contentPath
        let index = try await fetchIndex(forceRefresh: false)
        guard let topic = index.topics.first(where: { $0.id == topicId }) else {
            throw KnowledgeError.notFound
        }

        do {
            let content = try await fetchAndParseTopicContent(topic: topic)
            cacheManager.writeTopicContent(content)
            return content
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Index Fetching

    private func fetchIndexFromGitHub() async throws -> KnowledgeIndex {
        let cachedIndex = cacheManager.readIndex()

        // Fetch root directory with ETag conditional request
        let rootResult = try await apiClient.fetchDirectoryContents(
            path: "",
            etag: cachedIndex?.etag
        )

        switch rootResult {
        case .notModified:
            // Content unchanged — refresh lastFetched timestamp on cached index
            if let cached = cachedIndex {
                let refreshed = KnowledgeIndex(
                    categories: cached.categories,
                    topics: cached.topics,
                    featuredTopicIds: cached.featuredTopicIds,
                    learningPaths: cached.learningPaths,
                    lastFetched: Date(),
                    etag: cached.etag
                )
                return refreshed
            }
            // Should not happen if ETag was sent from cache, but fall through
            throw KnowledgeError.notFound

        case .modified(let items, let etag):
            return try await buildIndex(
                from: items,
                etag: etag
            )
        }
    }

    private func buildIndex(
        from rootItems: [GitHubContentItem],
        etag: String?
    ) async throws -> KnowledgeIndex {
        // Fetch kanon.json for featured topics and learning paths
        let (featuredTopicIds, learningPaths) = await fetchKanonConfig(from: rootItems)

        // Filter category directories (ignore _shared, dotfolders, files)
        let categoryDirs = rootItems.filter { item in
            item.type == "dir"
            && !item.name.hasPrefix(".")
            && !Self.ignoredDirectories.contains(item.name)
        }

        // Parallel category fetching
        let categoryResults = await fetchCategoriesInParallel(categoryDirs)

        // Sort categories by order
        let sortedCategories = categoryResults.map(\.category).sorted { $0.order < $1.order }
        let allTopics = categoryResults.flatMap(\.topics)

        return KnowledgeIndex(
            categories: sortedCategories,
            topics: allTopics,
            featuredTopicIds: featuredTopicIds,
            learningPaths: learningPaths,
            lastFetched: Date(),
            etag: etag
        )
    }

    // MARK: - Kanon Config

    private func fetchKanonConfig(
        from rootItems: [GitHubContentItem]
    ) async -> ([String], [LearningPath]) {
        guard let kanonItem = rootItems.first(where: { $0.name == "kanon.json" }),
              let downloadURL = kanonItem.downloadUrl else {
            return ([], [])
        }

        do {
            let data = try await apiClient.fetchRawFile(downloadURL: downloadURL)
            return parseKanonJSON(data)
        } catch {
            return ([], [])
        }
    }

    private func parseKanonJSON(_ data: Data) -> ([String], [LearningPath]) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], [])
        }

        let featured = (json["featured"] as? [String]) ?? []

        var paths: [LearningPath] = []
        if let pathDicts = json["paths"] as? [[String: Any]] {
            for dict in pathDicts {
                guard let id = dict["id"] as? String,
                      let title = dict["title"] as? String,
                      let topicIds = dict["topics"] as? [String] else { continue }
                paths.append(LearningPath(id: id, title: title, topicIds: topicIds))
            }
        }

        return (featured, paths)
    }

    // MARK: - Category Fetching

    private struct CategoryResult {
        let category: KnowledgeCategory
        let topics: [KnowledgeTopic]
    }

    private func fetchCategoriesInParallel(
        _ categoryDirs: [GitHubContentItem]
    ) async -> [CategoryResult] {
        return await withTaskGroup(of: CategoryResult?.self) { group in
            for dir in categoryDirs {
                group.addTask { [self] in
                    await self.fetchCategory(dir)
                }
            }

            var results: [CategoryResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }
    }

    private nonisolated func fetchCategory(
        _ dir: GitHubContentItem
    ) async -> CategoryResult? {
        do {
            let dirResult = try await apiClient.fetchDirectoryContents(path: dir.path)
            guard case .modified(let items, _) = dirResult else { return nil }

            // Parse _category.yml
            let category = await parseCategoryYML(from: items, dirName: dir.name)

            // Parse topic .md files
            let topics = await parseTopicFiles(from: items, categoryId: category.id)

            return CategoryResult(category: category, topics: topics)
        } catch {
            return nil
        }
    }

    private nonisolated func parseCategoryYML(
        from items: [GitHubContentItem],
        dirName: String
    ) async -> KnowledgeCategory {
        guard let categoryItem = items.first(where: { $0.name == "_category.yml" }),
              let downloadURL = categoryItem.downloadUrl else {
            // Fallback: create category from directory name
            return KnowledgeCategory(
                id: dirName,
                title: dirName.capitalized,
                description: "",
                order: 999,
                icon: "folder"
            )
        }

        do {
            let data = try await apiClient.fetchRawFile(downloadURL: downloadURL)
            guard let yamlString = String(data: data, encoding: .utf8) else {
                return fallbackCategory(dirName: dirName)
            }
            return parseCategoryFields(yamlString, dirName: dirName)
        } catch {
            return fallbackCategory(dirName: dirName)
        }
    }

    private nonisolated func parseCategoryFields(
        _ yaml: String,
        dirName: String
    ) -> KnowledgeCategory {
        // Use FrontmatterParser to parse the YAML (wrap in --- delimiters)
        let wrappedYAML = "---\n\(yaml)\n---\n"
        guard let result = FrontmatterParser.parse(wrappedYAML) else {
            return fallbackCategory(dirName: dirName)
        }

        let fields = result.fields
        let id = (fields["id"] as? String) ?? dirName
        let title = (fields["title"] as? String) ?? dirName.capitalized
        let description = (fields["description"] as? String) ?? ""
        let order = (fields["order"] as? String).flatMap { Int($0) } ?? 999
        let icon = (fields["icon"] as? String) ?? "folder"

        return KnowledgeCategory(
            id: id,
            title: title,
            description: description,
            order: order,
            icon: icon
        )
    }

    private nonisolated func fallbackCategory(dirName: String) -> KnowledgeCategory {
        KnowledgeCategory(
            id: dirName,
            title: dirName.capitalized,
            description: "",
            order: 999,
            icon: "folder"
        )
    }

    // MARK: - Topic File Parsing

    private nonisolated func parseTopicFiles(
        from items: [GitHubContentItem],
        categoryId: String
    ) async -> [KnowledgeTopic] {
        let mdFiles = items.filter { $0.name.hasSuffix(".md") && !$0.name.hasPrefix("_") }

        return await withTaskGroup(of: KnowledgeTopic?.self) { group in
            for file in mdFiles {
                group.addTask { [self] in
                    await self.parseTopicFile(file, categoryId: categoryId)
                }
            }

            var topics: [KnowledgeTopic] = []
            for await topic in group {
                if let topic {
                    topics.append(topic)
                }
            }
            return topics
        }
    }

    private nonisolated func parseTopicFile(
        _ file: GitHubContentItem,
        categoryId: String
    ) async -> KnowledgeTopic? {
        guard let downloadURL = file.downloadUrl else { return nil }

        do {
            let data = try await apiClient.fetchRawFile(downloadURL: downloadURL)
            guard let markdown = String(data: data, encoding: .utf8) else { return nil }

            let result = FrontmatterParser.parseTopic(
                markdown: markdown,
                categoryId: categoryId,
                contentPath: file.path
            )
            return result?.topic
        } catch {
            return nil
        }
    }

    // MARK: - Topic Content

    private func fetchAndParseTopicContent(
        topic: KnowledgeTopic
    ) async throws -> TopicContent {
        // Fetch the raw markdown via directory contents to get download URL
        let pathComponents = topic.contentPath.components(separatedBy: "/")
        guard pathComponents.count >= 2 else {
            throw KnowledgeError.notFound
        }

        let dirPath = pathComponents.dropLast().joined(separator: "/")
        let fileName = pathComponents.last!

        let dirResult = try await apiClient.fetchDirectoryContents(path: dirPath)
        guard case .modified(let items, _) = dirResult else {
            throw KnowledgeError.notFound
        }

        guard let fileItem = items.first(where: { $0.name == fileName }),
              let downloadURL = fileItem.downloadUrl else {
            throw KnowledgeError.notFound
        }

        let data = try await apiClient.fetchRawFile(downloadURL: downloadURL)
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw KnowledgeError.parsingError("Could not decode markdown as UTF-8")
        }

        // Parse frontmatter to get the body
        guard let frontmatterResult = FrontmatterParser.parse(markdown) else {
            // No frontmatter — treat entire file as body
            let sections = ContentSectionParser.parse(markdown)
            return TopicContent(topicId: topic.id, rawMarkdown: markdown, sections: sections)
        }

        var sections = ContentSectionParser.parse(frontmatterResult.body)

        // Append quiz from topic metadata if present
        if let quiz = topic.quiz, !quiz.isEmpty {
            sections.append(.quiz(quiz))
        }

        return TopicContent(
            topicId: topic.id,
            rawMarkdown: markdown,
            sections: sections
        )
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> KnowledgeError {
        if let knowledgeError = error as? KnowledgeError {
            return knowledgeError
        }
        return .networkError(error.localizedDescription)
    }
}
