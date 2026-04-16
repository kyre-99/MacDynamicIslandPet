import Foundation
import Combine

/// 气泡类型枚举，定义5种拟人化气泡类型
/// US-012: 拟人化气泡生成机制实现
enum BubbleType: String, Codable, CaseIterable {
    /// 问候气泡 - 引用时间/天气/事件
    case greeting = "greeting"
    /// 关心气泡 - 基于情感状态
    case caring = "caring"
    /// 回忆气泡 - 引用过去对话/事件
    case memory = "memory"
    /// 观点气泡 - 自主思考结果
    case opinion = "opinion"
    /// 调侃气泡 - 结合性格幽默度
    case teasing = "teasing"

    /// 获取气泡类型的中文显示名称
    var displayName: String {
        switch self {
        case .greeting: return "问候"
        case .caring: return "关心"
        case .memory: return "回忆"
        case .opinion: return "观点"
        case .teasing: return "调侃"
        }
    }

    /// 获取气泡类型的图标
    var icon: String {
        switch self {
        case .greeting: return "👋"
        case .caring: return "💕"
        case .memory: return "💭"
        case .opinion: return "💡"
        case .teasing: return "😜"
        }
    }

    /// 获取气泡类型的触发场景描述
    var triggerScenes: [String] {
        switch self {
        case .greeting: return ["stationaryTimeout", "random"]
        case .caring: return ["longAppUsage", "emotionTrigger"]
        case .memory: return ["windowSwitch", "eventReminder"]
        case .opinion: return ["autonomousThinking", "stationaryTimeout"]
        case .teasing: return ["edgeArrival", "windowSwitch"]
        }
    }
}

/// 气泡触发场景枚举
/// US-012: 定义气泡生成的触发来源
enum BubbleTriggerScene: String {
    /// 精灵到达屏幕边缘
    case edgeArrival = "edgeArrival"
    /// 精灵静止超过阈值时间
    case stationaryTimeout = "stationaryTimeout"
    /// 用户切换窗口
    case windowSwitch = "windowSwitch"
    /// 用户长时间使用某应用
    case longAppUsage = "longAppUsage"
    /// 事件提醒触发
    case eventReminder = "eventReminder"
    /// 自主思考完成
    case autonomousThinking = "autonomousThinking"
    /// 随机触发
    case random = "random"
}

/// Generates intelligent comments based on perception data
/// US-007: Integrates window info, visual analysis, and time context for comments
/// US-009: Memory-driven intelligent comments with pattern detection and deduplication
/// US-006: Emotion-driven comment generation using EmotionTracker
/// US-012: 拟人化气泡生成机制实现 - 融合性格、记忆、进化等级
class CommentGenerator: ObservableObject {
    static let shared = CommentGenerator()

    // MARK: - Published Properties

    /// Current generated comment
    @Published var currentComment: String = ""

    /// Whether a comment is being generated
    @Published var isGenerating: Bool = false

    /// US-009: Recent comments for deduplication tracking
    @Published var recentComments: [String] = []

    /// US-012: Current bubble type
    @Published var currentBubbleType: BubbleType = .greeting

    // MARK: - Private Properties

    private let llmService = LLMService.shared
    private let windowObserver = WindowObserver.shared
    private let timeContext = TimeContext.shared
    private let perceptionMemory = PerceptionMemoryManager.shared
    /// US-006: Emotion tracker reference for emotion-driven comments
    private let emotionTracker = EmotionTracker.shared
    /// US-012: Personality manager reference
    private let personalityManager = PersonalityManager.shared
    /// US-012: Evolution manager reference
    private let evolutionManager = EvolutionManager.shared
    /// Timeline memory manager for today's events
    private let timelineManager = TimelineMemoryManager.shared

    private var cancellables = Set<AnyCancellable>()

    /// US-009: Deduplication - comments too similar to recent ones are rejected
    private let similarityThreshold: Float = 0.85  // 放宽阈值，避免误判重复

    /// US-009: Track recent comments for deduplication
    private var lastGeneratedComments: [String] = []
    private let maxCommentHistory: Int = 10

    /// US-012: Fallback content for each bubble type
    private let fallbackContent: [BubbleType: [String]] = [
        .greeting: [
            "你好呀~",
            "今天怎么样？",
            "嘿，来聊聊天~",
            "又在看这个啦~",
            "今天心情好吗？"
        ],
        .caring: [
            "休息一下吧~",
            "别太累了哦~",
            "喝杯水吧~",
            "要不要放松一下？",
            "我陪着你呢~"
        ],
        .memory: [
            "记得你喜欢这个~",
            "上次我们聊过这个~",
            "这个好像说过呢~",
            "又想起那件事了~",
            "还记得吗？"
        ],
        .opinion: [
            "我觉得挺有意思~",
            "这个有点意思~",
            "好像还不错~",
            "嗯...有想法~",
            "我想说说这个~"
        ],
        .teasing: [
            "又又又在用这个！",
            "效率感人啊~",
            "好无聊没人陪我~",
            "主人太调皮了~",
            "这操作我看不懂~"
        ]
    ]

