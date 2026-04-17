import Foundation

/// Manages conversation memory storage and retrieval
///
/// US-004: Enhanced with topic classification, emotion analysis, and importance scoring
/// L2 memory files now include metadata headers: date, topics, emotions, importanceScore
class MemoryManager {
    /// Shared singleton instance
    static let shared = MemoryManager()

    /// Memory directory path
    static let memoryDirectory: URL = {
        let baseDir = AppConfigManager.appSupportDirectory
        return baseDir.appendingPathComponent("memory")
    }()

    /// Date formatter for memory file names (YYYY-MM-DD)
    private let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Date formatter for conversation timestamps
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private init() {
        ensureMemoryDirectoryExists()
    }

    /// Ensure the memory directory exists
    private func ensureMemoryDirectoryExists() {
        let dir = MemoryManager.memoryDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                print("📁 Created memory directory: \(dir.path)")
            } catch {
                print("⚠️ Failed to create memory directory: \(error.localizedDescription)")
            }
        }
    }

    /// Get today's memory file path
    func todayMemoryFilePath() -> URL {
        let today = fileDateFormatter.string(from: Date())
        return MemoryManager.memoryDirectory.appendingPathComponent("memory-\(today).md")
    }

    /// Save a conversation to today's memory file
    /// US-004: Enhanced with topic classification, emotion analysis, and importance scoring
    /// - Parameters:
    ///   - userInput: The user's message
    ///   - petResponse: The pet's response
    func saveConversation(userInput: String, petResponse: String) {
        let filePath = todayMemoryFilePath()
        let timestamp = timestampFormatter.string(from: Date())

        // US-004: Classify conversation topics
        let topics = ConversationTopic.classify(content: userInput + " " + petResponse)

        // US-004: Detect conversation emotions
        let emotions = EmotionTag.quickDetect(content: userInput + " " + petResponse)

        // US-004: Calculate importance score
        let importanceScore = ImportanceKeyword.calculateImportance(content: userInput)

        // Build markdown entry with metadata header (US-004)
        let topicsStr = topics.map { $0.rawValue }.joined(separator: ", ")
        let emotionsStr = emotions.map { $0.rawValue }.joined(separator: ", ")

        let entry = """
        ## \(timestamp)
        ---
        topics: [\(topicsStr)]
        emotions: [\(emotionsStr)]
        importanceScore: \(importanceScore)
        ---
        **User:** \(userInput)

        **Pet:** \(petResponse)

        """

        // Append to file (create if doesn't exist)
        do {
            if FileManager.default.fileExists(atPath: filePath.path) {
                let existingContent = try String(contentsOf: filePath, encoding: .utf8)
                let newContent = existingContent + entry
                try newContent.write(to: filePath, atomically: true, encoding: .utf8)
            } else {
                // Create new file with header (US-004: Enhanced header format)
                let header = "# Memory - \(fileDateFormatter.string(from: Date()))\n\n"
                let content = header + entry
                try content.write(to: filePath, atomically: true, encoding: .utf8)
            }
            print("💾 Saved conversation to: \(filePath.path)")
            print("   Topics: \(topicsStr), Emotions: \(emotionsStr), Importance: \(importanceScore)")

            // Add to instant memory index
            let enhancedItem = EnhancedMemoryItem.create(
                userInput: userInput,
                petResponse: petResponse,
                topics: topics,
                emotions: emotions,
                importance: importanceScore
            )
            MemoryIndexManager.shared.addToInstantMemory(enhancedItem.toBaseMemoryItem(layer: .instant))

            MemoryCardManager.shared.ingestConversation(
                userInput: userInput,
                petResponse: petResponse,
                topics: topics,
                emotions: emotions,
                importanceScore: importanceScore
            )

            // Refresh memory indices
            MemoryIndexManager.shared.refreshIndices()

            // 记录到每日知识积累（原始记录，累积 20 条后批量分析）
            KnowledgeManager.shared.appendDailyKnowledgeRaw(
                userInput: userInput,
                petResponse: petResponse
            )

        } catch {
            print("⚠️ Failed to save conversation: \(error.localizedDescription)")
        }
    }

    /// Save a conversation with pre-analyzed metadata
    /// US-004: Alternative save method for when topics, emotions are already analyzed
    /// - Parameters:
    ///   - userInput: The user's message
    ///   - petResponse: The pet's response
    ///   - topics: Pre-analyzed topics
    ///   - emotions: Pre-analyzed emotions
    ///   - importanceScore: Pre-calculated importance score
    func saveConversationWithMetadata(
        userInput: String,
        petResponse: String,
        topics: [ConversationTopic],
        emotions: [EmotionTag],
        importanceScore: Int
    ) {
        let filePath = todayMemoryFilePath()
        let timestamp = timestampFormatter.string(from: Date())

        // Build markdown entry with metadata header
        let topicsStr = topics.map { $0.rawValue }.joined(separator: ", ")
        let emotionsStr = emotions.map { $0.rawValue }.joined(separator: ", ")

        let entry = """
        ## \(timestamp)
        ---
        topics: [\(topicsStr)]
        emotions: [\(emotionsStr)]
        importanceScore: \(importanceScore)
        ---
        **User:** \(userInput)

        **Pet:** \(petResponse)

        """

        // Append to file
        do {
            if FileManager.default.fileExists(atPath: filePath.path) {
                let existingContent = try String(contentsOf: filePath, encoding: .utf8)
                let newContent = existingContent + entry
                try newContent.write(to: filePath, atomically: true, encoding: .utf8)
            } else {
                let header = "# Memory - \(fileDateFormatter.string(from: Date()))\n\n"
                let content = header + entry
                try content.write(to: filePath, atomically: true, encoding: .utf8)
            }
            print("💾 Saved conversation with metadata to: \(filePath.path)")
        } catch {
            print("⚠️ Failed to save conversation: \(error.localizedDescription)")
        }
    }

    /// Get memory files for the last N days (including today)
    /// - Parameter days: Number of days to retrieve (default 7)
    /// - Returns: Array of URLs to memory files, sorted by date (newest first)
    func getRecentMemoryFiles(days: Int = 7) -> [URL] {
        var files: [URL] = []
        let calendar = Calendar.current

        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let fileName = "memory-\(fileDateFormatter.string(from: date)).md"
            let filePath = MemoryManager.memoryDirectory.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: filePath.path) {
                files.append(filePath)
            }
        }

        return files  // Newest first (today at index 0)
    }

    /// Read memory content from a file
    /// - Parameter fileURL: Path to the memory file
    /// - Returns: String content of the file, or nil if not found
    func readMemoryContent(from fileURL: URL) -> String? {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("⚠️ Failed to read memory file: \(error.localizedDescription)")
            return nil
        }
    }

    /// Get memory context for LLM (recent conversations summarized)
    /// - Parameter days: Number of days to include (default 7)
    /// - Returns: Concatenated memory content as context string
    func getMemoryContext(days: Int = 7) -> String {
        let files = getRecentMemoryFiles(days: days)
        var context = ""

        for file in files {
            if let content = readMemoryContent(from: file) {
                // Extract date from filename for context label
                let fileName = file.lastPathComponent
                let dateStr = fileName.replacingOccurrences(of: "memory-", with: "")
                    .replacingOccurrences(of: ".md", with: "")

                context += "【\(dateStr)】\n\(content)\n\n"
            }
        }

        return context
    }

    /// Get the most recent conversations from memory
    /// US-004: Enhanced to return with metadata
    /// - Parameter count: Number of recent conversations to retrieve
    /// - Returns: Array of EnhancedMemoryItem tuples
    func getRecentConversations(count: Int = 10) -> [EnhancedMemoryItem] {
        var conversations: [EnhancedMemoryItem] = []

        // Read today's file first, then previous days if needed
        let files = getRecentMemoryFiles(days: 30)

        for file in files {
            guard let content = readMemoryContent(from: file) else { continue }

            // Parse markdown entries with metadata headers
            let entries = content.components(separatedBy: "## ").dropFirst()

            for entry in entries.reversed() {
                let parsed = parseEnhancedEntry(entry)
                if let item = parsed {
                    conversations.insert(item, at: 0)

                    if conversations.count >= count {
                        return conversations
                    }
                }
            }
        }

        return conversations
    }

    /// Parse enhanced markdown entry with metadata headers
    /// US-004: Parse entries containing topics, emotions, importanceScore
    /// - Parameter entry: Entry string starting after "## "
    /// - Returns: Parsed EnhancedMemoryItem or nil if parsing fails
    private func parseEnhancedEntry(_ entry: String) -> EnhancedMemoryItem? {
        let lines = entry.components(separatedBy: "\n")
        guard lines.count >= 6 else { return nil }

        // Parse timestamp (first line)
        let timestamp = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse metadata header (between --- lines)
        var topics: [ConversationTopic] = []
        var emotions: [EmotionTag] = []
        var importanceScore = 1

        var inMetadataHeader = false
        var userInput: String?
        var petResponse: String?

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

                    for topicName in topicsStr.split(separator: ",") {
                        let topicStr = String(topicName).trimmingCharacters(in: .whitespacesAndNewlines)
                        if let topic = ConversationTopic(rawValue: topicStr) {
                            topics.append(topic)
                        }
                    }
                } else if trimmed.hasPrefix("emotions:") {
                    let emotionsStr = trimmed.replacingOccurrences(of: "emotions:", with: "")
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    for emotionName in emotionsStr.split(separator: ",") {
                        let emotionStr = String(emotionName).trimmingCharacters(in: .whitespacesAndNewlines)
                        if let emotion = EmotionTag(rawValue: emotionStr) {
                            emotions.append(emotion)
                        }
                    }
                } else if trimmed.hasPrefix("importanceScore:") {
                    let scoreStr = trimmed.replacingOccurrences(of: "importanceScore:", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    importanceScore = Int(scoreStr) ?? 1
                }
            } else {
                // Parse User and Pet lines
                if trimmed.hasPrefix("**User:**") {
                    userInput = trimmed.replacingOccurrences(of: "**User:** ", with: "")
                } else if trimmed.hasPrefix("**Pet:**") {
                    petResponse = trimmed.replacingOccurrences(of: "**Pet:** ", with: "")
                }
            }
        }

        if let user = userInput, let pet = petResponse {
            // Parse timestamp to Date
            let date = timestampFormatter.date(from: timestamp) ?? Date()

            return EnhancedMemoryItem(
                id: UUID().uuidString,
                timestamp: date,
                userInput: user,
                petResponse: pet,
                topics: topics,
                emotions: emotions,
                importanceScore: importanceScore
            )
        }

        return nil
    }

    /// Clean up memory files older than retention period
    func cleanupOldMemoryFiles() {
        let retentionDays = AppConfigManager.shared.config?.memoryRetentionDays ?? 30
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date())!

        do {
            let files = try FileManager.default.contentsOfDirectory(at: MemoryManager.memoryDirectory, includingPropertiesForKeys: nil)

            for file in files {
                guard file.pathExtension == "md" && file.lastPathComponent.hasPrefix("memory-") else { continue }

                // Extract date from filename
                let fileName = file.lastPathComponent
                let dateStr = fileName.replacingOccurrences(of: "memory-", with: "")
                    .replacingOccurrences(of: ".md", with: "")

                if let fileDate = fileDateFormatter.date(from: dateStr) {
                    if fileDate < cutoffDate {
                        try FileManager.default.removeItem(at: file)
                        print("🗑️ Deleted old memory file: \(fileName)")
                    }
                }
            }
        } catch {
            print("⚠️ Failed to cleanup memory files: \(error.localizedDescription)")
        }
    }

    /// Get list of all memory files for debugging/display
    func listAllMemoryFiles() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: MemoryManager.memoryDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "md" && $0.lastPathComponent.hasPrefix("memory-") }
        } catch {
            print("⚠️ Failed to list memory files: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - US-004: Topic and Emotion Search Methods

    /// Search conversations by topic
    /// - Parameter topic: Topic to search for
    /// - Returns: Matching enhanced memory items
    func searchByTopic(_ topic: ConversationTopic) -> [EnhancedMemoryItem] {
        var results: [EnhancedMemoryItem] = []
        let files = getRecentMemoryFiles(days: 30)

        for file in files {
            guard let content = readMemoryContent(from: file) else { continue }

            let entries = content.components(separatedBy: "## ").dropFirst()

            for entry in entries {
                if let item = parseEnhancedEntry(entry) {
                    if item.topics.contains(topic) {
                        results.append(item)
                    }
                }
            }
        }

        return results
    }

    /// Search conversations by emotion
    /// - Parameter emotion: Emotion to search for
    /// - Returns: Matching enhanced memory items
    func searchByEmotion(_ emotion: EmotionTag) -> [EnhancedMemoryItem] {
        var results: [EnhancedMemoryItem] = []
        let files = getRecentMemoryFiles(days: 30)

        for file in files {
            guard let content = readMemoryContent(from: file) else { continue }

            let entries = content.components(separatedBy: "## ").dropFirst()

            for entry in entries {
                if let item = parseEnhancedEntry(entry) {
                    if item.emotions.contains(emotion) {
                        results.append(item)
                    }
                }
            }
        }

        return results
    }

    }
