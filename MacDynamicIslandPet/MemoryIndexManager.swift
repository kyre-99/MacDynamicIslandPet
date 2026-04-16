import Foundation

// MARK: - Memory Manager Interface

/// 记忆管理器统一接口
///
/// 所有记忆管理器（L1-L4各层级管理器）都实现该接口
/// 提供统一的保存、检索、搜索、清理操作
protocol MemoryManagerInterface {
    /// 关联类型：该管理器处理的记忆条目类型
    associatedtype MemoryType

    /// 保存记忆
    /// - Parameter memory: 要保存的记忆条目
    /// - Returns: 是否保存成功
    func save(_ memory: MemoryType) -> Bool

    /// 检索记忆
    /// - Parameter id: 记忆条目的唯一标识
    /// - Returns: 找到的记忆条目，如果不存在则返回nil
    func retrieve(id: String) -> MemoryType?

    /// 搜索记忆
    /// - Parameter criteria: 搜索条件
    /// - Returns: 匹配的记忆条目数组
    func search(criteria: MemorySearchCriteria) -> [MemoryType]

    /// 清理过期或无效的记忆
    /// - Returns: 清理的记忆条目数量
    func cleanup() -> Int
}

// MARK: - Memory Index Manager

/// 记忆索引管理器，实现记忆的索引和检索机制
///
/// 提供以下检索功能：
/// - 按话题检索：searchByTopic
/// - 按情感检索：searchByEmotion
/// - 按重要性检索：searchByImportance
/// - 按时间范围检索：searchByTimeRange
/// - 综合检索：searchComprehensive
///
/// 检索覆盖所有记忆层级（L1-L4）
/// 使用单例模式，通过 MemoryIndexManager.shared 访问
class MemoryIndexManager {
    /// 共享单例实例
    static let shared = MemoryIndexManager()

    /// L1即时记忆索引（内存中）
    private var instantMemoryIndex: [MemoryItem] = []

    /// L2短期记忆文件索引
    private var shortTermMemoryIndex: [URL: [MemoryItem]] = [:]

    /// L3中期记忆索引（事件时间线）
    private var mediumTermMemoryIndex: [MemoryItem] = []

    /// L4长期记忆索引（用户画像）
    private var longTermMemoryIndex: [MemoryItem] = []

    /// 搜索结果缓存（最近1小时）
    private var searchCache: [String: (result: MemorySearchResult, timestamp: Date)] = [:]

    /// 缓存有效期（1小时）
    private let cacheValidDuration: TimeInterval = 3600

    private init() {
        MemoryStoragePath.ensureAllDirectoriesExist()
        loadAllIndices()
    }

    // MARK: - Index Loading

    /// 加载所有层级记忆索引
    private func loadAllIndices() {
        loadShortTermIndex()
        loadMediumTermIndex()
        loadLongTermIndex()
    }

    /// 加载L2短期记忆索引
    private func loadShortTermIndex() {
        let dailyDir = MemoryStoragePath.dailyDirectory

        guard FileManager.default.fileExists(atPath: dailyDir.path) else {
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: dailyDir, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "md" {
                // 解析Markdown文件提取记忆条目
                if let items = parseDailyMarkdownFile(file) {
                    shortTermMemoryIndex[file] = items
                }
            }
        } catch {
            print("⚠️ Failed to load short-term memory index: \(error.localizedDescription)")
        }
    }

    /// 加载L3中期记忆索引（事件时间线）
    private func loadMediumTermIndex() {
        let timelineFile = MemoryStoragePath.timelineFile

        guard FileManager.default.fileExists(atPath: timelineFile.path) else {
            return
        }

        do {
            let data = FileManager.default.contents(atPath: timelineFile.path)
            if let data = data {
                // 解析timeline.json获取事件列表
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let events = try? decoder.decode([MemoryItem].self, from: data) {
                    mediumTermMemoryIndex = events
                }
            }
        } catch {
            print("⚠️ Failed to load medium-term memory index: \(error.localizedDescription)")
        }
    }

