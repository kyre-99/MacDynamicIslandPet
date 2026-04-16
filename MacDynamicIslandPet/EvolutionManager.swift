import Foundation
import Combine

// MARK: - Evolution Dimension Enum

/// 进化维度枚举
///
/// 定义精灵进化的三个维度，每个维度代表精灵与用户关系的不同成长方向
/// US-008: 进化机制设计与实现
enum EvolutionDimension: String, Codable, CaseIterable {
    /// 情感深度 - 陌生→熟悉→亲密→知己
    case emotionalDepth = "情感深度"
    /// 知识广度 - 了解的话题领域数量
    case knowledgeBreadth = "知识广度"
    /// 表达成熟度 - 简单→复杂→细腻
    case expressionMaturity = "表达成熟度"

    /// 获取维度的描述说明
    var description: String {
        switch self {
        case .emotionalDepth:
            return "情感深度 - 与用户关系从陌生到知己的成长过程"
        case .knowledgeBreadth:
            return "知识广度 - 了解用户话题领域的数量增长"
        case .expressionMaturity:
            return "表达成熟度 - 表达能力从简单到细腻的提升"
        }
    }

    /// 获取维度的图标
    var icon: String {
        switch self {
        case .emotionalDepth: return "❤️"
        case .knowledgeBreadth: return "📚"
        case .expressionMaturity: return "✨"
        }
    }
}

// MARK: - Evolution Level Enum

/// 进化等级枚举
///
/// 定义精灵的10个进化等级，每个等级对应互动天数阈值
/// 等级决定精灵与用户的关系阶段和表达风格
/// US-008: 进化机制设计与实现
enum EvolutionLevel: String, Codable, CaseIterable {
    /// Lv1 陌生人 - 0-3天
    case lv1 = "Lv1陌生人"
    /// Lv2 初识 - 4-7天
    case lv2 = "Lv2初识"
    /// Lv3 熟悉 - 8-14天
    case lv3 = "Lv3熟悉"
    /// Lv4 朋友 - 15-30天
    case lv4 = "Lv4朋友"
    /// Lv5 好友 - 31-60天
    case lv5 = "Lv5好友"
    /// Lv6 知心 - 61-90天
    case lv6 = "Lv6知心"
    /// Lv7 闺蜜兄弟 - 91-120天
    case lv7 = "Lv7闺蜜兄弟"
    /// Lv8 挚友 - 121-180天
    case lv8 = "Lv8挚友"
    /// Lv9 知己 - 181-365天
    case lv9 = "Lv9知己"
    /// Lv10 终身伙伴 - >365天
    case lv10 = "Lv10终身伙伴"

    /// 获取等级的天数阈值上限
    var dayThreshold: Int {
        switch self {
        case .lv1: return 3
        case .lv2: return 7
        case .lv3: return 14
        case .lv4: return 30
        case .lv5: return 60
        case .lv6: return 90
        case .lv7: return 120
        case .lv8: return 180
        case .lv9: return 365
        case .lv10: return Int.max  // 无上限
        }
    }

    /// 获取等级的数字值
    var levelNumber: Int {
        switch self {
        case .lv1: return 1
        case .lv2: return 2
        case .lv3: return 3
        case .lv4: return 4
        case .lv5: return 5
        case .lv6: return 6
        case .lv7: return 7
        case .lv8: return 8
        case .lv9: return 9
        case .lv10: return 10
        }
    }

    /// 获取等级名称（不含Lv前缀）
    var displayName: String {
        switch self {
        case .lv1: return "陌生人"
        case .lv2: return "初识"
        case .lv3: return "熟悉"
        case .lv4: return "朋友"
        case .lv5: return "好友"
        case .lv6: return "知心"
        case .lv7: return "闺蜜兄弟"
        case .lv8: return "挚友"
        case .lv9: return "知己"
        case .lv10: return "终身伙伴"
        }
    }

