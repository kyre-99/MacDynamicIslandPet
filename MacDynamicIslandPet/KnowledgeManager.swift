import Foundation

/// 知识管理器
/// 管理精灵的认知积累：
/// - current.md: 当前确认的知识（性格 + 知道的事情 + 不确定的事情）
/// - uncertain.md: 不确定/矛盾的知识
/// - knowledge/YYYY-MM-DD.md: 每日知识积累
class KnowledgeManager {
    static let shared = KnowledgeManager()

    // MARK: - 文件路径

    /// 知识目录
    private var knowledgeDirectory: URL {
        let baseDir = AppConfigManager.appSupportDirectory
        return baseDir.appendingPathComponent("knowledge")
    }

    /// 当前知识文件
    private var currentKnowledgePath: URL {
        return knowledgeDirectory.appendingPathComponent("current.md")
    }

    /// 不确定知识文件
    private var uncertainKnowledgePath: URL {
        return knowledgeDirectory.appendingPathComponent("uncertain.md")
    }

    /// 每日知识文件
    private func dailyKnowledgePath(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "knowledge-\(formatter.string(from: date)).md"
        // 每日知识放在 knowledge/knowledge/目录下
        return knowledgeDirectory.appendingPathComponent("knowledge").appendingPathComponent(fileName)
    }

    // MARK: - 初始化

    private init() {
        ensureDirectoriesExist()
        initializeFilesIfNeeded()
        print("🧠 KnowledgeManager initialized")
    }

