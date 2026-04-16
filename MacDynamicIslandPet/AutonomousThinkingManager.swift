import Foundation
import Combine
import AppKit

// MARK: - News Category Enum

/// 新闻领域枚举
///
/// 定义精灵自主思考关注的6个新闻领域
/// US-010: 自主思考系统设计与实现
enum NewsCategory: String, Codable, CaseIterable {
    /// 科技新闻
    case tech = "科技"
    /// 娱乐新闻
    case entertainment = "娱乐"
    /// 生活新闻
    case life = "生活"
    /// 游戏新闻
    case games = "游戏"
    /// 财经新闻
    case finance = "财经"
    /// 体育新闻
    case sports = "体育"

    /// 获取对应的RSS源URL（国内可访问，已验证可用）
    var rssSource: URL? {
        switch self {
        case .tech:
            // IT之家 - 科技新闻（可用）
            return URL(string: "https://www.ithome.com/rss/")
        case .entertainment:
            // 少数派 - 生活方式/娱乐（可用）
            return URL(string: "https://sspai.com/feed")
        case .games:
            // 36氪 - 科技创业新闻，包含游戏相关（可用）
            return URL(string: "https://36kr.com/feed")
        case .life:
            // 少数派 - 生活技巧（可用）
            return URL(string: "https://sspai.com/feed")
        case .finance:
            // IT之家 - 科技财经新闻（可用）
            return URL(string: "https://www.ithome.com/rss/")
        case .sports:
            // 36氪 - 新闻资讯（可用）
            return URL(string: "https://36kr.com/feed")
        }
    }

    /// 获取领域的中文显示名称
    var displayName: String {
        return self.rawValue
    }

    /// 获取领域的图标
    var icon: String {
        switch self {
        case .tech: return "💻"
        case .entertainment: return "🎬"
        case .life: return "🏠"
        case .games: return "🎮"
        case .finance: return "💰"
        case .sports: return "⚽"
        }
    }
}

// MARK: - Autonomous Thought Structure

/// 自主思考记录结构体
///
/// 存储精灵每次自主思考的完整信息
/// US-010: 自主思考系统设计与实现
struct AutonomousThought: Codable, Identifiable {
    /// 唯一标识
    var id: String

    /// 思考时间
    var timestamp: Date

    /// 新闻领域
    var newsCategory: NewsCategory

    /// 新闻标题
    var newsTitle: String

    /// 新闻摘要
    var newsSummary: String

    /// 精灵观点
    var spriteOpinion: String

    /// 性格参数影响说明
    var personalityInfluence: [String]

    /// 气泡是否已触发
    var bubbleTriggered: Bool

    /// 创建新的自主思考记录
    static func create(
        category: NewsCategory,
        title: String,
        summary: String,
        opinion: String,
        influences: [String]
    ) -> AutonomousThought {
        return AutonomousThought(
            id: UUID().uuidString,
            timestamp: Date(),
            newsCategory: category,
            newsTitle: title,
            newsSummary: summary,
            spriteOpinion: opinion,
            personalityInfluence: influences,
            bubbleTriggered: false
        )
    }
}

// MARK: - Autonomous Thinking Manager

/// 自主思考管理器
///
/// 管理精灵的自主思考行为，包括定时触发、新闻浏览、观点生成、气泡触发
/// US-010: 自主思考系统设计与实现
class AutonomousThinkingManager {
    /// 共享单例实例
    static let shared = AutonomousThinkingManager()

    /// 自主思考历史存储文件路径
    private var thoughtsFilePath: URL {
        return MemoryStoragePath.autonomousDirectory.appendingPathComponent("thoughts-history.json")
    }

    /// 自主思考历史缓存（最多保留100条）
    private var thoughtsCache: [AutonomousThought] = []

    /// 定时器 - 每小时触发一次自主思考
    private var hourlyTimer: Timer?

    /// 当前是否正在思考（避免重复触发）
    private var isThinking: Bool = false

    /// 思考触发间隔（秒）
    private let thinkingInterval: TimeInterval = 3600  // 1小时

    /// 观点气泡触发概率（测试时改为100%，正常使用可改回0.3即30%）
    private let opinionBubbleProbability: Double = 1.0  // 100%（方便测试）

    /// 新闻获取器
    private let newsFetcher: NewsFetcher = NewsFetcher.shared

    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 加载历史记录
        loadThoughtsHistory()