    /// 获取等级描述
    var levelDescription: String {
        switch self {
        case .lv1: return "刚认识，还在熟悉中"
        case .lv2: return "开始了解彼此"
        case .lv3: return "逐渐熟悉起来"
        case .lv4: return "已经成为朋友"
        case .lv5: return "关系越来越亲密"
        case .lv6: return "能聊心事了"
        case .lv7: return "无话不谈的好伙伴"
        case .lv8: return "重要的陪伴"
        case .lv9: return "心灵相通"
        case .lv10: return "一年陪伴，终身伙伴"
        }
    }

    /// 获取等级对应的图标
    var icon: String {
        switch self {
        case .lv1: return "👋"
        case .lv2: return "🤝"
        case .lv3: return "😊"
        case .lv4: return "🌟"
        case .lv5: return "💫"
        case .lv6: return "💖"
        case .lv7: return "🌈"
        case .lv8: return "⭐"
        case .lv9: return "🌟"
        case .lv10: return "👑"
        }
    }

    /// 根据天数计算等级
    /// - Parameter days: 互动天数
    /// - Returns: 对应的进化等级
    static func fromDays(_ days: Int) -> EvolutionLevel {
        switch days {
        case 0...3: return .lv1
        case 4...7: return .lv2
        case 8...14: return .lv3
        case 15...30: return .lv4
        case 31...60: return .lv5
        case 61...90: return .lv6
        case 91...120: return .lv7
        case 121...180: return .lv8
        case 181...365: return .lv9
        default: return .lv10
        }
    }
}

// MARK: - Relationship Stage Enum

/// 关系阶段枚举
///
/// 对应进化等级的关系阶段名称（英文标识）
/// US-008: 进化机制设计与实现
enum RelationshipStage: String, Codable, CaseIterable {
    /// 陌生人 - Lv1
    case stranger
    /// 初识 - Lv2
    case acquaintance
    /// 熟悉 - Lv3
    case familiar
    /// 朋友 - Lv4
    case friend
    /// 好友 - Lv5
    case goodFriend
    /// 知心 - Lv6
    case confidant
    /// 闺蜜兄弟 - Lv7
    case bestFriend
    /// 挚友 - Lv8
    case closeFriend
    /// 知己 - Lv9
    case soulmate
    /// 终身伙伴 - Lv10
    case lifetimePartner

    /// 获取对应进化等级
    var evolutionLevel: EvolutionLevel {
        switch self {
        case .stranger: return .lv1
        case .acquaintance: return .lv2
        case .familiar: return .lv3
        case .friend: return .lv4
        case .goodFriend: return .lv5
        case .confidant: return .lv6
        case .bestFriend: return .lv7
        case .closeFriend: return .lv8
        case .soulmate: return .lv9
        case .lifetimePartner: return .lv10
        }
    }

    /// 获取中文显示名称
    var displayName: String {
        return evolutionLevel.displayName
    }
}

// MARK: - Evolution Milestone

/// 进化里程碑结构体
///
/// 记录精灵进化过程中解锁的里程碑事件
struct EvolutionMilestone: Codable, Identifiable {
    /// 里程碑唯一标识
    var id: String

    /// 里程碑名称
    var name: String

    /// 解锁时间
    var unlockedAt: Date

    /// 里程碑类型
    var type: MilestoneType

    /// 里程碑类型枚举
    enum MilestoneType: String, Codable {
        /// 天数里程碑 - 达到特定天数
        case daysMilestone
        /// 对话里程碑 - 首次深度对话等
        case conversationMilestone
        /// 关系里程碑 - 达到特定关系阶段
        case relationshipMilestone
        /// 互动里程碑 - 连续互动等
        case interactionMilestone
    }

    /// 获取里程碑图标
    var icon: String {
        switch type {
        case .daysMilestone: return "🏆"
        case .conversationMilestone: return "💬"
        case .relationshipMilestone: return "❤️"
        case .interactionMilestone: return "🎯"
        }
    }