    /// 加载L4长期记忆索引（用户画像）
    private func loadLongTermIndex() {
        let profileFile = MemoryStoragePath.userProfileFile

        guard FileManager.default.fileExists(atPath: profileFile.path) else {
            return
        }

        do {
            let data = FileManager.default.contents(atPath: profileFile.path)
            if let data = data {
                // 解析user-profile.json获取用户画像数据
                // 用户画像可能包含多个子字段，需要灵活处理
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 将用户画像数据转换为MemoryItem格式
                    longTermMemoryIndex = convertProfileToMemoryItems(json)
                }
            }
        } catch {
            print("⚠️ Failed to load long-term memory index: \(error.localizedDescription)")
        }
    }

    // MARK: - Parsing Helpers

    /// 解析每日Markdown文件，提取记忆条目
    /// US-004: Enhanced to parse metadata headers (topics, emotions, importanceScore)
    /// - Parameter file: Markdown文件路径
    /// - Returns: 解析出的记忆条目数组
    private func parseDailyMarkdownFile(_ file: URL) -> [MemoryItem]? {
        do {
            let content = try String(contentsOf: file, encoding: .utf8)

            // 提取日期作为基础信息
            let fileName = file.lastPathComponent
            let dateStr = fileName.replacingOccurrences(of: "memory-", with: "")
                .replacingOccurrences(of: ".md", with: "")

            // 解析对话条目
            var items: [MemoryItem] = []
            let entries = content.components(separatedBy: "## ").dropFirst()

            for entry in entries {
                let lines = entry.components(separatedBy: "\n")
                guard lines.count >= 4 else { continue }

                let timestamp = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)

                // US-004: Parse metadata header (between --- lines)
                var topics: [String] = []
                var emotions: [String] = []
                var importanceScore = 1

                var inMetadataHeader = false

                // 提取用户和精灵的对话
                var userContent: String?
                var petContent: String?

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                    if trimmed == "---" {
                        inMetadataHeader = !inMetadataHeader
                        continue
                    }

                    if inMetadataHeader {
                        // Parse metadata fields
                        if trimmed.hasPrefix("topics:") {
                            let topicsStr = trimmed.replacingOccurrences(of: "topics:", with: "")
                                .replacingOccurrences(of: "[", with: "")
                                .replacingOccurrences(of: "]", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            topics = topicsStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        } else if trimmed.hasPrefix("emotions:") {
                            let emotionsStr = trimmed.replacingOccurrences(of: "emotions:", with: "")
                                .replacingOccurrences(of: "[", with: "")
                                .replacingOccurrences(of: "]", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            emotions = emotionsStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        } else if trimmed.hasPrefix("importanceScore:") {
                            let scoreStr = trimmed.replacingOccurrences(of: "importanceScore:", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            importanceScore = Int(scoreStr) ?? 1
                        }
                    } else {
                        if line.hasPrefix("**User:**") {
                            userContent = line.replacingOccurrences(of: "**User:** ", with: "")
                        } else if line.hasPrefix("**Pet:**") {
                            petContent = line.replacingOccurrences(of: "**Pet:** ", with: "")
                        }
                    }
                }

                if let user = userContent, let pet = petContent {
                    // US-004: Create memory item with parsed metadata
                    let item = MemoryItem.create(
                        layer: .shortTerm,
                        content: "用户: \(user) | 精灵: \(pet)",
                        topics: topics,
                        emotions: emotions,
                        importance: importanceScore
                    )
                    items.append(item)
                }
            }

            return items
        } catch {
            print("⚠️ Failed to parse daily markdown file: \(error.localizedDescription)")
            return nil
        }
    }

    /// 将用户画像JSON转换为MemoryItem数组
    /// - Parameter profile: 用户画像JSON字典
    /// - Returns: 转换后的记忆条目数组
    private func convertProfileToMemoryItems(_ profile: [String: Any]) -> [MemoryItem] {
        var items: [MemoryItem] = []

        // 提取偏好信息
        if let preferences = profile["preferences"] as? [String: Any] {
            for (key, value) in preferences {
                let content = "\(key): \(value)"
                let item = MemoryItem.create(
                    layer: .longTerm,
                    content: content,
                    topics: ["preference"],
                    emotions: [],
                    importance: 5
                )
                items.append(item)
            }
        }

        // 提取情感历史
        if let emotionHistory = profile["emotionHistory"] as? [[String: Any]] {
            for record in emotionHistory {
                if let emotion = record["emotion"] as? String,
                   let timestamp = record["timestamp"] as? String {
                    let content = "情感状态: \(emotion) at \(timestamp)"
                    let item = MemoryItem.create(
                        layer: .longTerm,
                        content: content,
                        topics: ["emotion"],
                        emotions: [emotion],
                        importance: 3
                    )
                    items.append(item)
                }
            }
        }

        // 提取互动模式
        if let interactionPatterns = profile["interactionPatterns"] as? [String: Any] {
            let content = "互动模式: \(interactionPatterns)"
            let item = MemoryItem.create(
                layer: .longTerm,
                content: content,
                topics: ["interaction"],
                emotions: [],
                importance: 4
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Search Methods

    /// 按话题检索记忆（String版本）
    /// - Parameter topic: 话题关键词
    /// - Returns: 包含该话题的所有记忆条目
    func searchByTopic(_ topic: String) -> MemorySearchResult {
        let startTime = Date()
        var matchedItems: [MemoryItem] = []
        var matchedLayers: [MemoryLayer] = []

        // 搜索所有层级
        for item in instantMemoryIndex {
            if item.topics.contains(topic) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for (_, items) in shortTermMemoryIndex {
            for item in items {
                if item.topics.contains(topic) {
                    matchedItems.append(item)
                    if !matchedLayers.contains(item.layer) {
                        matchedLayers.append(item.layer)
                    }
                }
            }
        }

        for item in mediumTermMemoryIndex {
            if item.topics.contains(topic) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for item in longTermMemoryIndex {
            if item.topics.contains(topic) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        let searchTimeMs = Date().timeIntervalSince(startTime) * 1000

        return MemorySearchResult(
            items: matchedItems,
            searchTimeMs: searchTimeMs,
            matchedLayers: matchedLayers,
            criteriaSummary: "话题: \(topic)"
        )
    }

    /// 按情感检索记忆
    /// - Parameter emotion: 情感标签
    /// - Returns: 包含该情感标签的所有记忆条目
    func searchByEmotion(_ emotion: String) -> MemorySearchResult {
        let startTime = Date()
        var matchedItems: [MemoryItem] = []
        var matchedLayers: [MemoryLayer] = []

        // 搜索所有层级
        for item in instantMemoryIndex {
            if item.emotions.contains(emotion) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for (_, items) in shortTermMemoryIndex {
            for item in items {
                if item.emotions.contains(emotion) {
                    matchedItems.append(item)
                    if !matchedLayers.contains(item.layer) {
                        matchedLayers.append(item.layer)
                    }
                }
            }
        }

        for item in mediumTermMemoryIndex {
            if item.emotions.contains(emotion) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for item in longTermMemoryIndex {
            if item.emotions.contains(emotion) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        let searchTimeMs = Date().timeIntervalSince(startTime) * 1000

        return MemorySearchResult(
            items: matchedItems,
            searchTimeMs: searchTimeMs,
            matchedLayers: matchedLayers,
            criteriaSummary: "情感: \(emotion)"
        )
    }

    /// US-004: 按话题枚举检索记忆
    /// - Parameter topic: ConversationTopic话题类型
    /// - Returns: 包含该话题的所有记忆条目
    func searchByConversationTopic(_ topic: ConversationTopic) -> MemorySearchResult {
        let startTime = Date()
        var matchedItems: [MemoryItem] = []
        var matchedLayers: [MemoryLayer] = []

        let topicRawValue = topic.rawValue

        // 搜索所有层级
        for item in instantMemoryIndex {
            if item.topics.contains(topicRawValue) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for (_, items) in shortTermMemoryIndex {
            for item in items {
                if item.topics.contains(topicRawValue) {
                    matchedItems.append(item)
                    if !matchedLayers.contains(item.layer) {
                        matchedLayers.append(item.layer)
                    }
                }
            }
        }

        for item in mediumTermMemoryIndex {
            if item.topics.contains(topicRawValue) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for item in longTermMemoryIndex {
            if item.topics.contains(topicRawValue) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        let searchTimeMs = Date().timeIntervalSince(startTime) * 1000

        return MemorySearchResult(
            items: matchedItems,
            searchTimeMs: searchTimeMs,
            matchedLayers: matchedLayers,
            criteriaSummary: "话题类型: \(topicRawValue)"
        )
    }

    /// US-004: 按情感枚举检索记忆
    /// - Parameter emotion: EmotionTag情感类型
    /// - Returns: 包含该情感标签的所有记忆条目
    func searchByEmotionTag(_ emotion: EmotionTag) -> MemorySearchResult {
        let startTime = Date()
        var matchedItems: [MemoryItem] = []
        var matchedLayers: [MemoryLayer] = []

        let emotionRawValue = emotion.rawValue

        // 搜索所有层级
        for item in instantMemoryIndex {
            if item.emotions.contains(emotionRawValue) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for (_, items) in shortTermMemoryIndex {
            for item in items {
                if item.emotions.contains(emotionRawValue) {
                    matchedItems.append(item)
                    if !matchedLayers.contains(item.layer) {
                        matchedLayers.append(item.layer)
                    }
                }
            }
        }

        for item in mediumTermMemoryIndex {
            if item.emotions.contains(emotionRawValue) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for item in longTermMemoryIndex {
            if item.emotions.contains(emotionRawValue) {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        let searchTimeMs = Date().timeIntervalSince(startTime) * 1000

        return MemorySearchResult(
            items: matchedItems,
            searchTimeMs: searchTimeMs,
            matchedLayers: matchedLayers,
            criteriaSummary: "情感类型: \(emotionRawValue)"
        )
    }

    /// 按重要性检索记忆
    /// - Parameter minImportance: 最小重要性评分
    /// - Returns: 重要性大于指定值的所有记忆条目
    func searchByImportance(_ minImportance: Int) -> MemorySearchResult {
        let startTime = Date()
        var matchedItems: [MemoryItem] = []
        var matchedLayers: [MemoryLayer] = []

        // 搜索所有层级
        for item in instantMemoryIndex {
            if item.importanceScore >= minImportance {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for (_, items) in shortTermMemoryIndex {
            for item in items {
                if item.importanceScore >= minImportance {
                    matchedItems.append(item)
                    if !matchedLayers.contains(item.layer) {
                        matchedLayers.append(item.layer)
                    }
                }
            }
        }

        for item in mediumTermMemoryIndex {
            if item.importanceScore >= minImportance {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for item in longTermMemoryIndex {
            if item.importanceScore >= minImportance {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        let searchTimeMs = Date().timeIntervalSince(startTime) * 1000

        return MemorySearchResult(
            items: matchedItems,
            searchTimeMs: searchTimeMs,
            matchedLayers: matchedLayers,
            criteriaSummary: "重要性 >= \(minImportance)"
        )
    }

    /// 按时间范围检索记忆
    /// - Parameters:
    ///   - start: 开始时间
    ///   - end: 结束时间
    /// - Returns: 在指定时间范围内的所有记忆条目
    func searchByTimeRange(start: Date, end: Date) -> MemorySearchResult {
        let startTime = Date()
        var matchedItems: [MemoryItem] = []
        var matchedLayers: [MemoryLayer] = []

        // 搜索所有层级
        for item in instantMemoryIndex {
            if item.timestamp >= start && item.timestamp <= end {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for (_, items) in shortTermMemoryIndex {
            for item in items {
                if item.timestamp >= start && item.timestamp <= end {
                    matchedItems.append(item)
                    if !matchedLayers.contains(item.layer) {
                        matchedLayers.append(item.layer)
                    }
                }
            }
        }

        for item in mediumTermMemoryIndex {
            if item.timestamp >= start && item.timestamp <= end {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        for item in longTermMemoryIndex {
            if item.timestamp >= start && item.timestamp <= end {
                matchedItems.append(item)
                if !matchedLayers.contains(item.layer) {
                    matchedLayers.append(item.layer)
                }
            }
        }

        let searchTimeMs = Date().timeIntervalSince(startTime) * 1000

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        return MemorySearchResult(
            items: matchedItems,
            searchTimeMs: searchTimeMs,
            matchedLayers: matchedLayers,
            criteriaSummary: "时间范围: \(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))"
        )
    }

    /// 综合检索记忆
    /// - Parameter criteria: 多个检索条件的组合
    /// - Returns: 满足所有条件的记忆条目
    func searchComprehensive(criteria: [MemorySearchCriteria]) -> MemorySearchResult {
        let startTime = Date()

        // 从所有层级收集记忆条目
        var allItems: [MemoryItem] = []
        allItems.append(contentsOf: instantMemoryIndex)

        for (_, items) in shortTermMemoryIndex {
            allItems.append(contentsOf: items)
        }

        allItems.append(contentsOf: mediumTermMemoryIndex)
        allItems.append(contentsOf: longTermMemoryIndex)

        // 应用所有检索条件
        var matchedItems = allItems
        var criteriaSummaries: [String] = []

        for criterion in criteria {
            matchedItems = applyCriterion(matchedItems, criterion)
            criteriaSummaries.append(summarizeCriterion(criterion))
        }

        let searchTimeMs = Date().timeIntervalSince(startTime) * 1000

        // 收集匹配的层级
        let matchedLayers = matchedItems.map { $0.layer }.unique()

        return MemorySearchResult(
            items: matchedItems,
            searchTimeMs: searchTimeMs,
            matchedLayers: matchedLayers,
            criteriaSummary: criteriaSummaries.joined(separator: ", ")
        )
    }

    /// 应用单个检索条件过滤记忆条目
    /// - Parameters:
    ///   - items: 待过滤的记忆条目
    ///   - criterion: 检索条件
    /// - Returns: 过滤后的记忆条目
    private func applyCriterion(_ items: [MemoryItem], _ criterion: MemorySearchCriteria) -> [MemoryItem] {
        switch criterion {
        case .topic(let topic):
            return items.filter { $0.topics.contains(topic) }
        case .emotion(let emotion):
            return items.filter { $0.emotions.contains(emotion) }
        case .importance(let minImportance):
            return items.filter { $0.importanceScore >= minImportance }
        case .timeRange(let start, let end):
            return items.filter { $0.timestamp >= start && $0.timestamp <= end }
        case .comprehensive(let subCriteria):
            var result = items
            for subCriterion in subCriteria {
                result = applyCriterion(result, subCriterion)
            }
            return result
        }
    }

    /// 汇总检索条件描述
    /// - Parameter criterion: 检索条件
    /// - Returns: 条件描述字符串
    private func summarizeCriterion(_ criterion: MemorySearchCriteria) -> String {
        switch criterion {
        case .topic(let topic):
            return "话题: \(topic)"
        case .emotion(let emotion):
            return "情感: \(emotion)"
        case .importance(let minImportance):
            return "重要性 >= \(minImportance)"
        case .timeRange(let start, let end):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return "时间: \(dateFormatter.string(from: start))-\(dateFormatter.string(from: end))"
        case .comprehensive(let subCriteria):
            let subSummaries = subCriteria.map { summarizeCriterion($0) }
            return "综合: " + subSummaries.joined(separator: "&")
        }
    }

    // MARK: - Memory Decay Implementation

    /// 执行记忆衰减规则
    /// L1在应用退出时清空、L2超过30天的每日Markdown文件自动删除、L3/L4永久保留
    /// - Returns: 清理的记忆条目数量
    func executeDecayRules() -> Int {
        var cleanedCount = 0

        // L1即时记忆：清空内存索引
        cleanedCount += instantMemoryIndex.count
        instantMemoryIndex.removeAll()

        // L2短期记忆：清理超过30天的文件
        let retentionDays = 30
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date())!

        let dailyDir = MemoryStoragePath.dailyDirectory
        if FileManager.default.fileExists(atPath: dailyDir.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: dailyDir, includingPropertiesForKeys: nil)
                for file in files where file.pathExtension == "md" {
                    // 从文件名提取日期
                    let fileName = file.lastPathComponent
                    let dateStr = fileName.replacingOccurrences(of: "memory-", with: "")
                        .replacingOccurrences(of: ".md", with: "")

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"

                    if let fileDate = dateFormatter.date(from: dateStr),
                       fileDate < cutoffDate {
                        try FileManager.default.removeItem(at: file)
                        shortTermMemoryIndex.removeValue(forKey: file)
                        cleanedCount += 1
                        print("🗑️ Deleted old memory file: \(fileName)")
                    }
                }
            } catch {
                print("⚠️ Failed to cleanup L2 memory files: \(error.localizedDescription)")
            }
        }

        // L3/L4: 永久保留，不执行清理

        return cleanedCount
    }

    /// 清空L1即时记忆（应用退出时调用）
    func clearInstantMemory() {
        instantMemoryIndex.removeAll()
        print("🧹 Cleared L1 instant memory")
    }

    /// 手动清理接口（用于用户主动清理）
    /// - Parameter layer: 要清理的记忆层级
    /// - Returns: 清理的记忆条目数量
    func manualCleanup(layer: MemoryLayer) -> Int {
        switch layer {
        case .instant:
            let count = instantMemoryIndex.count
            instantMemoryIndex.removeAll()
            return count
        case .shortTerm:
            return executeDecayRules()  // 执行30天清理规则
        case .mediumTerm, .longTerm:
            // L3/L4永久保留，手动清理需要用户确认
            print("⚠️ L3/L4 memories are permanent. Use with caution.")
            return 0
        }
    }

    // MARK: - Instant Memory Management

    /// 添加L1即时记忆条目
    /// - Parameter item: 记忆条目
    func addToInstantMemory(_ item: MemoryItem) {
        // 检查容量限制
        if instantMemoryIndex.count >= MemoryLayer.instant.capacityLimit {
            // 移除最旧的条目
            instantMemoryIndex.removeFirst()
        }
        instantMemoryIndex.append(item)
    }

    /// 获取L1即时记忆条目
    /// - Returns: 当前即时记忆列表
    func getInstantMemory() -> [MemoryItem] {
        return instantMemoryIndex
    }

    // MARK: - Cache Management

    /// 清理搜索缓存
    func clearSearchCache() {
        searchCache.removeAll()
    }

    /// 检查缓存是否有效
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的结果（如果有效）
    private func checkCache(_ key: String) -> MemorySearchResult? {
        if let cached = searchCache[key] {
            let elapsed = Date().timeIntervalSince(cached.timestamp)
            if elapsed < cacheValidDuration {
                return cached.result
            } else {
                searchCache.removeValue(forKey: key)
            }
        }
        return nil
    }

    /// 存储搜索结果到缓存
    /// - Parameters:
    ///   - key: 缓存键
    ///   - result: 搜索结果
    private func storeCache(_ key: String, _ result: MemorySearchResult) {
        searchCache[key] = (result: result, timestamp: Date())
    }

    // MARK: - Index Refresh

    /// 刷新所有索引（用于新记忆添加后）
    func refreshIndices() {
        loadAllIndices()
        clearSearchCache()
    }

    // MARK: - Importance Score Update (for LLM Analysis)

    /// 更新对话的重要性评分
    /// 用于LLM深层分析后更新记忆的重要性评分
    /// - Parameters:
    ///   - timestamp: 对话时间戳
    ///   - newScore: 新的重要性评分
    /// - Returns: 更新成功返回true
    func updateImportanceScore(timestamp: Date, newScore: Int) -> Bool {
        print("🧠 MemoryIndexManager: Updating importance score to \(newScore) for timestamp \(timestamp)")

        // 更新L1即时记忆索引
        for i in instantMemoryIndex.indices {
            if Calendar.current.isDate(instantMemoryIndex[i].timestamp, equalTo: timestamp, toGranularity: .second) {
                instantMemoryIndex[i].importanceScore = newScore
                print("🧠 MemoryIndexManager: Updated L1 instant memory")
                return true
            }
        }

        // 更新L2短期记忆（Markdown文件）
        let dailyDir = MemoryStoragePath.dailyDirectory
        if FileManager.default.fileExists(atPath: dailyDir.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: dailyDir, includingPropertiesForKeys: nil)
                for file in files where file.pathExtension == "md" {
                    if updateImportanceInMarkdownFile(file, timestamp: timestamp, newScore: newScore) {
                        print("🧠 MemoryIndexManager: Updated L2 short-term memory in file")
                        // 重新加载索引
                        loadShortTermIndex()
                        return true
                    }
                }
            } catch {
                print("⚠️ MemoryIndexManager: Failed to update L2 memory - \(error.localizedDescription)")
            }
        }

        print("🧠 MemoryIndexManager: No matching conversation found for timestamp")
        return false
    }

    /// 更新Markdown文件中对话的重要性评分
    /// - Parameters:
    ///   - file: Markdown文件路径
    ///   - timestamp: 对话时间戳
    ///   - newScore: 新的重要性评分
    /// - Returns: 更新成功返回true
    private func updateImportanceInMarkdownFile(_ file: URL, timestamp: Date, newScore: Int) -> Bool {
        do {
            let content = try String(contentsOf: file, encoding: .utf8)

            // 时间格式化
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let targetTimeStr = formatter.string(from: timestamp)

            // 检查是否包含该时间戳的对话
            if !content.contains("## \(targetTimeStr)") {
                return false
            }

            // 替换 importanceScore
            var updatedContent = content

            // 找到该对话块并更新重要性评分
            let pattern = "## \(targetTimeStr)\n---\n([\\s\\S]*?)---"

            if let range = updatedContent.range(of: pattern, options: .regularExpression) {
                let blockContent = String(updatedContent[range])

                // 替换 importanceScore 行
                let updatedBlock = blockContent.replacingOccurrences(
                    of: "importanceScore: \\d+",
                    with: "importanceScore: \(newScore)",
                    options: .regularExpression
                )

                updatedContent.replaceSubrange(range, with: updatedBlock)

                // 写回文件
                try updatedContent.write(to: file, atomically: true, encoding: .utf8)
                print("🧠 MemoryIndexManager: Updated importanceScore in \(file.lastPathComponent)")
                return true
            }

            return false
        } catch {
            print("⚠️ MemoryIndexManager: Failed to update markdown file - \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    /// 返回数组中唯一元素
    func unique() -> [Element] {
        return Array(Set(self))
    }
}