    /// 确保目录存在
    private func ensureDirectoriesExist() {
        if !FileManager.default.fileExists(atPath: knowledgeDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: knowledgeDirectory, withIntermediateDirectories: true)
                print("📁 Created knowledge directory: \(knowledgeDirectory.path)")
            } catch {
                print("⚠️ Failed to create knowledge directory: \(error)")
            }
        }

        // 确保 knowledge/knowledge/ 子目录存在
        let dailyKnowledgeDir = knowledgeDirectory.appendingPathComponent("knowledge")
        if !FileManager.default.fileExists(atPath: dailyKnowledgeDir.path) {
            do {
                try FileManager.default.createDirectory(at: dailyKnowledgeDir, withIntermediateDirectories: true)
                print("📁 Created daily knowledge directory: \(dailyKnowledgeDir.path)")
            } catch {
                print("⚠️ Failed to create daily knowledge directory: \(error)")
            }
        }
    }

    /// 初始化文件（如果不存在）
    private func initializeFilesIfNeeded() {
        // 初始化 current.md（精灵初始认知 - 什么也不知道）
        if !FileManager.default.fileExists(atPath: currentKnowledgePath.path) {
            let initialContent = """
【我知道的事情】
我什么也不知道。

"""
            try? initialContent.write(to: currentKnowledgePath, atomically: true, encoding: .utf8)
            print("📝 Initialized current.md with initial knowledge")
        }

        // 初始化 uncertain.md（不确定的问题）
        if !FileManager.default.fileExists(atPath: uncertainKnowledgePath.path) {
            let initialUncertain = """
我是谁？
这个人是谁？
我应该怎么称呼这个人？

"""
            try? initialUncertain.write(to: uncertainKnowledgePath, atomically: true, encoding: .utf8)
            print("📝 Initialized uncertain.md with initial questions")
        }

        // 初始化今日知识文件
        let todayPath = dailyKnowledgePath(for: Date())
        if !FileManager.default.fileExists(atPath: todayPath.path) {
            let header = "# 知识积累 - \(DateFormatter().string(from: Date()))\n\n"
            try? header.write(to: todayPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - 读取知识

    /// 获取当前知识内容（用于System Prompt）
    func getCurrentKnowledge() -> String {
        guard let content = try? String(contentsOf: currentKnowledgePath, encoding: .utf8) else {
            return ""
        }
        return content
    }

    /// 获取不确定知识内容
    func getUncertainKnowledge() -> String {
        guard let content = try? String(contentsOf: uncertainKnowledgePath, encoding: .utf8) else {
            return ""
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 获取完整的System Prompt知识部分（包含精灵最近了解的内容）
    func getSystemPromptKnowledge() -> String {
        let current = getCurrentKnowledge()
        let uncertain = getUncertainKnowledge()

        var result = current

        // 添加精灵最近了解的内容（RSS自主思考知识）
        let autonomousKnowledge = AutonomousThinkingManager.shared.getKnowledgeSummary()
        if !autonomousKnowledge.isEmpty && autonomousKnowledge != "暂无新闻知识" {
            result += "\n\n【我最近了解到的内容】\n" + autonomousKnowledge
        }

        // 添加不确定知识
        if !uncertain.isEmpty {
            result += "\n\n【不确定的事情】（我可以问这个人确认）\n" + uncertain
        }

        return result
    }

    // MARK: - 更新知识

    /// 添加新知识（确认的知识）
    /// - Parameter knowledge: 新知识内容
    func addConfirmedKnowledge(_ knowledge: String) {
        guard !knowledge.isEmpty else { return }

        let current = getCurrentKnowledge()

        // 检查是否已经有这个知识
        if current.contains(knowledge) {
            print("🧠 Knowledge already exists: \(knowledge.prefix(20))...")
            return
        }

        var newContent = current

        // 在"我知道的事情"部分追加
        if let range = current.range(of: "【我知道的事情】") {
            let existingKnows = String(current[range.upperBound..<current.endIndex])
                .components(separatedBy: "【")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if existingKnows.contains("我刚来到这里") || existingKnows.contains("我什么也不知道") {
                // 第一次添加知识，替换初始认知
                newContent = current.replacingOccurrences(
                    of: "我什么也不知道。\n",
                    with: ""
                )
                // 在"我知道的事情"后面直接添加新知识
                let insertPoint = newContent.index(after: range.upperBound)
                newContent = String(newContent[..<insertPoint]) + knowledge + "\n" + String(newContent[insertPoint...])
            } else {
                // 追加新知识
                let nextSectionStart = current[range.upperBound...].firstIndex(of: "【") ?? current.endIndex
                let insertPoint = current.index(before: nextSectionStart)
                newContent = String(current[..<insertPoint]) + knowledge + "\n" + String(current[insertPoint...])
            }
        }

        try? newContent.write(to: currentKnowledgePath, atomically: true, encoding: .utf8)
        print("🧠 Added confirmed knowledge: \(knowledge.prefix(30))...")

        // 检查新知识是否解决了不确定的问题，如果是则移除
        resolveUncertainQuestionsIfNeeded(newKnowledge: knowledge)
    }

    /// 检查新知识是否解决了不确定的问题
    private func resolveUncertainQuestionsIfNeeded(newKnowledge knowledge: String) {
        let uncertain = getUncertainKnowledge()
        var updatedUncertain = uncertain

        // 检查每个不确定问题是否已解决
        let lines = uncertain.components(separatedBy: "\n")
        for line in lines {
            let question = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !question.isEmpty else { continue }

            var isResolved = false

            // 判断问题是否已解决
            if question.contains("我是谁") && (knowledge.contains("名字") || knowledge.contains("叫")) {
                isResolved = true
            }
            if question.contains("怎么称呼") && (knowledge.contains("称呼") || knowledge.contains("叫")) {
                isResolved = true
            }
            if question.contains("这个人是谁") && (knowledge.contains("用户") || knowledge.contains("这个人")) {
                isResolved = true
            }

            if isResolved {
                updatedUncertain = updatedUncertain.replacingOccurrences(
                    of: question + "\n",
                    with: ""
                )
                print("🧠 Resolved uncertain question: \(question)")
            }
        }

        if updatedUncertain != uncertain {
            try? updatedUncertain.write(to: uncertainKnowledgePath, atomically: true, encoding: .utf8)
        }
    }

    /// 添加不确定知识（矛盾或待确认）
    /// - Parameter knowledge: 不确定的知识内容
    func addUncertainKnowledge(_ knowledge: String) {
        guard !knowledge.isEmpty else { return }

        let currentUncertain = getUncertainKnowledge()

        // 检查是否已经有
        if currentUncertain.contains(knowledge) {
            print("🧠 Uncertain knowledge already exists")
            return
        }

        var newContent = currentUncertain
        if newContent.isEmpty {
            newContent = knowledge + "\n"
        } else {
            newContent += knowledge + "\n"
        }

        try? newContent.write(to: uncertainKnowledgePath, atomically: true, encoding: .utf8)
        print("🧠 Added uncertain knowledge: \(knowledge.prefix(30))...")
    }

    /// 确认不确定知识（解决矛盾后）
    /// - Parameters:
    ///   - uncertainItem: 之前不确定的内容
    ///   - confirmedResult: 确认后的结果
    func confirmUncertainKnowledge(uncertainItem: String, confirmedResult: String) {
        // 从 uncertain.md 移除
        let currentUncertain = getUncertainKnowledge()
        let newUncertain = currentUncertain.replacingOccurrences(of: uncertainItem + "\n", with: "")
        try? newUncertain.write(to: uncertainKnowledgePath, atomically: true, encoding: .utf8)

        // 添加到 current.md
        addConfirmedKnowledge(confirmedResult)

        print("🧠 Confirmed uncertain knowledge: \(uncertainItem.prefix(20))... → \(confirmedResult.prefix(20))...")
    }

    /// 记录今日知识积累（原始记录，不带提取结果）
    /// - Parameters:
    ///   - userInput: 用户输入
    ///   - petResponse: 精灵回复
    func appendDailyKnowledgeRaw(userInput: String, petResponse: String) {
        let todayPath = dailyKnowledgePath(for: Date())

        let entry = """
## 对话 \(DateFormatter().string(from: Date()))
用户：\(userInput.prefix(100))
精灵：\(petResponse.prefix(100))

"""

        do {
            var content = try String(contentsOf: todayPath, encoding: .utf8)
            content += entry
            try content.write(to: todayPath, atomically: true, encoding: .utf8)
        } catch {
            // 文件不存在，创建新文件
            let header = "# 知识积累 - \(DateFormatter().string(from: Date()))\n\n"
            try? (header + entry).write(to: todayPath, atomically: true, encoding: .utf8)
        }

        print("📝 Appended daily knowledge (raw)")
    }

    /// 获取今日知识积累数量
    /// - Returns: 今日对话记录数量
    func getDailyKnowledgeCount() -> Int {
        let todayPath = dailyKnowledgePath(for: Date())
        guard let content = try? String(contentsOf: todayPath, encoding: .utf8) else {
            return 0
        }

        // 计算"## 对话"的出现次数
        let matches = content.components(separatedBy: "## 对话")
        return matches.count - 1
    }

    /// 获取今日知识积累原始内容
    /// - Returns: 今日知识积累文件内容
    func getTodayKnowledgeContent() -> String {
        let todayPath = dailyKnowledgePath(for: Date())
        return (try? String(contentsOf: todayPath, encoding: .utf8)) ?? ""
    }

    /// 清空今日知识积累（用于分析完成后）
    func clearTodayKnowledge() {
        let todayPath = dailyKnowledgePath(for: Date())
        let header = "# 知识积累 - \(DateFormatter().string(from: Date()))\n\n"
        try? header.write(to: todayPath, atomically: true, encoding: .utf8)
        print("📝 Cleared today's knowledge log")
    }

    /// 获取今日知识积累中的对话列表（用于构建对话历史）
    /// - Parameter count: 最大返回数量
    /// - Returns: 对话列表（userInput, petResponse）元组数组
    func getRecentConversations(count: Int = 20) -> [(userInput: String, petResponse: String)] {
        let todayPath = dailyKnowledgePath(for: Date())
        guard let content = try? String(contentsOf: todayPath, encoding: .utf8) else {
            return []
        }

        var conversations: [(userInput: String, petResponse: String)] = []

        // 解析格式：## 对话 ...\n用户：...\n精灵：...
        let entries = content.components(separatedBy: "## 对话")
        for entry in entries.dropFirst() { // 跳过第一个空元素
            let lines = entry.components(separatedBy: "\n")
            var userInput: String?
            var petResponse: String?

            for line in lines {
                if line.hasPrefix("用户：") {
                    userInput = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("精灵：") {
                    petResponse = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if let user = userInput, let pet = petResponse {
                conversations.append((user, pet))
            }
        }

        // 返回最近 count 条
        let start = max(0, conversations.count - count)
        return Array(conversations[start...])
    }

    /// 记录今日知识积累（带提取结果，用于批量分析后）
    /// - Parameters:
    ///   - userInput: 用户输入
    ///   - petResponse: 精灵回复
    ///   - extracted: 提取的知识
    func appendDailyKnowledge(userInput: String, petResponse: String, extracted: String) {
        let todayPath = dailyKnowledgePath(for: Date())

        let entry = """
## 对话 \(DateFormatter().string(from: Date()))
用户：\(userInput.prefix(50))...
精灵：\(petResponse.prefix(50))...
提取：\(extracted)

"""

        do {
            var content = try String(contentsOf: todayPath, encoding: .utf8)
            content += entry
            try content.write(to: todayPath, atomically: true, encoding: .utf8)
        } catch {
            // 文件不存在，创建新文件
            let header = "# 知识积累 - \(DateFormatter().string(from: Date()))\n\n"
            try? (header + entry).write(to: todayPath, atomically: true, encoding: .utf8)
        }

        print("📝 Appended daily knowledge")
    }

    // MARK: - 重置知识

    /// 重置所有知识（用于测试）
    func resetKnowledge() {
        try? FileManager.default.removeItem(at: currentKnowledgePath)
        try? FileManager.default.removeItem(at: uncertainKnowledgePath)
        initializeFilesIfNeeded()
        print("🧠 Knowledge reset")
    }
}