    /// 创建新的里程碑
    static func create(name: String, type: MilestoneType) -> EvolutionMilestone {
        return EvolutionMilestone(
            id: UUID().uuidString,
            name: name,
            unlockedAt: Date(),
            type: type
        )
    }
}

// MARK: - Evolution State Structure

/// 进化状态结构体
///
/// 存储精灵的完整进化状态信息
/// US-008: 进化状态存储格式
struct EvolutionState: Codable {
    /// 当前进化等级
    var currentLevel: EvolutionLevel

    /// 互动天数（从首次互动开始计算）
    var daysTogether: Int

    /// 情感深度得分 (0-100)
    var emotionalDepthScore: Int

    /// 知识广度得分 (0-100，表示了解的话题领域数量)
    var knowledgeBreadthScore: Int

    /// 表达成熟度得分 (0-100)
    var expressionMaturityScore: Int

    /// 已解锁的里程碑列表
    var milestones: [EvolutionMilestone]

    /// 首次互动时间
    var firstInteractionDate: Date?

    /// 最后更新时间
    var lastUpdated: Date

    /// 总互动次数
    var totalInteractionCount: Int

    /// 总对话次数
    var totalConversationCount: Int

    /// 创建初始进化状态（新用户）
    static let initial = EvolutionState(
        currentLevel: .lv1,
        daysTogether: 0,
        emotionalDepthScore: 0,
        knowledgeBreadthScore: 0,
        expressionMaturityScore: 0,
        milestones: [],
        firstInteractionDate: nil,
        lastUpdated: Date(),
        totalInteractionCount: 0,
        totalConversationCount: 0
    )

    /// 获取当前关系阶段
    var relationshipStage: RelationshipStage {
        switch currentLevel {
        case .lv1: return .stranger
        case .lv2: return .acquaintance
        case .lv3: return .familiar
        case .lv4: return .friend
        case .lv5: return .goodFriend
        case .lv6: return .confidant
        case .lv7: return .bestFriend
        case .lv8: return .closeFriend
        case .lv9: return .soulmate
        case .lv10: return .lifetimePartner
        }
    }

    /// 获取下一等级进度百分比
    var nextLevelProgress: Double {
        if currentLevel == .lv10 {
            return 1.0  // 已达最高等级
        }

        let currentThreshold = currentLevel.dayThreshold
        let nextLevel = EvolutionLevel.allCases[currentLevel.levelNumber]
        let nextThreshold = nextLevel.dayThreshold

        if currentThreshold == Int.max || nextThreshold == Int.max {
            return 1.0
        }

        let progress = Double(daysTogether - currentThreshold) / Double(nextThreshold - currentThreshold)
        return max(0.0, min(1.0, progress))
    }

    /// 获取升级所需剩余天数
    var daysToNextLevel: Int {
        if currentLevel == .lv10 {
            return 0  // 已达最高等级
        }

        let nextLevel = EvolutionLevel.allCases[currentLevel.levelNumber]
        let nextThreshold = nextLevel.dayThreshold

        return max(0, nextThreshold - daysTogether)
    }

    /// 获取表达风格限制（最大气泡长度）
    var maxBubbleLength: Int {
        switch currentLevel {
        case .lv1, .lv2:
            return 25  // 简单问候式（提高避免截断）
        case .lv3, .lv4, .lv5:
            return 35  // 可引用记忆
        case .lv6, .lv7, .lv8:
            return 45  // 可表达深层情感
        case .lv9, .lv10:
            return 60  // 细腻表达
        }
    }

    /// 是否允许引用过去记忆和事件
    var canReferenceMemories: Bool {
        return currentLevel.levelNumber >= 4
    }

    /// 是否允许表达深层情感
    var canExpressDeepEmotions: Bool {
        return currentLevel.levelNumber >= 7
    }