    // MARK: - Comment Styles (Three styles per US-007)

    enum CommentStyle: String, CaseIterable {
        case gentleTease   // 温和调侃
        case caringAdvice  // 关心建议
        case playfulRoast  // 搞怪吐槽

        var displayName: String {
            switch self {
            case .gentleTease: return "温和调侃"
            case .caringAdvice: return "关心建议"
            case .playfulRoast: return "搞怪吐槽"
            }
        }
    }

    // MARK: - Prompt Templates

    /// System prompt for comment generation
    private let baseSystemPrompt: String = """
你是桌面小精灵，要根据感知到的信息生成一个简短的吐槽（不超过30字）。
风格：可爱活泼，有点调皮但有同理心。
"""

    /// Style-specific prompt templates
    private func getStylePrompt(_ style: CommentStyle) -> String {
        switch style {
        case .gentleTease:
            return """
风格：温和调侃
用轻松幽默的方式调侃一下主人的行为，不要太严肃，带点俏皮。
例子："又在刷微博啦~" "代码写得好慢哦~" "这个应用好像用很久了~"
"""
        case .caringAdvice:
            return """
风格：关心建议
表达对主人的关心，温柔地给出建议，但不要太啰嗦。
例子："该休息一下了~" "喝杯水吧~" "不要太累了哦~" "早点睡吧~"
"""
        case .playfulRoast:
            return """
风格：搞怪吐槽
用夸张搞怪的方式吐槽，可以带点小情绪但不要太负面。
例子："又又又又在看视频！" "主人今天效率感人啊~" "我要饿死了没人陪我玩~"
"""
        }
    }

    /// Behavior pattern prompt additions
    /// US-009: Enhanced with memory pattern detection and references
    private func getBehaviorPatternPrompt(_ appName: String, duration: TimeInterval, includeMemory: Bool = true) -> String {
        var patternPrompt = ""

        // Long activity pattern (US-009: 连续在某个应用超过X分钟)
        if duration > 3600 {  // More than 1 hour
            patternPrompt += "主人已经在这个应用里待了超过\(Int(duration / 60))分钟了。\n"

            // US-009: 模式触发特定吐槽（长时间工作关心提醒）
            if timeContext.currentPeriod == .lateNight {
                patternPrompt += "警告：深夜还在长时间工作，强烈关心提醒！\n"
            }
        }

        // US-009: 连续行为模式检测（连续3次都是编程）
        let consecutivePattern = detectConsecutiveBehaviorPattern()
        if let pattern = consecutivePattern {
            patternPrompt += "行为模式：\(pattern.description)\n"
        }

        // Frequent switching pattern
        if windowObserver.isFrequentSwitching(threshold: 5, withinMinutes: 10) {
            patternPrompt += "主人最近10分钟切换了很多应用。\n"
        }

        // App category specific prompts (简洁)
        let appCategory = windowObserver.getAppCategory(appName)
        switch appCategory {
        case .development:
            patternPrompt += "主人在编程~\n"
        case .communication:
            patternPrompt += "主人在聊天或开会~\n"
        case .browser:
            patternPrompt += "主人在浏览网页~\n"
        case .entertainment:
            patternPrompt += "主人在看视频或听音乐~\n"
        case .productivity:
            patternPrompt += "主人在处理文档~\n"
        case .other:
            break
        }

        return patternPrompt
    }

    // MARK: - US-006: Emotion-driven Comment Context

    /// Get emotion context for comment generation
    /// US-006: 情感历史影响气泡内容
    private func getEmotionContext() -> String {
        // 获取当前情感状态
        let currentEmotion = emotionTracker.getCurrentEmotion()

        // 获取情感模式描述
        let patternsDescription = emotionTracker.getEmotionPatternsDescription()

        var emotionContext = ""

        // 检测到焦虑状态或焦虑周期模式时给予安慰
        if emotionTracker.needsComforting() {
            emotionContext += "用户状态：当前情感\(currentEmotion.rawValue)，建议生成关心类气泡（安慰、关心、建议休息）\n"
            emotionContext += "情感模式：\(patternsDescription)\n"
            emotionContext += "提示：用户可能需要安慰，生成关心体贴的内容\n"
        }

        // 检测到放松状态时生成轻松调侃类内容
        if emotionTracker.isRelaxedState() {
            emotionContext += "用户状态：当前情感\(currentEmotion.rawValue)，适合轻松调侃类气泡\n"
            emotionContext += "提示：用户心情不错，可以生成轻松幽默的内容\n"
        }

        return emotionContext
    }

