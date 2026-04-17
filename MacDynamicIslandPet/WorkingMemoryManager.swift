import Foundation

struct WorkingMemoryContext {
    var identitySummary: String
    var relationshipSummary: String
    var internalStateSummary: String
    var environmentSummary: String
    var recentConversationSummary: String
    var recalledMemories: [String]
    var unfinishedThought: String?

    func asPromptBlock() -> String {
        var sections: [String] = []
        sections.append("#【身份】\n\(identitySummary)")
        sections.append("#【关系】\n\(relationshipSummary)")
        sections.append("#【内心】\n\(internalStateSummary)")
        sections.append("#【环境】\n\(environmentSummary)")

        if !recentConversationSummary.isEmpty {
            sections.append("#【最近互动】\n\(recentConversationSummary)")
        }

        if !recalledMemories.isEmpty {
            sections.append("#【被唤起的记忆】\n" + recalledMemories.joined(separator: "\n"))
        }

        if let unfinishedThought, !unfinishedThought.isEmpty {
            sections.append("#【未完的念头】\n\(unfinishedThought)")
        }

        return sections.joined(separator: "\n")
    }
}

class WorkingMemoryManager {
    static let shared = WorkingMemoryManager()

    private let knowledgeManager = KnowledgeManager.shared
    private let perceptionMemory = PerceptionMemoryManager.shared
    private let memoryCardManager = MemoryCardManager.shared
    private let timelineManager = TimelineMemoryManager.shared
    private let personalityManager = PersonalityManager.shared
    private let evolutionManager = EvolutionManager.shared
    private let emotionTracker = EmotionTracker.shared
    private let timeContext = TimeContext.shared
    private let petInternalStateManager = PetInternalStateManager.shared
    private let relationshipMemoryManager = RelationshipMemoryManager.shared
    private let windowObserver = WindowObserver.shared

    private init() {}

    func buildConversationContext(
        userInput: String,
        emotionOverride: UserEmotionState? = nil,
        emotionInsightSummary: String? = nil
    ) -> WorkingMemoryContext {
        let emotion = emotionOverride ?? emotionTracker.getCurrentEmotion(conversationContent: userInput)
        let recentConversations = knowledgeManager.getRecentConversations(count: 4)
        let recentPerceptions = perceptionMemory.getRecentPerceptions(count: 2)
        let todayEvents = timelineManager.getTodayEventsPromptDescription()
        let unfinishedThought = petInternalStateManager.consumeContextualUnfinishedThought(forConversation: userInput)
        let recalledMemories = recallMemorySummaries(
            queryText: userInput,
            emotion: emotion,
            appName: windowObserver.currentActiveApp,
            fallbackPerceptions: recentPerceptions,
            todayEvents: todayEvents
        )

        return WorkingMemoryContext(
            identitySummary: buildIdentitySummary(),
            relationshipSummary: buildRelationshipSummary(),
            internalStateSummary: petInternalStateManager.getPromptSummary(),
            environmentSummary: buildEnvironmentSummary(emotion: emotion, insightSummary: emotionInsightSummary),
            recentConversationSummary: summarizeRecentConversations(recentConversations),
            recalledMemories: recalledMemories,
            unfinishedThought: unfinishedThought
        )
    }

    func buildSelfTalkContext(triggerScene: BubbleTriggerScene) -> WorkingMemoryContext {
        let emotion = emotionTracker.getCurrentEmotion()
        let recentConversations = knowledgeManager.getRecentConversations(count: 3)
        let recentPerceptions = perceptionMemory.getRecentPerceptions(count: 3)
        let todayEvents = timelineManager.getTodayEventsPromptDescription()
        let unfinishedThought = petInternalStateManager.consumeContextualUnfinishedThought(forSelfTalk: triggerScene)
        var recalledMemories = recallMemorySummaries(
            queryText: nil,
            emotion: emotion,
            appName: windowObserver.currentActiveApp,
            fallbackPerceptions: recentPerceptions,
            todayEvents: todayEvents
        )

        recalledMemories.insert("当前触发场景是 \(triggerScene.rawValue)。", at: 0)

        return WorkingMemoryContext(
            identitySummary: buildIdentitySummary(),
            relationshipSummary: buildRelationshipSummary(),
            internalStateSummary: petInternalStateManager.getPromptSummary(),
            environmentSummary: buildEnvironmentSummary(emotion: emotion),
            recentConversationSummary: summarizeRecentConversations(recentConversations),
            recalledMemories: Array(recalledMemories.prefix(3)),
            unfinishedThought: unfinishedThought
        )
    }

    // MARK: - Prompt Building Helpers

