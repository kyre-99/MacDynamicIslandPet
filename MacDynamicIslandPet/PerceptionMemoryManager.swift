import Foundation

/// Represents a single perception event (what the pet observed)
/// US-005: Struct for storing perception events
struct PerceptionEvent: Codable {
    /// Timestamp of the perception
    let timestamp: Date

    /// Time period label (早晨/上午/中午/下午/傍晚/晚上/深夜)
    let timePeriod: TimePeriod

    /// Name of the active application when perception occurred
    let appName: String

    /// Brief description of what the user was doing
    let activityDescription: String

    /// Optional: Summary of screenshot content (if visual analysis was used)
    let screenshotSummary: String?

    /// The pet's reaction/comment to the observation
    let petReaction: String?
}

/// Time period enum for categorizing perception events
/// US-005: Time periods defined in US-006 acceptance criteria
enum TimePeriod: String, Codable, CaseIterable {
    case morning     // 早晨 (6-9)
    case morningLate // 上午 (9-12)
    case noon        // 中午 (12-14)
    case afternoon   // 下午 (14-18)
    case evening     // 傍晚 (18-20)
    case night       // 晚上 (20-23)
    case lateNight   // 深夜 (23-6)

    /// Get time period from current time
    static func fromHour(_ hour: Int) -> TimePeriod {
        switch hour {
        case 6..<9: return .morning
        case 9..<12: return .morningLate
        case 12..<14: return .noon
        case 14..<18: return .afternoon
        case 18..<20: return .evening
        case 20..<23: return .night
        default: return .lateNight  // 23-6
        }
    }

    /// Chinese display name
    var displayName: String {
        switch self {
        case .morning: return "早晨"
        case .morningLate: return "上午"
        case .noon: return "中午"
        case .afternoon: return "下午"
        case .evening: return "傍晚"
        case .night: return "晚上"
        case .lateNight: return "深夜"
        }
    }
}

/// Manages perception memory storage and retrieval
/// US-005: Stores perception events for the pet to reference later
class PerceptionMemoryManager {
    /// Shared singleton instance
    static let shared = PerceptionMemoryManager()

    /// Memory directory path (same as conversation memory)
    private static let perceptionMemoryDirectory: URL = {
        let baseDir = AppConfigManager.appSupportDirectory
        return baseDir.appendingPathComponent("perception-memory")
    }()

    /// Date formatter for memory file names (YYYY-MM-DD)
    private let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Date formatter for timestamps
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// Full timestamp formatter
    private let fullTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private init() {
        ensureMemoryDirectoryExists()
    }