    /// Get caring bubble suggestion based on current emotion
    /// US-006: 基于情感状态生成关心类气泡内容
    func getEmotionBasedCaringBubble() -> String {
        return emotionTracker.getComfortingBubbleContent()
    }

    /// Check if user needs comforting based on emotion state
    /// US-006: 判断是否需要给予安慰
    func shouldGenerateCaringComment() -> Bool {
        return emotionTracker.needsComforting()
    }

    /// Check if user is in relaxed state for playful comment
    /// US-006: 判断是否处于放松状态
    func shouldGeneratePlayfulComment() -> Bool {
        return emotionTracker.isRelaxedState()
    }

    // MARK: - US-009: Pattern Detection Methods

    /// Behavior pattern types for US-009
    struct BehaviorPattern {
        let type: PatternType
        let count: Int
        let appName: String?
        let category: AppCategory?
        let description: String
    }

    enum PatternType {
        case sameAppConsecutive     // 连续使用同一应用
        case sameCategoryConsecutive // 连续使用同类应用
        case frequentSwitching      // 频繁切换应用
    }

    /// Detect consecutive behavior patterns from recent memory
    /// US-009: 检测连续行为模式（如：连续3次都是编程）
    private func detectConsecutiveBehaviorPattern() -> BehaviorPattern? {
        let recentEvents = perceptionMemory.getRecentPerceptions(count: 5)

        guard recentEvents.count >= 3 else { return nil }

        // Check for same app consecutive
        let recentApps = recentEvents.map { $0.appName }
        if let firstApp = recentApps.first {
            let sameAppCount = recentApps.filter { $0 == firstApp }.count
            if sameAppCount >= 3 {
                return BehaviorPattern(
                    type: .sameAppConsecutive,
                    count: sameAppCount,
                    appName: firstApp,
                    category: nil,
                    description: "连续\(sameAppCount)次使用\(firstApp)"
                )
            }
        }

        // Check for same category consecutive
        let recentCategories = recentEvents.compactMap { event -> AppCategory? in
            windowObserver.getAppCategory(event.appName)
        }

        if let firstCategory = recentCategories.first {
            let sameCategoryCount = recentCategories.filter { $0 == firstCategory }.count
            if sameCategoryCount >= 3 {
                return BehaviorPattern(
                    type: .sameCategoryConsecutive,
                    count: sameCategoryCount,
                    appName: nil,
                    category: firstCategory,
                    description: "连续\(sameCategoryCount)次\(firstCategory.displayName)"
                )
            }
        }

        // Check for frequent switching (different apps)
        let uniqueApps = Set(recentApps)
        if uniqueApps.count >= 4 && recentApps.count >= 5 {
            return BehaviorPattern(
                type: .frequentSwitching,
                count: uniqueApps.count,
                appName: nil,
                category: nil,
                description: "最近\(recentApps.count)次切换了\(uniqueApps.count)个不同应用"
            )
        }

        return nil
    }

    /// Get memory reference prompt for US-009
    /// US-009: 吐槽内容引用记忆（你刚才还在看微博，现在又来了~）
    private func getMemoryReferencePrompt() -> String {
        let recentEvents = perceptionMemory.getPerceptionsInLast(minutes: 30)

        guard !recentEvents.isEmpty else { return "" }

        // Find a previous app to reference
        let currentApp = windowObserver.currentActiveApp
        let previousEvents = recentEvents.filter { $0.appName != currentApp }

        guard let previous = previousEvents.first else { return "" }

        // US-009: 引用记忆（你刚才还在看微博，现在又来了~）
        let timeSince = Date().timeIntervalSince(
            DateFormatter().date(from: previous.timestamp) ?? Date()
        )
        let minutesAgo = Int(timeSince / 60)

        if minutesAgo < 5 {
            return "刚才(\(minutesAgo)分钟前)主人还在\(previous.appName)，现在又切换到\(currentApp)了。\n"
        } else if minutesAgo < 15 {
            return "不久前(\(minutesAgo)分钟前)主人还在\(previous.appName)。\n"
        }

        return ""
    }

    // MARK: - US-009: Deduplication

    /// Check if comment is too similar to recent comments
    /// US-009: 避免重复：检查记忆中是否已有类似吐槽
    private func isDuplicateComment(_ comment: String) -> Bool {
        // Check against recent generated comments
        for recent in lastGeneratedComments {
            let similarity = calculateSimilarity(comment, recent)
            if similarity > similarityThreshold {
                print("CommentGenerator: Duplicate detected - similarity \(similarity) with '\(recent)'")
                return true
            }
        }

        // Check against recent memory reactions
        let recentPerceptions = perceptionMemory.getRecentPerceptions(count: 5)
        for perception in recentPerceptions {
            if let reaction = perception.reaction {
                let similarity = calculateSimilarity(comment, reaction)
                if similarity > similarityThreshold {
                    print("CommentGenerator: Duplicate detected in memory - similarity \(similarity) with '\(reaction)'")
                    return true
                }
            }
        }

        return false
    }