    private func buildIdentitySummary() -> String {
        let profile = personalityManager.currentProfile
        var traits: [String] = []

        if profile.extroversion >= 70 {
            traits.append("活泼爱说话")
        } else if profile.extroversion <= 30 {
            traits.append("安静克制")
        }

        if profile.humor >= 70 {
            traits.append("喜欢调侃")
        }

        if profile.gentleness >= 70 {
            traits.append("很会关心人")
        }

        if profile.rebellion >= 70 {
            traits.append("偶尔有点坏心眼")
        }

        if traits.isEmpty {
            traits.append("性格柔和")
        }

        return "你是住在屏幕角落的小精灵，性格偏" + traits.joined(separator: "、") + "。"
    }

    private func buildRelationshipSummary() -> String {
        let promptSummary = relationshipMemoryManager.getPromptSummary()
        guard !promptSummary.isEmpty else {
            let evolutionState = evolutionManager.getEvolutionState()
            if evolutionState.daysTogether == 0 {
                return "你刚来到这里，和这个人还在互相认识。"
            }

            if evolutionState.daysTogether < 7 {
                return "你和这个人已经相处了\(evolutionState.daysTogether)天，还在建立默契。"
            }

            return "你们现在是\(evolutionState.relationshipStage.displayName)，已经有一定默契。"
        }

        return promptSummary
    }

    private func buildEnvironmentSummary(emotion: UserEmotionState, insightSummary: String? = nil) -> String {
        let appName = windowObserver.currentActiveApp.isEmpty ? "未知应用" : windowObserver.currentActiveApp
        let durationMinutes = Int(windowObserver.activeAppDuration / 60)
        var description = "现在是\(timeContext.dateDescription)，这个人正在使用\(appName)"

        if durationMinutes > 0 {
            description += "，已经停留了\(durationMinutes)分钟"
        }

        description += "。你判断他当前更接近\(emotion.rawValue)状态。"
        if let insightSummary, !insightSummary.isEmpty {
            description += " 补充理解：\(insightSummary)"
        }
        return description
    }

    private func summarizeRecentConversations(_ conversations: [(userInput: String, petResponse: String)]) -> String {
        guard !conversations.isEmpty else {
            return ""
        }

        return conversations.suffix(3).map { conversation in
            "用户说：\(trim(conversation.userInput, limit: 36))；你回：\(trim(conversation.petResponse, limit: 36))。"
        }.joined(separator: "\n")
    }

    private func recallMemorySummaries(
        queryText: String?,
        emotion: UserEmotionState,
        appName: String,
        fallbackPerceptions: [(timestamp: String, timePeriod: String, appName: String, activity: String, reaction: String?)],
        todayEvents: String
    ) -> [String] {
        let cards = memoryCardManager.searchRelevantCards(
            query: MemoryCardQuery(
                text: queryText,
                emotion: emotion,
                appName: appName,
                limit: 3
            )
        )

        var memories = cards.map { card in
            "[\(card.type.rawValue)] \(card.summary)"
        }

        if memories.isEmpty {
            memories = buildFallbackRecalledMemories(
                userInput: queryText,
                emotion: emotion,
                recentPerceptions: fallbackPerceptions,
                todayEvents: todayEvents
            )
        }

        return Array(memories.prefix(3))
    }

    private func buildFallbackRecalledMemories(
        userInput: String?,
        emotion: UserEmotionState,
        recentPerceptions: [(timestamp: String, timePeriod: String, appName: String, activity: String, reaction: String?)],
        todayEvents: String
    ) -> [String] {
        var memories: [String] = []

        if let userInput, !userInput.isEmpty {
            if userInput.contains("明天") || userInput.contains("下周") || userInput.contains("计划") {
                memories.append("他刚提到近期安排，你可以自然接住这个话题。")
            }

            if userInput.contains("累") || userInput.contains("压力") || userInput.contains("焦虑") {
                memories.append("他这轮表达了疲惫或压力，更适合先关心而不是乱吐槽。")
            }
        }

        if let latestPerception = recentPerceptions.last {
            memories.append("你最近看到他在\(latestPerception.appName)里\(trim(latestPerception.activity, limit: 24))。")
        }

        if !todayEvents.isEmpty {
            memories.append("今天有值得提一嘴的特殊日子：\(trim(todayEvents, limit: 36))")
        }

        if emotion == .sad || emotion == .stressed || emotion == .anxious {
            memories.append("他现在情绪不算轻松，你要优先照顾他的感受。")
        }

        return Array(memories.prefix(3))
    }

    private func trim(_ text: String, limit: Int) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        guard normalized.count > limit else { return normalized }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<endIndex]) + "..."
    }
}