    /// Ensure the memory directory exists
    private func ensureMemoryDirectoryExists() {
        let dir = PerceptionMemoryManager.perceptionMemoryDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                print("📁 Created perception memory directory: \(dir.path)")
            } catch {
                print("⚠️ Failed to create perception memory directory: \(error.localizedDescription)")
            }
        }
    }

    /// Get today's perception memory file path
    func todayMemoryFilePath() -> URL {
        let today = fileDateFormatter.string(from: Date())
        return PerceptionMemoryManager.perceptionMemoryDirectory.appendingPathComponent("memory-\(today).md")
    }

    /// Save a perception event to today's memory file
    /// - Parameters:
    ///   - appName: The active application name
    ///   - activityDescription: Brief description of user activity
    ///   - screenshotSummary: Optional screenshot summary (if visual analysis used)
    ///   - petReaction: The pet's reaction to the observation
    func savePerception(
        appName: String,
        activityDescription: String,
        screenshotSummary: String? = nil,
        petReaction: String? = nil
    ) {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let timePeriod = TimePeriod.fromHour(hour)
        let timestamp = fullTimestampFormatter.string(from: now)

        let filePath = todayMemoryFilePath()

        // Build markdown entry
        // Format: 时间 | 应用 | 活动简述 | 小精灵的反应
        let entry = """
        ## \(timestamp) (\(timePeriod.displayName))

        **应用:** \(appName)

        **活动:** \(activityDescription)

        \(screenshotSummary != nil ? "**屏幕摘要:** \(screenshotSummary!)\n\n" : "")\(petReaction != nil ? "**小精灵:** \(petReaction!)\n" : "")

        """

        // Append to file (create if doesn't exist)
        do {
            if FileManager.default.fileExists(atPath: filePath.path) {
                let existingContent = try String(contentsOf: filePath, encoding: .utf8)
                let newContent = existingContent + entry
                try newContent.write(to: filePath, atomically: true, encoding: .utf8)
            } else {
                // Create new file with header
                let header = "# Perception Memory - \(fileDateFormatter.string(from: Date()))\n\n"
                let content = header + entry
                try content.write(to: filePath, atomically: true, encoding: .utf8)
            }
            print("💾 Saved perception to: \(filePath.path)")
        } catch {
            print("⚠️ Failed to save perception: \(error.localizedDescription)")
        }

        // Cleanup old files (reuse memoryRetentionDays config)
        cleanupOldMemoryFiles()
    }

    /// Get recent perception events (last N events from today and recent days)
    /// - Parameter count: Number of events to retrieve
    /// - Returns: Array of perception events as tuples (only user activities, not pet self-talk or pet app)
    func getRecentPerceptions(count: Int = 5) -> [(timestamp: String, timePeriod: String, appName: String, activity: String, reaction: String?)] {
        var perceptions: [(timestamp: String, timePeriod: String, appName: String, activity: String, reaction: String?)] = []

        // 过滤关键词 - 排除宠物自身行为的记录
        let petActivityKeywords = ["自言自语触发", "无聊触发", "被连续点击", "走到屏幕边缘", "停止移动"]

        // 过滤应用名 - 排除宠物自身应用
        let petAppNames = ["MacDynamicIslandPet", "小精灵", "小精灵情绪", "小精灵自身"]

        // Read today's file first, then previous days if needed
        let files = getRecentMemoryFiles(days: 30)

        for file in files {
            guard let content = readMemoryContent(from: file) else { continue }

            // Parse markdown entries
            let entries = content.components(separatedBy: "## ").dropFirst()

            for entry in entries.reversed() {
                let lines = entry.components(separatedBy: "\n")
                guard lines.count >= 3 else { continue }

                // Extract timestamp and time period from first line
                let headerLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
                // Parse "2026-04-14 19:30:00 (晚上)"
                let parts = headerLine.split(separator: "(")
                let timestamp = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let timePeriod = parts.count > 1 ? String(parts[1].dropLast()).trimmingCharacters(in: .whitespaces) : ""

                // Find 应用, 活动, and 小精灵 lines
                var appName: String = ""
                var activity: String = ""
                var reaction: String?

                for line in lines {
                    if line.hasPrefix("**应用:**") {
                        appName = line.replacingOccurrences(of: "**应用:** ", with: "")
                    } else if line.hasPrefix("**活动:**") {
                        activity = line.replacingOccurrences(of: "**活动:** ", with: "")
                    } else if line.hasPrefix("**小精灵:**") {
                        reaction = line.replacingOccurrences(of: "**小精灵:** ", with: "")
                    }
                }

                // 过滤宠物自身行为的记录 - 只保留用户实际活动
                let isPetActivity = petActivityKeywords.contains { keyword in
                    activity.contains(keyword)
                }

                // 过滤宠物自身应用
                let isPetApp = petAppNames.contains { petApp in
                    appName.contains(petApp)
                }

                if !appName.isEmpty && !activity.isEmpty && !isPetActivity && !isPetApp {
                    perceptions.insert((timestamp: timestamp, timePeriod: timePeriod, appName: appName, activity: activity, reaction: reaction), at: 0)

                    if perceptions.count >= count {
                        return perceptions
                    }
                }
            }
        }

        return perceptions
    }

    /// Get all perceptions from today
    /// - Returns: Array of all today's perception events
    func getTodayPerceptions() -> [(timestamp: String, timePeriod: String, appName: String, activity: String, reaction: String?)] {
        guard let content = readMemoryContent(from: todayMemoryFilePath()) else { return [] }

        var perceptions: [(timestamp: String, timePeriod: String, appName: String, activity: String, reaction: String?)] = []

        let entries = content.components(separatedBy: "## ").dropFirst()

        for entry in entries {
            let lines = entry.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            let headerLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = headerLine.split(separator: "(")
            let timestamp = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let timePeriod = parts.count > 1 ? String(parts[1].dropLast()).trimmingCharacters(in: .whitespaces) : ""

            var appName: String = ""
            var activity: String = ""
            var reaction: String?

            for line in lines {
                if line.hasPrefix("**应用:**") {
                    appName = line.replacingOccurrences(of: "**应用:** ", with: "")
                } else if line.hasPrefix("**活动:**") {
                    activity = line.replacingOccurrences(of: "**活动:** ", with: "")
                } else if line.hasPrefix("**小精灵:**") {
                    reaction = line.replacingOccurrences(of: "**小精灵:** ", with: "")
                }
            }

            if !appName.isEmpty && !activity.isEmpty {
                perceptions.append((timestamp: timestamp, timePeriod: timePeriod, appName: appName, activity: activity, reaction: reaction))
            }
        }

        return perceptions
    }

    /// Get perceptions from the last N minutes
    /// - Parameter minutes: Number of minutes to look back
    /// - Returns: Array of perception events within the time window
    func getPerceptionsInLast(minutes: Int) -> [(timestamp: String, timePeriod: String, appName: String, activity: String, reaction: String?)] {
        let cutoffTime = Date().addingTimeInterval(-TimeInterval(minutes * 60))
        let cutoffTimestamp = fullTimestampFormatter.string(from: cutoffTime)

        return getRecentPerceptions(count: 20).filter { event in
            event.timestamp >= cutoffTimestamp
        }
    }

    /// Get memory files for the last N days (including today)
    /// - Parameter days: Number of days to retrieve
    /// - Returns: Array of URLs to memory files, sorted by date (newest first)
    func getRecentMemoryFiles(days: Int = 7) -> [URL] {
        var files: [URL] = []
        let calendar = Calendar.current

        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let fileName = "memory-\(fileDateFormatter.string(from: date)).md"
            let filePath = PerceptionMemoryManager.perceptionMemoryDirectory.appendingPathComponent(fileName)

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
            print("⚠️ Failed to read perception memory file: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clean up memory files older than retention period
    func cleanupOldMemoryFiles() {
        let retentionDays = AppConfigManager.shared.config?.memoryRetentionDays ?? 30
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date())!

        do {
            let files = try FileManager.default.contentsOfDirectory(at: PerceptionMemoryManager.perceptionMemoryDirectory, includingPropertiesForKeys: nil)

            for file in files {
                guard file.pathExtension == "md" && file.lastPathComponent.hasPrefix("memory-") else { continue }

                let fileName = file.lastPathComponent
                let dateStr = fileName.replacingOccurrences(of: "memory-", with: "")
                    .replacingOccurrences(of: ".md", with: "")

                if let fileDate = fileDateFormatter.date(from: dateStr) {
                    if fileDate < cutoffDate {
                        try FileManager.default.removeItem(at: file)
                        print("🗑️ Deleted old perception memory file: \(fileName)")
                    }
                }
            }
        } catch {
            print("⚠️ Failed to cleanup perception memory files: \(error.localizedDescription)")
        }
    }

    /// Get memory context for comment generation (recent events summarized, max 3 to keep prompt short)
    /// - Parameter minutes: Minutes of recent events to include
    /// - Returns: Concatenated memory content as context string
    func getMemoryContextForComment(minutes: Int = 30) -> String {
        let recentEvents = getRecentPerceptions(count: 3)  // 只取3条，保持简洁

        if recentEvents.isEmpty {
            return ""
        }

        var context = "最近活动：\n"

        for event in recentEvents {
            context += "- \(event.appName): \(event.activity)\n"
        }

        return context
    }
}