    /// Calculate simple similarity between two strings (0.0-1.0)
    private func calculateSimilarity(_ a: String, _ b: String) -> Float {
        // Simple Jaccard similarity based on character overlap
        let setA = Set(a)
        let setB = Set(b)

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count

        if union == 0 { return 0 }
        return Float(intersection) / Float(union)
    }

    /// Record comment for deduplication tracking
    private func recordComment(_ comment: String) {
        lastGeneratedComments.append(comment)
        if lastGeneratedComments.count > maxCommentHistory {
            lastGeneratedComments.removeFirst()
        }
        recentComments = lastGeneratedComments
    }

    // MARK: - US-012: Bubble Type Selection Strategy

    /// 选择气泡类型基于触发场景和性格参数权重
    /// US-012: 气泡类型选择策略
    /// - Parameters:
    ///   - triggerScene: 触发场景
    ///   - personalityProfile: 性格参数
    /// - Returns: 选择的气泡类型
    func selectBubbleType(triggerScene: BubbleTriggerScene, personalityProfile: PersonalityProfile? = nil) -> BubbleType {
        let profile = personalityProfile ?? personalityManager.currentProfile

        // [US-012] 日志：输出当前性格参数
        print("🟣 [US-012] selectBubbleType - 触发场景: \(triggerScene.rawValue)")
        print("🟣 [US-012] 当前性格: 外向=\(profile.extroversion), 好奇=\(profile.curiosity), 粘人=\(profile.clinginess), 幽默=\(profile.humor), 温柔=\(profile.gentleness), 叛逆=\(profile.rebellion)")

        // 获取性格参数的气泡类型权重调整
        let weights = PersonalityStyleMapping.calculateBubbleTypeWeights(for: profile)
        print("🟣 [US-012] 性格权重: \(weights)")

        // 基于触发场景的基础类型选择
        var baseType: BubbleType
        switch triggerScene {
        case .edgeArrival:
            baseType = .teasing
        case .stationaryTimeout:
            // 随机选择问候或观点
            baseType = Bool.random() ? .greeting : .opinion
        case .windowSwitch:
            // 随机选择调侃或回忆
            baseType = Bool.random() ? .teasing : .memory
        case .longAppUsage:
            baseType = .caring
        case .eventReminder:
            baseType = .memory
        case .autonomousThinking:
            baseType = .opinion
        case .random:
            // 随机触发时，根据性格权重调整概率
            let types = BubbleType.allCases
            var probabilities: [Double] = [0.2, 0.2, 0.2, 0.2, 0.2]  // 基础概率

            // 应用性格权重调整
            for (index, type) in types.enumerated() {
                if let weight = weights[type.rawValue] {
                    probabilities[index] += weight
                }
            }

            // 归一化概率
            let total = probabilities.reduce(0, +)
            if total > 0 {
                probabilities = probabilities.map { $0 / total }
            }

            // 根据概率选择类型
            let random = Double.random(in: 0...1)
            var cumulative = 0.0
            for (index, prob) in probabilities.enumerated() {
                cumulative += prob
                if random <= cumulative {
                    return types[index]
                }
            }

            return .greeting
        }

        // 应用性格权重调整基础类型
        // 幽默感>70时teasing概率+30%
        if profile.humor >= 70 && baseType != .teasing {
            if Double.random(in: 0...1) < 0.3 {
                baseType = .teasing
            }
        }

        // 温柔度>70时caring概率+30%
        if profile.gentleness >= 70 && baseType != .caring {
            if Double.random(in: 0...1) < 0.3 {
                baseType = .caring
            }
        }

        // 焦虑状态时强制选择关心类型
        if emotionTracker.needsComforting() {
            baseType = .caring
            print("🟣 [US-012] 用户处于焦虑状态，强制选择关心类型")
        }

        print("🟣 [US-012] 最终选择的气泡类型: \(baseType.displayName)")
        return baseType
    }

    // MARK: - US-012: LLM Prompt Template Builder