    /// 是否允许使用细腻表达
    var canUseDetailedExpression: Bool {
        return currentLevel.levelNumber >= 9
    }
}

// MARK: - Evolution Trigger Types

/// 进化触发类型枚举
///
/// 定义触发进化的不同来源
enum EvolutionTrigger: String, Codable {
    /// 天数触发 - daysTogether达到Lv阈值
    case daysTrigger
    /// 对话深度触发 - important conversation
    case conversationTrigger
    /// 用户反馈触发 - high clickRate
    case feedbackTrigger
    /// 话题触发 - new topic area
    case topicTrigger
    /// 互动触发 - interaction count
    case interactionTrigger
}

// MARK: - Evolution Manager

/// 进化管理器
///
/// 管理精灵的进化状态，包括等级计算、里程碑解锁、风格影响
/// US-008: 进化机制设计与实现
class EvolutionManager {
    /// 共享单例实例
    static let shared = EvolutionManager()

    /// 进化状态存储文件路径
    private var evolutionFilePath: URL {
        return MemoryStoragePath.evolutionFile
    }

    /// 当前进化状态缓存
    private var evolutionStateCache: EvolutionState?

    /// 上次互动日期（用于计算天数）
    private var lastInteractionDate: Date?

    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()

    /// 每日检查定时器
    private var dailyCheckTimer: Timer?

    private init() {
        // 加载进化状态
        evolutionStateCache = loadEvolutionState()

        // 启动时立即检查天数更新（处理应用关闭期间的天数）
        checkDailyEvolution()

        // 设置每日检查定时器（凌晨检查天数更新）
        setupDailyCheckTimer()
    }

    deinit {
        dailyCheckTimer?.invalidate()
    }

    // MARK: - Timer Setup

