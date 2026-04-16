import Foundation
import Combine

/// 模拟互动数据生成器
/// US-015: 生成30天的模拟互动数据用于长期运行稳定性测试
///
/// 生成内容包括：
/// - 每天10-20条对话记忆（存储到daily Markdown文件）
/// - 每天3-5个事件（存储到timeline.json）
/// - 每天20-50条情感变化记录（存储到emotion-history）
/// - 完整的用户画像数据（存储到user-profile.json）
/// - 30天的自主思考历史（存储到thoughts-history.json）
class SimulatedInteractionDataGenerator: ObservableObject {
    /// 共享单例实例
    static let shared = SimulatedInteractionDataGenerator()

    /// 记忆根目录
    private let memoryDirectory = MemoryStoragePath.memoryDirectory

    /// 是否正在生成数据
    @Published var isGenerating: Bool = false

    /// 生成进度（百分比）
    @Published var progress: Double = 0.0

    /// 生成状态描述
    @Published var statusDescription: String = ""

    /// 模拟对话模板
    private let conversationTemplates: [(user: String, pet: String)] = [
        ("今天心情不错", "开心就好~"),
        ("工作有点累", "辛苦了，休息一下~"),
        ("明天要开会", "会议加油~"),
        ("刚看完一个电影", "电影好看吗？"),
        ("周末想去爬山", "爬山挺好的~"),
        ("有点焦虑", "别担心，放松一下~"),
        ("代码写得顺利", "厉害呀~"),
        ("吃了个好吃的", "下次带我去~"),
        ("朋友来找我了", "朋友相聚开心~"),
        ("今天天气很好", "天气好心情也好~"),
        ("要加班了", "加班辛苦啦~"),
        ("学到了新东西", "学习进步了~"),
        ("有点无聊", "想聊聊天吗？"),
        ("看了一个好视频", "有趣的内容~"),
        ("准备睡觉了", "晚安~"),
        ("刚起床", "早安~"),
        ("想喝咖啡", "咖啡提神~"),
        ("今天吃了顿好的", "美味呀~"),
        ("遇到了一些问题", "慢慢解决~"),
        ("今天效率很高", "效率满满~")
    ]

    /// 模拟事件模板
    private let eventTemplates: [(type: EventType, description: String)] = [
        (EventType.birthday, "好友生日"),
        (EventType.anniversary, "认识纪念日"),
        (EventType.achievement, "完成项目"),
        (EventType.milestone, "认识新朋友"),
        (EventType.importantSchedule, "重要会议"),
        (EventType.importantSchedule, "体检预约")
    ]

    /// 模拟情感状态
    private let emotionStates: [UserEmotionState] = [
        .happy, .relaxed, .focused, .tired, .anxious, .relaxed, .excited, .stressed, .neutral
    ]

    private init() {}

    // MARK: - Data Generation

    /// 生成30天模拟数据
    /// - Parameter days: 要模拟的天数（默认30）
    /// - Returns: 是否生成成功
    func generate30DaySimulation(days: Int = 30) -> Bool {
        isGenerating = true
        progress = 0.0
        statusDescription = "开始生成模拟数据..."

        // 确保目录存在
        MemoryStoragePath.ensureAllDirectoriesExist()

        // 备份现有真实数据
        backupExistingData()

        // 清理现有数据（用于测试）
        clearExistingData()

        do {
            // 生成每天的对话记忆
            generateDailyConversations(days: days)

            // 生成事件时间线
            generateTimelineEvents(days: days)

            // 生成情感历史
            generateEmotionHistory(days: days)

            // 生成用户画像
            generateUserProfile()

            // 生成自主思考历史
            generateAutonomousThoughts(days: days)

            // 生成进化状态
            generateEvolutionState(days: days)

            progress = 100.0
            statusDescription = "模拟数据生成完成"
            isGenerating = false
            return true
        } catch {
            statusDescription = "生成失败: \(error.localizedDescription)"
            isGenerating = false
            return false
        }
    }