    /// 构建自言自语的 System Message（精灵信息 + 主人状态 + KnowledgeManager 知识）
    /// 修改：依托于模型知道的和不知道的内容，与 ConversationManager 一致
    /// - Parameter triggerScene: 触发场景
    /// - Returns: System message 内容
    private func buildSelfTalkSystemMessage(triggerScene: BubbleTriggerScene) -> String {
        let profile = personalityManager.currentProfile
        let evolutionState = evolutionManager.getEvolutionState()
        let emotionState = emotionTracker.getCurrentEmotion()
        let timeContext = TimeContext.shared

        print("🟣 [US-008] buildSelfTalkSystemMessage - 进化等级：\(evolutionState.currentLevel.rawValue), 互动天数：\(evolutionState.daysTogether)")

        // 当前时间
        let timeHint = "现在是\(timeContext.currentPeriod.displayName)，\(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))。"

        // 性格倾向（自然语言）
        var personalityHint = ""
        if profile.extroversion >= 70 {
            personalityHint += "你活泼爱说话，"
        } else if profile.extroversion <= 30 {
            personalityHint += "你比较安静，"
        }
        if profile.humor >= 70 {
            personalityHint += "喜欢吐槽调侃，"
        }
        if profile.gentleness >= 70 {
            personalityHint += "很关心这个人，"
        }
        if profile.rebellion >= 70 {
            personalityHint += "有点调皮叛逆，"
        }
        if personalityHint.isEmpty {
            personalityHint = "你性格温和，"
        }

        // 关系状态
        var relationHint = ""
        if evolutionState.daysTogether == 0 {
            relationHint = "你刚来到这里。"
        } else if evolutionState.daysTogether < 7 {
            relationHint = "你和这个人相处了\(evolutionState.daysTogether)天。"
        } else {
            relationHint = "你们现在是\(evolutionState.relationshipStage.displayName)。"
        }

        // 情感状态
        var emotionHint = ""
        switch emotionState {
        case .happy:
            emotionHint = "这个人看起来心情不错。"
        case .sad:
            emotionHint = "这个人好像有点难过。"
        case .stressed:
            emotionHint = "这个人压力有点大。"
        case .busy:
            emotionHint = "这个人很忙。"
        default:
            emotionHint = ""
        }

        // 获取进化等级的气泡长度限制
        let maxLength = evolutionManager.getMaxBubbleLength()

        // 从 KnowledgeManager 获取知识（包含知道和不知道的事情）
        let knowledgeContent = KnowledgeManager.shared.getSystemPromptKnowledge()

        // 今日事件
        let todayEvents = timelineManager.getTodayEventsPromptDescription()
        var eventsHint = ""
        if !todayEvents.isEmpty {
            eventsHint = "\n#【今日特别】\n今天是特殊的日子：\n\(todayEvents)精灵可以适当提及这些特别的日子，表达关心或祝福。"
        }

        // 精灵此刻的心情/想法（根据触发场景）
        var moodHint = ""
        switch triggerScene {
        case .edgeArrival:
            moodHint = "你跑到屏幕边上看了一眼，"
        case .stationaryTimeout:
            moodHint = "你站着发了一会儿呆，"
        case .random:
            moodHint = "你无聊地晃悠着，"
        default:
            moodHint = "你盯着主人看，"
        }

        // 主人当前状态
        let masterStatus = buildMasterCurrentStatus(triggerScene)

        print("🟣 [US-008] 气泡最大长度：\(maxLength)字 (根据进化等级)")

        return """
你现在正缩在屏幕的小角落里，作为一只鲜活的小精灵观察着这个世界，感受着这个人的情绪和状态。你会怎么想？会怎么说？请完全代入这个角色。
# 【你的灵魂核心】
你的性格底色是 \(personalityHint)。不要机械地复述性格，而是让这种性格渗透进你说的每一个字里。
#【你的羁绊】
你面前的那个人，与你是 \(relationHint) 的关系。你此时对他抱着 \(emotionHint) 的心情。这种情感将决定你说话的语气——是撒娇、敬畏，还是小小的毒舌？
#【此时此刻】
时钟指向 \(timeHint)。窗外的光影、当下的氛围都在影响你。
#【你的知识】
这是你脑海中对外面世界的知识库：\(knowledgeContent)。
\(eventsHint)#【你的状态】
你现在正忙于 \(moodHint)，而那个正盯着你看的人类正处于 \(masterStatus) 的状态。
# 【对话要求】
请把你自己完全代入这个角色，吐露一段内心的碎碎念或自言自语。
拒绝套路： 不要说"作为小精灵..."这种废话，直接开始你的表演。
字数限制： 严格控制在 \(maxLength) 字以内。
纯净输出： 只输出你想说的话（对话气泡内容），一个字的解释都不要有。
"""
    }