        // 设置定时器
        setupHourlyTimer()
    }

    deinit {
        hourlyTimer?.invalidate()
    }

    // MARK: - Timer Setup

    /// 设置每小时触发定时器
    private func setupHourlyTimer() {
        // 取消现有定时器
        hourlyTimer?.invalidate()

        // 设置每小时触发
        hourlyTimer = Timer.scheduledTimer(
            withTimeInterval: thinkingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performAutonomousThinking()
        }

        // 添加到Common模式确保在UI交互时也能触发
        RunLoop.current.add(hourlyTimer!, forMode: .common)

        print("🧠 AutonomousThinkingManager: Hourly timer setup - interval: \(thinkingInterval)s")
    }

    /// 手动触发自主思考（用于测试）
    func triggerManually() {
        performAutonomousThinking()
    }

    // MARK: - Autonomous Thinking Process

    /// 执行自主思考流程
    private func performAutonomousThinking() {
        print("🟣 [US-010] ========== 开始自主思考流程 ==========")

        // 检查是否正在思考
        guard !isThinking else {
            print("🟣 [US-010] 已在思考中，跳过本次触发")
            return
        }

        // 检查是否有气泡显示或精灵移动（避免冲突）
        if SelfTalkManager.shared.shouldShowBubble {
            print("🟣 [US-010] 当前有气泡显示，延迟思考5分钟")
            // 延迟5分钟后再次尝试
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                self?.performAutonomousThinking()
            }
            return
        }

        isThinking = true
        print("🟣 [US-010] 开始思考任务...")

        // 后台线程执行思考任务
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.executeThinkingTask()
        }
    }

    /// 执行具体的思考任务
    private func executeThinkingTask() {
        print("🟣 [US-010] executeThinkingTask - 开始获取新闻...")
        // 1. 获取用户关注的新闻领域
        let enabledCategories = getEnabledNewsCategories()
        print("🟣 [US-010] 用户关注的新闻领域: \(enabledCategories.map { $0.displayName })")

        if enabledCategories.isEmpty {
            print("🟣 [US-010] 没有启用的新闻领域，跳过思考")
            isThinking = false
            return
        }

        // 2. 随机选择一个领域
        let selectedCategory = enabledCategories.randomElement()!
        print("🟣 [US-010] 选择的新闻领域: \(selectedCategory.displayName)")

        // 3. 获取该领域的新闻
        newsFetcher.fetchNews(for: selectedCategory) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let newsItems):
                if newsItems.isEmpty {
                    print("🧠 AutonomousThinkingManager: No news fetched for \(selectedCategory.displayName)")
                    self.isThinking = false
                    return
                }

                // 随机选择一条新闻
                let selectedNews = newsItems.randomElement()!

                // 4. 生成精灵观点
                self.generateSpriteOpinion(
                    category: selectedCategory,
                    news: selectedNews
                ) { opinionResult in
                    switch opinionResult {
                    case .success(let thought):
                        // 5. 保存思考记录
                        self.saveThought(thought)

                        // 6. 触发观点气泡（30%概率）
                        self.triggerOpinionBubble(thought)

                        self.isThinking = false
                        print("🧠 AutonomousThinkingManager: Thinking complete - \(thought.spriteOpinion)")

                    case .failure(let error):
                        print("🧠 AutonomousThinkingManager: Opinion generation failed - \(error.localizedDescription)")
                        self.isThinking = false
                    }
                }

            case .failure(let error):
                print("🧠 AutonomousThinkingManager: News fetch failed - \(error.localizedDescription)")
                self.isThinking = false
            }
        }
    }

    // MARK: - News Categories Configuration

    /// 获取用户启用的新闻领域列表
    /// - Returns: 启用的新闻领域数组
    private func getEnabledNewsCategories() -> [NewsCategory] {
        // 从config.json读取用户配置的感兴趣领域
        guard let config = AppConfigManager.shared.config else {
            // 默认启用tech、entertainment、games
            return [.tech, .entertainment, .games]
        }

        // 从config.newsInterests读取（US-011会添加此字段）
        // 如果字段不存在，使用默认值
        if let newsInterests = config.newsInterests {
            return newsInterests.compactMap { NewsCategory(rawValue: $0) }
        }

        // 默认值
        return [.tech, .entertainment, .games]
    }

    /// 更新新闻领域配置
    /// 在US-011保存配置后调用此方法立即生效
    func updateNewsCategories() {
        let categories = getEnabledNewsCategories()
        print("🧠 AutonomousThinkingManager: News categories updated - \(categories.map { $0.displayName })")
    }

    // MARK: - Opinion Generation

    /// 生成精灵对新闻的观点
    /// - Parameters:
    ///   - category: 新闻领域
    ///   - news: 新闻条目
    ///   - completion: 完成回调
    private func generateSpriteOpinion(
        category: NewsCategory,
        news: NewsItem,
        completion: @escaping (Result<AutonomousThought, LLMError>) -> Void
    ) {
        // 获取性格参数
        let personality = PersonalityManager.shared.currentProfile
        let personalityDescription = PersonalityStyleMapping.generateStyleDescription(for: personality)
        let toneStyle = PersonalityStyleMapping.generateToneStylePrompt(for: personality)

        // 获取进化等级
        let evolutionState = EvolutionManager.shared.getEvolutionState()
        // 气泡显示长度（根据进化等级）
        let bubbleMaxLength = evolutionState.maxBubbleLength
        // 观点内容长度（固定100字，用于知识积累，更详细）
        let opinionMaxLength = 100

        // 构建Prompt
        let prompt = """
作为性格为\(personalityDescription)的桌面精灵，性格参数：外向度\(personality.extroversion)(高=主动活跃低=安静内敛)、好奇心\(personality.curiosity)(高=喜欢探索新话题低=专注熟悉领域)、粘人程度\(personality.clinginess)(高=渴望互动低=独立自主)、幽默感\(personality.humor)(高=调侃幽默低=正经严肃)、温柔度\(personality.gentleness)(高=关心体贴低=直接表达)、叛逆度\(personality.rebellion)(高=搞怪吐槽低=温和配合)。

当前状态：与用户关系\(evolutionState.relationshipStage.displayName)(Lv\(evolutionState.currentLevel.levelNumber))、互动天数\(evolutionState.daysTogether)天。

看到了一条\(category.displayName)新闻：
标题：\(news.title)
摘要：\(news.summary)

请用有趣的方式表达你对这条新闻的看法（不超过\(opinionMaxLength)字），要包含：
1. 你的观点和感受
2. 为什么觉得有趣/重要/无聊
3. 可能和主人的关联（如果相关）
体现你的性格特点，保持\(toneStyle)的语气。只输出观点内容不要解释。
"""

        // 调用LLM生成观点
        LLMService.shared.sendMessage(userMessage: prompt, context: nil) { result in
            switch result {
            case .success(let opinion):
                // 记录性格参数影响说明
                var influences: [String] = []

                if personality.extroversion >= 70 {
                    influences.append("外向度高→主动表达观点")
                }
                if personality.curiosity >= 70 {
                    influences.append("好奇心高→对新新闻感兴趣")
                }
                if personality.humor >= 70 {
                    influences.append("幽默感高→调侃式表达")
                }
                if personality.rebellion >= 70 {
                    influences.append("叛逆度高→吐槽式观点")
                }

                let thought = AutonomousThought.create(
                    category: category,
                    title: news.title,
                    summary: news.summary,
                    opinion: opinion,
                    influences: influences
                )

                completion(.success(thought))

            case .failure:
                // 使用fallback观点
                let fallbackOpinion = self.fallbackOpinion(category: category)
                let thought = AutonomousThought.create(
                    category: category,
                    title: news.title,
                    summary: news.summary,
                    opinion: fallbackOpinion,
                    influences: ["LLM失败→使用fallback"]
                )

                completion(.success(thought))
            }
        }
    }

    /// Fallback观点（LLM调用失败时使用）
    /// - Parameter category: 新闻领域
    /// - Returns: 预设的fallback观点
    private func fallbackOpinion(category: NewsCategory) -> String {
        let fallbacks: [String] = [
            "\(category.icon) 看到这条\(category.displayName)新闻了，虽然没太看懂内容，但感觉挺有意思的，等有空再研究一下~",
            "\(category.displayName)领域最近好像有很多新动态，这条新闻让我有点好奇，不知道主人会不会也感兴趣呢？",
            "这条\(category.displayName)新闻看起来有点复杂，我得好好想想怎么看，不过感觉是个值得关注的事情。",
            "\(category.icon) 哇，\(category.displayName)方面又有新消息了！虽然不太确定具体怎么样，但感觉挺新鲜的~"
        ]
        return fallbacks.randomElement() ?? "看到新闻啦，这个领域最近挺活跃的~"
    }

    // MARK: - Opinion Bubble Trigger

    /// 触发观点气泡（100%概率显示完整内容）
    /// - Parameter thought: 自主思考记录
    private func triggerOpinionBubble(_ thought: AutonomousThought) {
        print("🟣 [US-010] triggerOpinionBubble - 触发观点气泡")

        // 直接使用完整观点，不截断
        let bubbleText = thought.spriteOpinion

        print("🟣 [US-010] ✅ 触发观点气泡: \(bubbleText)")

        DispatchQueue.main.async {
            // 使用统一接口显示气泡，不设置自定义隐藏时间
            // 让气泡视图的流式动画自己控制消失（长内容会停留更久）
            SelfTalkManager.shared.showExternalBubble(text: bubbleText)

            // 记录气泡显示
            SelfTalkManager.shared.recordBubbleDisplay(bubbleType: "opinion", content: bubbleText)

            print("🧠 AutonomousThinkingManager: Opinion bubble set - \(bubbleText)")
        }

        // 更新思考记录为已触发气泡
        updateThoughtBubbleTriggered(thought.id)
    }

    /// 截取观点用于气泡显示（保留完整观点用于知识积累）
    /// - Parameters:
    ///   - opinion: 完整观点
    ///   - maxLength: 最大显示长度
    /// - Returns: 截取后的短版本
    private func truncateOpinionForBubble(_ opinion: String, maxLength: Int) -> String {
        if opinion.count <= maxLength {
            return opinion
        }
        // 截取前maxLength个字符，加省略号
        let truncated = String(opinion.prefix(maxLength - 1))
        return truncated + "…"
    }

    // MARK: - Thoughts History Storage

    /// 加载自主思考历史
    private func loadThoughtsHistory() {
        MemoryStoragePath.ensureAllDirectoriesExist()

        guard FileManager.default.fileExists(atPath: thoughtsFilePath.path) else {
            thoughtsCache = []
            return
        }

        do {
            let data = FileManager.default.contents(atPath: thoughtsFilePath.path)
            if let data = data {
                thoughtsCache = try JSONDecoder().decode([AutonomousThought].self, from: data)
                print("🧠 AutonomousThinkingManager: Loaded \(thoughtsCache.count) thoughts from history")
            }
        } catch {
            print("⚠️ AutonomousThinkingManager: Failed to load thoughts history - \(error.localizedDescription)")
            thoughtsCache = []
        }
    }

    /// 保存思考记录
    /// - Parameter thought: 新的思考记录
    private func saveThought(_ thought: AutonomousThought) {
        // 添加到缓存
        thoughtsCache.append(thought)

        // 保留最近100条
        if thoughtsCache.count > 100 {
            thoughtsCache = thoughtsCache.suffix(100)
        }

        // 写入文件
        saveThoughtsToFile()
    }

    /// 更新思考记录的气泡触发状态
    /// - Parameter thoughtId: 思考记录ID
    private func updateThoughtBubbleTriggered(_ thoughtId: String) {
        if let index = thoughtsCache.firstIndex(where: { $0.id == thoughtId }) {
            thoughtsCache[index].bubbleTriggered = true
            saveThoughtsToFile()
        }
    }

    /// 保存思考历史到文件
    private func saveThoughtsToFile() {
        MemoryStoragePath.ensureAllDirectoriesExist()

        do {
            let data = try JSONEncoder().encode(thoughtsCache)
            try data.write(to: thoughtsFilePath)
            print("🧠 AutonomousThinkingManager: Saved \(thoughtsCache.count) thoughts to history")
        } catch {
            print("⚠️ AutonomousThinkingManager: Failed to save thoughts history - \(error.localizedDescription)")
        }
    }

    /// 获取最近的自主思考记录（供记忆检索使用）
    /// - Parameter limit: 返回数量限制
    /// - Returns: 最近的思考记录数组
    func getRecentThoughts(limit: Int = 10) -> [AutonomousThought] {
        return thoughtsCache.suffix(limit).reversed()
    }

    /// 获取精灵的知识摘要（最近思考过的新闻领域和观点）
    /// 用于融入记忆系统，让精灵能引用过去的思考
    /// - Returns: 知识摘要字符串
    func getKnowledgeSummary() -> String {
        let recentThoughts = getRecentThoughts(limit: 5)
        if recentThoughts.isEmpty {
            return "暂无新闻知识"
        }

        var summary = "最近关注的新闻：\n"
        for thought in recentThoughts {
            summary += "- [\(thought.newsCategory.displayName)] \(thought.newsTitle)：\(thought.spriteOpinion)\n"
        }
        return summary
    }

    /// 获取指定领域的思考记录
    /// - Parameter category: 新闻领域
    /// - Returns: 该领域的思考记录数组
    func getThoughtsByCategory(_ category: NewsCategory) -> [AutonomousThought] {
        return thoughtsCache.filter { $0.newsCategory == category }
    }

    /// 获取统计信息
    /// - Returns: 统计信息字符串
    func getStatisticsSummary() -> String {
        let total = thoughtsCache.count
        let triggered = thoughtsCache.filter { $0.bubbleTriggered }.count

        var categoryCounts: [NewsCategory: Int] = [:]
        for category in NewsCategory.allCases {
            categoryCounts[category] = thoughtsCache.filter { $0.newsCategory == category }.count
        }

        var summary = "累计自主思考\(total)次\n观点气泡触发\(triggered)次\n\n领域分布：\n"
        for category in NewsCategory.allCases {
            if let count = categoryCounts[category], count > 0 {
                summary += "\(category.icon) \(category.displayName): \(count)次\n"
            }
        }

        return summary
    }
}