    /// 生成每日对话记忆
    /// - Parameter days: 天数
    private func generateDailyConversations(days: Int) {
        statusDescription = "生成每日对话记忆..."

        let calendar = Calendar.current
        let today = Date()

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today

            // 每天10-20条对话
            let conversationCount = Int.random(in: 10...20)

            // 创建当天的Markdown文件内容
            var fileContent = "---\n"
            fileContent += "date: \(formatDate(date))\n"
            fileContent += "---\n\n"

            for i in 0..<conversationCount {
                let template = conversationTemplates.randomElement() ?? conversationTemplates[0]
                let timestamp = formatTimestamp(date, hour: Int.random(in: 8...22), minute: Int.random(in: 0...59))

                // 随机话题和情感
                let topics = ConversationTopic.allCases.randomElement() ?? .daily
                let emotions = EmotionTag.allCases.randomElement() ?? .calm
                let importance = ImportanceKeyword.calculateImportance(content: template.user)

                fileContent += "## \(timestamp)\n"
                fileContent += "---\n"
                fileContent += "topics: [\(topics.rawValue)]\n"
                fileContent += "emotions: [\(emotions.rawValue)]\n"
                fileContent += "importanceScore: \(importance)\n"
                fileContent += "---\n"
                fileContent += "**User:** \(template.user)\n"
                fileContent += "**Pet:** \(template.pet)\n\n"
            }

            // 写入文件
            let fileName = "memory-\(formatDate(date)).md"
            let fileURL = MemoryStoragePath.dailyDirectory.appendingPathComponent(fileName)

            do {
                try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("⚠️ Failed to write daily memory file: \(error.localizedDescription)")
            }

            progress = Double(dayOffset) / Double(days) * 20
        }
    }

    /// 生成事件时间线
    /// - Parameter days: 天数
    private func generateTimelineEvents(days: Int) {
        statusDescription = "生成事件时间线..."

        let calendar = Calendar.current
        let today = Date()

        var events: [TimelineEvent] = []

        for dayOffset in stride(from: 0, to: days, by: Int.random(in: 3...7)) {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today

            // 每天3-5个事件（简化：每隔几天生成事件）
            let eventCount = Int.random(in: 3...5)

            for _ in 0..<eventCount {
                let template = eventTemplates.randomElement() ?? eventTemplates[0]
                let event = TimelineEvent.create(
                    date: date,
                    type: template.type,
                    description: template.description,
                    importance: Int.random(in: 5...10),
                    source: "simulation",
                    relatedConversations: [],
                    isRecurring: template.type == EventType.birthday
                )
                events.append(event)
            }
        }

        // 写入timeline.json
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(events)
            try data.write(to: MemoryStoragePath.timelineFile)
        } catch {
            print("⚠️ Failed to write timeline.json: \(error.localizedDescription)")
        }

        progress += 20
    }

    /// 生成情感历史
    /// - Parameter days: 天数
    private func generateEmotionHistory(days: Int) {
        statusDescription = "生成情感历史..."

        let calendar = Calendar.current
        let today = Date()

        var emotionHistory: [[String: Any]] = []

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today

            // 每天20-50条情感变化
            let emotionCount = Int.random(in: 20...50)

            for _ in 0..<emotionCount {
                let emotion = emotionStates.randomElement() ?? .neutral
                let hour = Int.random(in: 0...23)
                let minute = Int.random(in: 0...59)
                let timestamp = formatTimestamp(date, hour: hour, minute: minute)

                emotionHistory.append([
                    "timestamp": timestamp,
                    "emotion": emotion.rawValue,
                    "triggerSource": ["conversation", "screenActivity", "timeContext"].randomElement() ?? "timeContext",
                    "confidence": Double.random(in: 0.5...0.85)
                ])
            }
        }

        // 写入user-profile.json的emotionHistory字段
        var profile: [String: Any] = loadExistingProfile()
        profile["emotionHistory"] = Array(emotionHistory.suffix(100))  // 保留最近100条

        do {
            let data = try JSONSerialization.data(withJSONObject: profile, options: [.prettyPrinted])
            try data.write(to: MemoryStoragePath.userProfileFile)
        } catch {
            print("⚠️ Failed to write emotion history: \(error.localizedDescription)")
        }

        progress += 20
    }

    /// 生成用户画像
    private func generateUserProfile() {
        statusDescription = "生成用户画像..."

        var profile: [String: Any] = loadExistingProfile()

        // 用户偏好
        profile["preferences"] = [
            "likes": ["咖啡", "电影", "爬山", "学习", "朋友聚会"],
            "dislikes": ["加班", "周一", "下雨天"],
            "wants": ["去旅行", "学新技能"],
            "habits": ["早起", "喝咖啡"]
        ]

        // 情感模式
        profile["emotionPatterns"] = [
            "weeklyPattern": [
                "周一": "焦虑",
                "周五": "开心",
                "周六": "放松"
            ],
            "dailyPattern": [
                "早晨": "疲惫",
                "下午": "专注",
                "晚上": "放松"
            ],
            "emotionFrequency": [
                "开心": 0.25,
                "焦虑": 0.15,
                "放松": 0.20,
                "专注": 0.15,
                "平静": 0.25
            ],
            "lastUpdated": formatDate(Date())
        ]

        // 互动模式
        profile["interactionPatterns"] = [
            "hourlyInteractionCount": Int.random(in: 2...8),
            "bestInteractionTimeSlots": ["下午", "晚上"],
            "preferredBubbleType": "teasing",
            "ignoreRate": 0.2,
            "clickRate": 0.6,
            "avgResponseTime": 3.5
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: profile, options: [.prettyPrinted])
            try data.write(to: MemoryStoragePath.userProfileFile)
        } catch {
            print("⚠️ Failed to write user profile: \(error.localizedDescription)")
        }

        progress += 15
    }

    /// 生成自主思考历史
    /// - Parameter days: 天数
    private func generateAutonomousThoughts(days: Int) {
        statusDescription = "生成自主思考历史..."

        let calendar = Calendar.current
        let today = Date()

        var thoughts: [[String: Any]] = []

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today

            // 每天1-2条自主思考
            let thoughtCount = Int.random(in: 1...2)

            for _ in 0..<thoughtCount {
                let timestamp = formatTimestamp(date, hour: Int.random(in: 10...18), minute: 0)

                thoughts.append([
                    "id": UUID().uuidString,
                    "timestamp": timestamp,
                    "newsCategory": NewsCategory.allCases.randomElement()?.rawValue ?? "tech",
                    "newsTitle": "今日科技新闻",
                    "newsSummary": "这是一条模拟的新闻摘要",
                    "spriteOpinion": "我觉得挺有意思~",
                    "personalityInfluence": ["humor高", "curiosity高"],
                    "bubbleTriggered": Bool.random()
                ])
            }
        }

        // 写入thoughts-history.json
        do {
            let data = try JSONSerialization.data(withJSONObject: Array(thoughts.suffix(100)), options: [.prettyPrinted])
            try data.write(to: MemoryStoragePath.thoughtsHistoryFile)
        } catch {
            print("⚠️ Failed to write thoughts history: \(error.localizedDescription)")
        }

        progress += 15
    }

    /// 生成进化状态
    /// - Parameter days: 天数
    private func generateEvolutionState(days: Int) {
        statusDescription = "生成进化状态..."

        let level = EvolutionLevel.fromDays(days)

        let state = EvolutionState(
            currentLevel: level,
            daysTogether: days,
            emotionalDepthScore: Int.random(in: 30...70),
            knowledgeBreadthScore: Int.random(in: 20...50),
            expressionMaturityScore: Int.random(in: 20...60),
            milestones: generateMilestones(days: days),
            firstInteractionDate: Calendar.current.date(byAdding: .day, value: -days, to: Date()),
            lastUpdated: Date(),
            totalInteractionCount: days * Int.random(in: 10...20),
            totalConversationCount: days * Int.random(in: 5...15)
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: MemoryStoragePath.evolutionFile)
        } catch {
            print("⚠️ Failed to write evolution state: \(error.localizedDescription)")
        }

        progress += 10
    }

    /// 根据天数生成里程碑
    /// - Parameter days: 互动天数
    /// - Returns: 里程碑列表
    private func generateMilestones(days: Int) -> [EvolutionMilestone] {
        var milestones: [EvolutionMilestone] = []

        let milestoneDays = [7, 14, 30, 60, 90, 180, 365]

        for milestoneDay in milestoneDays {
            if days >= milestoneDay {
                let milestone = EvolutionMilestone.create(
                    name: "认识\(milestoneDay)天",
                    type: .daysMilestone
                )
                milestones.append(milestone)
            }
        }

        return milestones
    }

    // MARK: - Helper Methods

    /// 格式化日期
    /// - Parameter date: 日期
    /// - Returns: 格式化字符串
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 格式化时间戳
    /// - Parameters:
    ///   - date: 日期
    ///   - hour: 小时
    ///   - minute: 分钟
    /// - Returns: 格式化字符串
    private func formatTimestamp(_ date: Date, hour: Int, minute: Int) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute

        let fullDate = calendar.date(from: components) ?? date

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: fullDate)
    }

    /// 加载现有profile
    /// - Returns: 现有profile字典
    private func loadExistingProfile() -> [String: Any] {
        guard FileManager.default.fileExists(atPath: MemoryStoragePath.userProfileFile.path) else {
            return [:]
        }

        do {
            let data = FileManager.default.contents(atPath: MemoryStoragePath.userProfileFile.path)
            if let data = data {
                return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }
        } catch {
            print("⚠️ Failed to load existing profile: \(error.localizedDescription)")
        }

        return [:]
    }

    /// 备份现有数据
    private func backupExistingData() {
        // US-015: 测试完成后清理模拟数据，恢复真实用户数据
        // 这里可以添加备份逻辑，暂时简化处理
        print("🧪 SimulatedInteractionDataGenerator: Backing up existing data (simplified)")
    }

    /// 清理现有数据（用于测试）
    private func clearExistingData() {
        // 清理daily目录
        let dailyDir = MemoryStoragePath.dailyDirectory
        if FileManager.default.fileExists(atPath: dailyDir.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: dailyDir, includingPropertiesForKeys: nil)
                for file in files {
                    try FileManager.default.removeItem(at: file)
                }
            } catch {
                print("⚠️ Failed to clear daily directory: \(error.localizedDescription)")
            }
        }

        // 清理timeline.json
        if FileManager.default.fileExists(atPath: MemoryStoragePath.timelineFile.path) {
            try? FileManager.default.removeItem(at: MemoryStoragePath.timelineFile)
        }

        // 清理user-profile.json
        if FileManager.default.fileExists(atPath: MemoryStoragePath.userProfileFile.path) {
            try? FileManager.default.removeItem(at: MemoryStoragePath.userProfileFile)
        }

        // 清理thoughts-history.json
        if FileManager.default.fileExists(atPath: MemoryStoragePath.thoughtsHistoryFile.path) {
            try? FileManager.default.removeItem(at: MemoryStoragePath.thoughtsHistoryFile)
        }

        // 清理evolution.json
        if FileManager.default.fileExists(atPath: MemoryStoragePath.evolutionFile.path) {
            try? FileManager.default.removeItem(at: MemoryStoragePath.evolutionFile)
        }

        print("🧪 SimulatedInteractionDataGenerator: Existing data cleared")
    }

    /// 计算记忆目录总大小
    /// - Returns: 目录大小（字节）
    func calculateMemoryDirectorySize() -> UInt64 {
        let directory = memoryDirectory

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return 0
        }

        var totalSize: UInt64 = 0

        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])

            for file in files {
                if file.isDirectory {
                    // 递归计算子目录
                    let subFiles = try FileManager.default.contentsOfDirectory(at: file, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
                    for subFile in subFiles {
                        let attributes = try FileManager.default.attributesOfItem(atPath: subFile.path)
                        if let size = attributes[.size] as? UInt64 {
                            totalSize += size
                        }
                    }
                } else {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    if let size = attributes[.size] as? UInt64 {
                        totalSize += size
                    }
                }
            }
        } catch {
            print("⚠️ Failed to calculate directory size: \(error.localizedDescription)")
        }

        return totalSize
    }

    /// 获取目录大小描述
    /// - Parameter bytes: 字节数
    /// - Returns: 格式化的大小描述
    func formatSize(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            let kb = Double(bytes) / 1024
            return String(format: "%.2f KB", kb)
        }
    }
}

// MARK: - URL Extension for Directory Check

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}