    /// 构建性格特征描述（自然语言）
    private func buildPersonalityTraits(_ profile: PersonalityProfile) -> String {
        var traits: [String] = []

        if profile.extroversion >= 70 {
            traits.append("你很活泼外向，喜欢主动说话")
        } else if profile.extroversion <= 30 {
            traits.append("你比较安静内向，不太主动说话")
        }

        if profile.curiosity >= 70 {
            traits.append("你对什么都好奇，喜欢观察和问问题")
        }

        if profile.humor >= 70 {
            traits.append("你很幽默爱调侃，喜欢吐槽")
        } else if profile.humor <= 30 {
            traits.append("你比较正经，不太开玩笑")
        }

        if profile.gentleness >= 70 {
            traits.append("你很温柔体贴，会关心主人")
        }

        if profile.rebellion >= 70 {
            traits.append("你有点叛逆调皮，喜欢搞怪")
        }

        if traits.isEmpty {
            traits.append("你性格比较平衡")
        }

        return traits.joined(separator: "。") + "。"
    }

    /// 构建主人当前状态描述
    private func buildMasterCurrentStatus(_ triggerScene: BubbleTriggerScene) -> String {
        let appName = windowObserver.currentActiveApp
        let duration = windowObserver.activeAppDuration

        var status = ""

        // 时间信息
        let timeContext = TimeContext.shared
        status += "现在是\(timeContext.currentPeriod.displayName)，"

        // 应用信息
        status += "主人正在用\(appName)"

        // 使用时长
        if duration > 3600 {
            status += "（已经用了\(Int(duration / 60))分钟）"
        }

        // 行为模式
        if windowObserver.isFrequentSwitching(threshold: 5, withinMinutes: 10) {
            status += "，最近切换了很多应用"
        }

        // 触发场景补充
        switch triggerScene {
        case .edgeArrival:
            status += "。你刚刚跑到屏幕边缘"
        case .stationaryTimeout:
            status += "。你站着发呆了好一会儿"
        case .random:
            status += ""
        default:
            status += ""
        }

        return status + "。"
    }

    /// 构建关系阶段描述
    private func buildRelationshipDescription(_ evolutionState: EvolutionState) -> String {
        switch evolutionState.relationshipStage {
        case .stranger:
            return "你们还不太熟悉。"
        case .acquaintance:
            return "你们刚认识不久。"
        case .familiar:
            return "你们已经比较熟悉了。"
        case .friend:
            return "你们已经是朋友了。"
        case .goodFriend:
            return "你们是好朋友。"
        case .confidant:
            return "你们是知心朋友。"
        case .bestFriend:
            return "你们像闺蜜兄弟一样亲密。"
        case .closeFriend:
            return "你们是挚友。"
        case .soulmate:
            return "你们是知己。"
        case .lifetimePartner:
            return "你们是终身伙伴。"
        }
    }

    /// 构建情感状态描述
    private func buildEmotionDescription(_ emotionState: UserEmotionState) -> String {
        switch emotionState {
        case .happy:
            return "主人看起来很开心，你也跟着开心。"
        case .sad:
            return "主人好像有点难过。"
        case .anxious:
            return "主人有点焦虑的样子。"
        case .stressed:
            return "主人好像压力有点大。"
        case .busy:
            return "主人现在很忙。"
        case .relaxed:
            return "主人看起来很放松。"
        case .focused:
            return "主人很专注地工作。"
        case .excited:
            return "主人很兴奋的样子。"
        case .tired:
            return "主人看起来有点累。"
        case .neutral:
            return ""
        }
    }

    // MARK: - US-012: Humanoid Bubble Generation

    /// 生成拟人化气泡（自言自语）
    /// 修复：只发送一个 system message，包含精灵信息 + 主人状态，让精灵自然发挥
    /// - Parameters:
    ///   - triggerScene: 触发场景
    ///   - bubbleType: 可选指定气泡类型，不指定则自动选择
    ///   - completion: 完成回调
    func generateHumanoidBubble(
        triggerScene: BubbleTriggerScene,
        bubbleType: BubbleType? = nil,
        completion: @escaping (Result<(content: String, type: BubbleType), CommentError>) -> Void
    ) {
        guard !isGenerating else {
            completion(.failure(.alreadyGenerating))
            return
        }

        isGenerating = true

        // 选择气泡类型
        let selectedType = bubbleType ?? selectBubbleType(triggerScene: triggerScene)
        currentBubbleType = selectedType

        // 获取进化等级的最大气泡长度
        let maxLength = evolutionManager.getMaxBubbleLength()

        // 构建完整的 system message（精灵信息 + 主人状态 + 记忆）
        let systemContent = buildSelfTalkSystemMessage(triggerScene: triggerScene)

        print("🧠 CommentGenerator: Sending self-talk with single system message")

        // 调用LLM（只用 system message）
        llmService.sendSelfTalkSystem(
            systemContent: systemContent,
            maxTokens: 50,
            completion: { result in
                DispatchQueue.main.async {
                    self.isGenerating = false

                    switch result {
                    case .success(let comment):
                        // 按进化等级限制长度
                        let trimmed = self.trimCommentToLength(comment, maxLength: maxLength)

                        // US-012: 增强去重检查
                        if self.isDuplicateComment(trimmed) {
                            // 使用对应类型的fallback
                            let fallback = self.getFallbackForBubbleType(selectedType)
                            self.currentComment = fallback
                            self.recordComment(fallback)
                            completion(.success((content: fallback, type: selectedType)))
                        } else {
                            self.currentComment = trimmed
                            self.recordComment(trimmed)
                            completion(.success((content: trimmed, type: selectedType)))
                        }

                    case .failure:
                        // 使用fallback
                        let fallback = self.getFallbackForBubbleType(selectedType)
                        self.currentComment = fallback
                        self.recordComment(fallback)
                        completion(.success((content: fallback, type: selectedType)))
                    }
                }
            }
        )
    }