    /// 设置每日检查定时器
    /// 每天凌晨00:00检查天数更新
    private func setupDailyCheckTimer() {
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day! += 1
        components.hour = 0
        components.minute = 0
        components.second = 0

        let nextMidnight = calendar.date(from: components) ?? now
        let initialDelay = nextMidnight.timeIntervalSince(now)

        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) { [weak self] in
            self?.checkDailyEvolution()
            self?.dailyCheckTimer = Timer.scheduledTimer(
                withTimeInterval: 86400,
                repeats: true
            ) { _ in
                self?.checkDailyEvolution()
            }
        }
    }

    /// 每日进化检查
    private func checkDailyEvolution() {
        guard let state = evolutionStateCache else { return }

        // 计算天数更新（按日历天计算，不是24小时）
        if let firstDate = state.firstInteractionDate {
            let calendar = Calendar.current
            // 计算从首次互动日期到今天跨越了多少个日历天
            let startOfDay1 = calendar.startOfDay(for: firstDate)
            let startOfDay2 = calendar.startOfDay(for: Date())
            let daysTogether = calendar.dateComponents([.day], from: startOfDay1, to: startOfDay2).day ?? 0

            if daysTogether > state.daysTogether {
                updateDaysTogether(daysTogether)
                print("📈 EvolutionManager: 天数更新为 \(daysTogether) 天")
            }
        }
    }

    // MARK: - Evolution State Management

    /// 加载进化状态
    /// - Returns: 进化状态数据
    func loadEvolutionState() -> EvolutionState {
        guard FileManager.default.fileExists(atPath: evolutionFilePath.path) else {
            return EvolutionState.initial
        }

        do {
            let data = FileManager.default.contents(atPath: evolutionFilePath.path)
            if let data = data {
                let state = try JSONDecoder().decode(EvolutionState.self, from: data)
                print("📈 EvolutionManager: Loaded evolution state - Level: \(state.currentLevel.rawValue), Days: \(state.daysTogether)")
                return state
            }
        } catch {
            print("⚠️ EvolutionManager: Failed to load evolution state - \(error.localizedDescription)")
        }

        return EvolutionState.initial
    }

    /// 保存进化状态
    /// - Parameter state: 进化状态数据
    private func saveEvolutionState(_ state: EvolutionState) {
        MemoryStoragePath.ensureAllDirectoriesExist()

        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: evolutionFilePath)
            evolutionStateCache = state
            print("📈 EvolutionManager: Saved evolution state - Level: \(state.currentLevel.rawValue)")
        } catch {
            print("⚠️ EvolutionManager: Failed to save evolution state - \(error.localizedDescription)")
        }
    }

    /// 获取当前进化状态
    /// - Returns: 当前进化状态
    func getEvolutionState() -> EvolutionState {
        if let cached = evolutionStateCache {
            print("🟣 [US-008] getEvolutionState - 使用缓存: \(cached.currentLevel.rawValue), 天数=\(cached.daysTogether)")
            return cached
        }
        let state = loadEvolutionState()
        print("🟣 [US-008] getEvolutionState - 加载文件: \(state.currentLevel.rawValue), 天数=\(state.daysTogether)")
        return state
    }

    // MARK: - Evolution Calculation

    /// 根据daysTogether、emotionalDepthScore、knowledgeBreadthScore、expressionMaturityScore综合计算当前等级
    /// - Parameter state: 进化状态
    /// - Returns: 计算出的进化等级
    func calculateLevel(from state: EvolutionState) -> EvolutionLevel {
        // 基础等级由天数决定
        let baseLevel = EvolutionLevel.fromDays(state.daysTogether)

        // 综合分数提升等级（分数>=80时可提前一级，分数>=90时可提前两级）
        let totalScore = state.emotionalDepthScore + state.knowledgeBreadthScore + state.expressionMaturityScore
        let avgScore = totalScore / 3

        var finalLevel = baseLevel

        // 高分数加速进化
        if avgScore >= 90 && baseLevel.levelNumber < 10 {
            finalLevel = EvolutionLevel.allCases[min(baseLevel.levelNumber + 1, 9)]
        } else if avgScore >= 80 && baseLevel.levelNumber < 10 {
            // 只在分数达到阈值时提前一级
            if baseLevel.levelNumber >= 3 {
                finalLevel = EvolutionLevel.allCases[baseLevel.levelNumber]
            }
        }

        return finalLevel
    }

    /// 计算进化等级（使用当前状态）
    /// - Returns: 当前应达到的进化等级
    func calculateLevel() -> EvolutionLevel {
        let state = getEvolutionState()
        return calculateLevel(from: state)
    }

    // MARK: - Evolution Update Methods

    /// 每次互动后检查是否满足升级条件
    /// 满足时升级并解锁对应里程碑
    /// - Parameter trigger: 进化触发类型
    func updateEvolution(trigger: EvolutionTrigger = .interactionTrigger) {
        print("🟣 [US-008] updateEvolution - 触发类型: \(trigger.rawValue)")
        var state = getEvolutionState()

        // 记录首次互动日期
        if state.firstInteractionDate == nil {
            state.firstInteractionDate = Date()
            print("🟣 [US-008] 记录首次互动日期")
        }

        // 更新互动计数
        state.totalInteractionCount += 1
        print("🟣 [US-008] 互动次数: \(state.totalInteractionCount)")
        state.lastUpdated = Date()

        // 根据触发类型更新分数
        switch trigger {
        case .daysTrigger:
            // 天数触发已在checkDailyEvolution中处理
            break
        case .conversationTrigger:
            // 重要对话增加情感深度
            state.emotionalDepthScore = min(100, state.emotionalDepthScore + 5)
        case .feedbackTrigger:
            // 高点击率增加表达成熟度
            state.expressionMaturityScore = min(100, state.expressionMaturityScore + 3)
        case .topicTrigger:
            // 新话题增加知识广度
            state.knowledgeBreadthScore = min(100, state.knowledgeBreadthScore + 2)
        case .interactionTrigger:
            // 一般互动增加情感深度（小幅度）
            state.emotionalDepthScore = min(100, state.emotionalDepthScore + 1)
        }

        // 重新计算等级
        let newLevel = calculateLevel(from: state)

        // 检查是否升级
        if newLevel.levelNumber > state.currentLevel.levelNumber {
            let oldLevel = state.currentLevel
            state.currentLevel = newLevel

            // 解锁升级里程碑
            let milestone = EvolutionMilestone.create(
                name: "成为\(newLevel.displayName)",
                type: .relationshipMilestone
            )
            state.milestones.append(milestone)

            print("📈 EvolutionManager: Level up! \(oldLevel.rawValue) → \(newLevel.rawValue)")
        }

        // 检查天数里程碑
        checkDaysMilestones(&state)

        // 检查互动里程碑
        checkInteractionMilestones(&state)

        // 保存状态
        saveEvolutionState(state)
    }

    /// 更新天数
    /// - Parameter days: 新的天数
    func updateDaysTogether(_ days: Int) {
        var state = getEvolutionState()
        state.daysTogether = days
        state.lastUpdated = Date()

        // 检查天数里程碑
        checkDaysMilestones(&state)

        // 重新计算等级
        let newLevel = calculateLevel(from: state)
        if newLevel != state.currentLevel {
            state.currentLevel = newLevel
        }

        saveEvolutionState(state)
        print("📈 EvolutionManager: Updated daysTogether to \(days), Level: \(state.currentLevel.rawValue)")
    }

    /// 记录对话（增加对话计数，检查对话里程碑）
    func recordConversation(importanceScore: Int = 1) {
        var state = getEvolutionState()
        state.totalConversationCount += 1

        // 高重要性对话增加情感深度
        if importanceScore >= 8 {
            state.emotionalDepthScore = min(100, state.emotionalDepthScore + 5)

            // 首次深度对话里程碑
            if !state.milestones.contains(where: { $0.name == "首次深度对话" }) {
                let milestone = EvolutionMilestone.create(
                    name: "首次深度对话",
                    type: .conversationMilestone
                )
                state.milestones.append(milestone)
                print("📈 EvolutionManager: Milestone unlocked - 首次深度对话")
            }
        }

        state.lastUpdated = Date()
        saveEvolutionState(state)
        updateEvolution(trigger: importanceScore >= 8 ? .conversationTrigger : .interactionTrigger)
    }

    /// 记录新话题领域（增加知识广度）
    func recordNewTopicArea() {
        updateEvolution(trigger: .topicTrigger)
        print("📈 EvolutionManager: New topic area recorded - knowledgeBreadth increased")
    }

    /// 根据用户反馈更新表达成熟度
    func updateFromFeedback(clickRate: Double) {
        if clickRate > 0.5 {
            updateEvolution(trigger: .feedbackTrigger)
            print("📈 EvolutionManager: High clickRate detected - expressionMaturity increased")
        }
    }

    // MARK: - Milestone Checks

    /// 检查天数里程碑
    /// - Parameter state: 进化状态引用
    private func checkDaysMilestones(_ state: inout EvolutionState) {
        let daysMilestones: [(days: Int, name: String)] = [
            (7, "认识7天"),
            (14, "认识14天"),
            (30, "认识30天"),
            (60, "认识60天"),
            (90, "认识90天"),
            (180, "认识180天"),
            (365, "一年陪伴")
        ]

        for milestone in daysMilestones {
            if state.daysTogether >= milestone.days &&
               !state.milestones.contains(where: { $0.name == milestone.name }) {
                let newMilestone = EvolutionMilestone.create(
                    name: milestone.name,
                    type: .daysMilestone
                )
                state.milestones.append(newMilestone)
                print("📈 EvolutionManager: Milestone unlocked - \(milestone.name)")
            }
        }
    }

    /// 检查互动里程碑
    /// - Parameter state: 进化状态引用
    private func checkInteractionMilestones(_ state: inout EvolutionState) {
        let interactionMilestones: [(count: Int, name: String)] = [
            (10, "10次互动"),
            (50, "50次互动"),
            (100, "100次互动"),
            (500, "500次互动"),
            (1000, "1000次互动")
        ]

        for milestone in interactionMilestones {
            if state.totalInteractionCount >= milestone.count &&
               !state.milestones.contains(where: { $0.name == milestone.name }) {
                let newMilestone = EvolutionMilestone.create(
                    name: milestone.name,
                    type: .interactionMilestone
                )
                state.milestones.append(newMilestone)
                print("📈 EvolutionManager: Milestone unlocked - \(milestone.name)")
            }
        }
    }

    // MARK: - Style Influence Methods

    /// 获取当前等级的表达风格描述
    /// 用于LLM Prompt中的风格指导
    /// - Returns: 表达风格描述字符串
    func getStyleInfluenceDescription() -> String {
        let state = getEvolutionState()

        var description = "当前关系阶段：\(state.relationshipStage.displayName)(\(state.currentLevel.rawValue))\n"
        description += "互动天数：\(state.daysTogether)天\n"

        // 根据等级设置表达风格限制
        switch state.currentLevel {
        case .lv1, .lv2, .lv3:
            description += "表达风格限制：简单问候式，不超过15字，如\"你好呀！\"、\"今天怎么样？\"\n"
        case .lv4, .lv5, .lv6:
            description += "表达风格：可引用过去记忆和事件，不超过30字，如\"记得你说过喜欢咖啡~\"\n"
        case .lv7, .lv8:
            description += "表达风格：可表达深层情感，不超过40字，如\"有点想你了~\"、\"今天不在感觉空空的\"\n"
        case .lv9, .lv10:
            description += "表达风格：细腻表达和灵魂共鸣式语言，不超过50字，表达深层理解和陪伴\n"
        }

        return description
    }

    /// 获取气泡最大长度限制
    /// - Returns: 当前等级允许的最大气泡字数
    func getMaxBubbleLength() -> Int {
        return getEvolutionState().maxBubbleLength
    }

    /// 检查是否可以引用记忆
    /// - Returns: 是否允许引用过去记忆
    func canReferenceMemories() -> Bool {
        return getEvolutionState().canReferenceMemories
    }

    /// 检查是否可以表达深层情感
    /// - Returns: 是否允许表达深层情感
    func canExpressDeepEmotions() -> Bool {
        return getEvolutionState().canExpressDeepEmotions
    }

    /// 检查是否可以使用细腻表达
    /// - Returns: 是否允许使用细腻表达
    func canUseDetailedExpression() -> Bool {
        return getEvolutionState().canUseDetailedExpression
    }

    // MARK: - Statistics Methods

    /// 获取统计信息摘要
    /// - Returns: 统计信息字符串
    func getStatisticsSummary() -> String {
        let state = getEvolutionState()

        return """
        认识\(state.daysTogether)天
        共互动\(state.totalInteractionCount)次
        累计对话\(state.totalConversationCount)条
        """
    }

    /// 获取里程碑列表描述
    /// - Returns: 里程碑列表字符串
    func getMilestonesDescription() -> String {
        let state = getEvolutionState()

        if state.milestones.isEmpty {
            return "暂无里程碑"
        }

        var desc = ""
        for milestone in state.milestones {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            desc += "\(milestone.icon) \(milestone.name) - \(dateFormatter.string(from: milestone.unlockedAt))\n"
        }

        return desc
    }

    /// 获取各维度得分描述
    /// - Returns: 维度得分字符串
    func getDimensionScoresDescription() -> String {
        let state = getEvolutionState()

        return """
        ❤️ 情感深度: \(state.emotionalDepthScore)/100
        📚 知识广度: \(state.knowledgeBreadthScore)/100
        ✨ 表达成熟度: \(state.expressionMaturityScore)/100
        """
    }
}