    /// 按指定长度裁剪气泡内容
    /// US-012: maxLength根据进化等级调整
    /// - Parameters:
    ///   - comment: 原始气泡内容
    ///   - maxLength: 最大长度
    /// - Returns: 裁剪后的内容（完整显示，不截断）
    private func trimCommentToLength(_ comment: String, maxLength: Int) -> String {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        // 不再截断，返回完整内容
        return trimmed
    }

    /// 获取指定气泡类型的fallback内容
    /// US-012: 气泡生成失败fallback策略
    /// - Parameter bubbleType: 气泡类型
    /// - Returns: 随机选择的fallback内容
    func getFallbackForBubbleType(_ bubbleType: BubbleType) -> String {
        let fallbacks = fallbackContent[bubbleType] ?? ["..."]
        return fallbacks.randomElement() ?? "..."
    }

    // MARK: - US-012: Personality Influence Verification

    /// 获取当前性格参数的气泡类型概率权重
    /// US-012: 用于验证性格参数影响气泡风格
    /// - Returns: 各气泡类型的权重字典
    func getCurrentBubbleTypeWeights() -> [String: Double] {
        return PersonalityStyleMapping.calculateBubbleTypeWeights(for: personalityManager.currentProfile)
    }

    /// 获取当前进化等级的最大气泡长度
    /// US-012: 用于验证进化等级影响气泡长度
    /// - Returns: 最大气泡字数
    func getCurrentMaxBubbleLength() -> Int {
        return evolutionManager.getMaxBubbleLength()
    }

    /// 检查当前进化等级是否可以引用记忆
    /// US-012: 验证进化等级影响气泡内容
    /// - Returns: 是否允许引用记忆
    func canReferenceMemories() -> Bool {
        return evolutionManager.canReferenceMemories()
    }

    /// 检查当前进化等级是否可以表达深层情感
    /// US-012: 验证进化等级影响表达深度
    /// - Returns: 是否允许表达深层情感
    func canExpressDeepEmotions() -> Bool {
        return evolutionManager.canExpressDeepEmotions()
    }

    /// 生成性格描述文字
    /// US-012: 性格参数到性格描述的转换
    /// - Parameter profile: 性格参数
    /// - Returns: 性格描述字符串
    private func generatePersonalityDescription(for profile: PersonalityProfile) -> String {
        var descriptions: [String] = []

        if profile.extroversion >= 70 {
            descriptions.append("活泼开朗")
        } else if profile.extroversion <= 30 {
            descriptions.append("安静内敛")
        }

        if profile.curiosity >= 70 {
            descriptions.append("充满好奇心")
        }

        if profile.humor >= 70 {
            descriptions.append("爱调侃")
        } else if profile.humor <= 30 {
            descriptions.append("正经严肃")
        }

        if profile.gentleness >= 70 {
            descriptions.append("温柔体贴")
        }

        if profile.rebellion >= 70 {
            descriptions.append("搞怪叛逆")
        }

        if descriptions.isEmpty {
            return "性格平衡"
        }

        return descriptions.joined(separator: "、")
    }

    // MARK: - US-008: Visual Analysis Bubble Generation (Go-See)

    /// 生成带视觉分析的气泡（go-see 行为专用）
    /// - Parameters:
    ///   - visualResult: 视觉分析结果
    ///   - appName: 应用名称
    ///   - completion: 完成回调
    func generateCommentWithVision(
        visualResult: VisualAnalysisResult,
        appName: String,
        completion: @escaping (Result<String, CommentError>) -> Void
    ) {
        guard !isGenerating else {
            completion(.failure(.alreadyGenerating))
            return
        }

        isGenerating = true

        // 从 KnowledgeManager 获取背景知识
        let knowledgeContent = KnowledgeManager.shared.getSystemPromptKnowledge()

        // 获取性格描述
        let profile = personalityManager.currentProfile
        let personalityDescription = generatePersonalityDescription(for: profile)

        // 构建详细的视觉信息描述
        var visualDetails = "- 应用名称：\(appName)\n"
        visualDetails += "- 活动类型：\(visualResult.activityType)\n"

        // 添加主要窗口信息
        if let mainWindow = visualResult.mainWindow, !mainWindow.isEmpty {
            visualDetails += "- 主要窗口：\(mainWindow)\n"
        }

        // 添加可见文本信息
        if let visibleText = visualResult.visibleText, !visibleText.isEmpty {
            visualDetails += "- 可见文本：\(visibleText)\n"
        }

        // 添加 UI 元素信息
        if let uiElements = visualResult.uiElements, !uiElements.isEmpty {
            visualDetails += "- 界面元素：\(uiElements)\n"
        }

        // 添加用户行为推断
        if let userBehavior = visualResult.userBehavior, !userBehavior.isEmpty {
            visualDetails += "- 用户行为：\(userBehavior)\n"
        }

        visualDetails += "- 内容简述：\(visualResult.briefDescription)"

        // 构建完整的 system prompt（包含视觉分析结果）
        let systemPrompt = """
你是一只寄居在电脑屏幕里的桌宠小精灵。你现在的精神状态是：\(personalityDescription)。
【你的小小世界】
你脑子里的知识： \(knowledgeContent)（这是你的常识，请自然地运用它）。
你刚才偷偷瞄了一眼屏幕： 你看到了 \(visualDetails)。
【你的行动指令】
请盯着屏幕前的那个人类，结合你看到的画面和你的性格，憋出一句内心的小吐槽。
只需要输出你的心里话（气泡内容），禁止任何解释或前缀。
"""

        llmService.sendMessage(
            userMessage: systemPrompt,
            context: nil,
            completion: { result in
                DispatchQueue.main.async {
                    self.isGenerating = false

                    switch result {
                    case .success(let comment):
                        let trimmed = self.trimComment(comment)

                        // 去重检查
                        if self.isDuplicateComment(trimmed) {
                            let fallback = self.getFallbackFromVisualResult(visualResult)
                            self.currentComment = fallback
                            self.recordComment(fallback)
                            completion(.success(fallback))
                        } else {
                            self.currentComment = trimmed
                            self.recordComment(trimmed)
                            completion(.success(trimmed))
                        }

                    case .failure:
                        let fallback = self.getFallbackFromVisualResult(visualResult)
                        self.currentComment = fallback
                        self.recordComment(fallback)
                        completion(.success(fallback))
                    }
                }
            }
        )
    }

    /// 裁剪评论（完整显示，不截断）
    private func trimComment(_ comment: String) -> String {
        return comment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 根据视觉分析结果生成 fallback 评论
    private func getFallbackFromVisualResult(_ result: VisualAnalysisResult) -> String {
        // 优先使用可见文本生成个性化评论
        if let visibleText = result.visibleText, !visibleText.isEmpty {
            // 提取文本中的关键词生成评论
            let textPreview = String(visibleText.prefix(20))
            return "在看\"\(textPreview)\"~"
        }

        // 使用用户行为推断生成评论
        if let userBehavior = result.userBehavior, !userBehavior.isEmpty {
            switch result.activityType {
            case "编程":
                return "写代码中~"
            case "浏览网页":
                return "逛网页中~"
            case "看视频":
                return "看视频中~"
            case "开会":
                return "开会中~"
            case "聊天":
                return "聊天中~"
            case "写文档":
                return "写文档中~"
            default:
                return "忙碌中~"
            }
        }

        // 使用活动类型生成评论
        let activity = result.activityType
        let fallbacks: [String]

        switch activity {
        case "编程", "开发", "Xcode":
            fallbacks = ["代码写得怎么样啦~", "写代码累了歇歇~", "代码 bug 多不多~"]
        case "浏览网页", "Safari":
            fallbacks = ["又在看网页啦~", "眼睛要休息哦~", "又又又刷网页！"]
        case "看视频", "视频":
            fallbacks = ["视频好看吗~", "看太久不好哦~", "看了一整天了！"]
        case "开会", "会议":
            fallbacks = ["会议顺利吗~", "开会辛苦啦~", "开会开到天荒地老~"]
        case "聊天", "通讯":
            fallbacks = ["聊得开心吗~", "聊太久眼睛累~", "聊天的巨人~"]
        case "写文档", "文档":
            fallbacks = ["文档写到哪了~", "写文档休息下~", "文档写不完啦~"]
        default:
            fallbacks = ["又在做这个啦~", "休息一下吧~", "又又又在做这个！"]
        }

        return fallbacks.randomElement() ?? "..."
    }

    // MARK: - Initialization

    private init() {}
}

// MARK: - Error Types

enum CommentError: Error, LocalizedError {
    case alreadyGenerating
    case noContext
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .alreadyGenerating:
            return "Comment is already being generated"
        case .noContext:
            return "No perception context available"
        case .generationFailed:
            return "Comment generation failed"
        }
    }
}