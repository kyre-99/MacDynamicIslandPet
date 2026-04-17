import Foundation

/// 小人的内在心情枚举
enum PetMood: String, Codable, CaseIterable {
    case calm = "平静"
    case happy = "开心"
    case playful = "活泼"
    case lonely = "寂寞"
    case clingy = "黏人"
    case concerned = "担心"
    case sleepy = "困倦"
    case sulky = "委屈"
    case curious = "好奇"
}

enum UnfinishedThoughtKind: String, Codable {
    case plan = "安排"
    case comfort = "关心"
    case followUp = "续聊"
}

/// 小人内部状态
struct PetInternalState: Codable {
    var mood: PetMood
    var energy: Int
    var socialNeed: Int
    var attachmentLevel: Int
    var frustration: Int
    var curiosityFocus: String?
    var currentGoal: String?
    var unfinishedThought: String?
    var unfinishedThoughtKind: UnfinishedThoughtKind?
    var unfinishedThoughtUpdatedAt: Date?
    var unfinishedThoughtLastMentionedAt: Date?
    var unfinishedThoughtMentionCount: Int
    var lastInteractionAt: Date?
    var updatedAt: Date

    static func initialState() -> PetInternalState {
        PetInternalState(
            mood: .calm,
            energy: 72,
            socialNeed: 38,
            attachmentLevel: 45,
            frustration: 8,
            curiosityFocus: nil,
            currentGoal: "先安静陪在他身边",
            unfinishedThought: nil,
            unfinishedThoughtKind: nil,
            unfinishedThoughtUpdatedAt: nil,
            unfinishedThoughtLastMentionedAt: nil,
            unfinishedThoughtMentionCount: 0,
            lastInteractionAt: nil,
            updatedAt: Date()
        )
    }
}

/// 内部状态事件
enum PetInternalEvent {
    case conversationStarted(userInput: String)
    case conversationCompleted(response: String)
    case selfTalkTriggered(reason: String)
}

/// 管理小人的内部状态
class PetInternalStateManager {
    static let shared = PetInternalStateManager()

    private let storageFile = MemoryStoragePath.petInternalStateFile
    private var stateCache: PetInternalState

    private init() {
        MemoryStoragePath.ensureAllDirectoriesExist()
        stateCache = Self.loadState(from: storageFile) ?? PetInternalState.initialState()
        saveState(stateCache)
    }

    // MARK: - Public API

    func getCurrentState() -> PetInternalState {
        let refreshed = applyPassiveContext(
            to: stateCache,
            now: Date(),
            userEmotion: EmotionTracker.shared.getCurrentEmotion(),
            timePeriod: TimeContext.shared.currentPeriod,
            activeApp: WindowObserver.shared.currentActiveApp,
            activeDuration: WindowObserver.shared.activeAppDuration
        )

        if refreshed != stateCache {
            saveState(refreshed)
        }

        return refreshed
    }

    func getPromptSummary(includeUnfinishedThought: Bool = false) -> String {
        let state = getCurrentState()

        var segments: [String] = []
        segments.append("你现在的内心偏\(state.mood.rawValue)。")
        segments.append("你的精力大约还有\(state.energy)/100，想被关注的程度是\(state.socialNeed)/100。")
        segments.append("你对这个人的亲近感是\(state.attachmentLevel)/100，委屈值是\(state.frustration)/100。")

        if let goal = state.currentGoal, !goal.isEmpty {
            segments.append("你此刻最直接的念头是：\(goal)。")
        }

        if let focus = state.curiosityFocus, !focus.isEmpty {
            segments.append("你最近特别留意的是：\(focus)。")
        }

        if includeUnfinishedThought, let thought = state.unfinishedThought, !thought.isEmpty {
            segments.append("你心里还挂着一件事：\(thought)。")
        }

        return segments.joined()
    }

    func recordConversationStarted(
        userInput: String,
        emotionInsight: EmotionInsightSnapshot? = nil,
        now: Date = Date()
    ) {
        let current = getCurrentState()
        let reduced = reducedState(from: current, event: .conversationStarted(userInput: userInput), now: now)
        let next = applyEmotionInsight(emotionInsight, to: reduced, now: now)
        saveState(next)
    }

    func recordConversationCompleted(
        response: String,
        emotionInsight: EmotionInsightSnapshot? = nil,
        now: Date = Date()
    ) {
        let current = getCurrentState()
        let reduced = reducedState(from: current, event: .conversationCompleted(response: response), now: now)
        let next = applyEmotionInsight(emotionInsight, to: reduced, now: now)
        saveState(next)
    }

    func recordSelfTalkTriggered(reason: String, now: Date = Date()) {
        let current = getCurrentState()
        let next = reducedState(from: current, event: .selfTalkTriggered(reason: reason), now: now)
        saveState(next)
    }

    func overwriteStateForTesting(_ state: PetInternalState) {
        saveState(state)
    }

    func consumeContextualUnfinishedThought(forConversation userInput: String, now: Date = Date()) -> String? {
        consumeContextualUnfinishedThought(
            now: now,
            shouldMention: { state in
                self.isThoughtRelevantToConversation(
                    thought: state.unfinishedThought,
                    kind: state.unfinishedThoughtKind,
                    userInput: userInput
                )
            }
        )
    }

    func consumeContextualUnfinishedThought(forSelfTalk triggerScene: BubbleTriggerScene, now: Date = Date()) -> String? {
        consumeContextualUnfinishedThought(
            now: now,
            shouldMention: { state in
                self.isThoughtRelevantToSelfTalk(state: state, triggerScene: triggerScene)
            }
        )
    }

    // MARK: - Pure Transition Rules

    func reducedState(from state: PetInternalState, event: PetInternalEvent, now: Date = Date()) -> PetInternalState {
        var next = state
        next.updatedAt = now

        switch event {
        case .conversationStarted(let userInput):
            next.lastInteractionAt = now
            next.socialNeed = clamp(next.socialNeed - 24)
            next.frustration = clamp(next.frustration - 12)
            next.attachmentLevel = clamp(next.attachmentLevel + 4)
            next.energy = clamp(next.energy - 3)

            if containsAny(userInput, keywords: ["累", "难过", "焦虑", "压力", "烦", "崩溃"]) {
                next.mood = .concerned
                next.currentGoal = "想先安慰一下他"
                next = storeUnfinishedThought(
                    in: next,
                    thought: "想晚一点再确认他有没有好一点",
                    kind: .comfort,
                    now: now
                )
            } else if containsAny(userInput, keywords: ["哈哈", "开心", "高兴", "喜欢", "好耶"]) {
                next.mood = .happy
                next.currentGoal = "想顺着这份开心陪他聊下去"
            } else {
                next.mood = .happy
                next.currentGoal = "想继续陪他说话"
            }

            if containsAny(userInput, keywords: ["明天", "下周", "计划", "记得", "安排"]) {
                next = storeUnfinishedThought(
                    in: next,
                    thought: "想记住他刚提到的安排，找机会再轻轻接上",
                    kind: .plan,
                    now: now
                )
            } else if containsAny(userInput, keywords: ["最近", "之后", "回头", "再说", "等等"]) {
                next = storeUnfinishedThought(
                    in: next,
                    thought: "感觉这件事还没聊完，之后可以再顺着问一句",
                    kind: .followUp,
                    now: now
                )
            }

        case .conversationCompleted(let response):
            next.lastInteractionAt = now
            next.socialNeed = clamp(next.socialNeed - 8)
            next.frustration = clamp(next.frustration - 6)
            next.attachmentLevel = clamp(next.attachmentLevel + 2)

            if containsAny(response, keywords: ["休息", "别太累", "陪着", "加油"]) {
                next.mood = .concerned
                next.currentGoal = "想继续温柔地陪着他"
                if next.unfinishedThought == nil {
                    next = storeUnfinishedThought(
                        in: next,
                        thought: "想等会儿再确认他的状态有没有松一点",
                        kind: .comfort,
                        now: now
                    )
                }
            } else {
                next.mood = .calm
                next.currentGoal = "想安静看看他接下来会做什么"
            }

        case .selfTalkTriggered(let reason):
            next.energy = clamp(next.energy - 2)
            next.socialNeed = clamp(next.socialNeed + 6)
            next.frustration = clamp(next.frustration + 2)

            switch reason {
            case "edge":
                next.mood = .playful
                next.currentGoal = "想故意晃到他面前刷存在感"
            case "stationary":
                next.mood = next.socialNeed >= 70 ? .clingy : .lonely
                next.currentGoal = "想看看他会不会理我一下"
            case "random":
                next.mood = next.socialNeed >= 65 ? .clingy : .curious
                next.currentGoal = "想随口说点什么引起注意"
            default:
                next.mood = .curious
                next.currentGoal = "想表达一下现在的心情"
            }
        }

        return normalized(next)
    }

    func applyPassiveContext(
        to state: PetInternalState,
        now: Date = Date(),
        userEmotion: UserEmotionState,
        timePeriod: TimePeriod,
        activeApp: String,
        activeDuration: TimeInterval
    ) -> PetInternalState {
        var next = state
        next.updatedAt = now
        let secondsSinceUpdate = now.timeIntervalSince(state.updatedAt)
        let shouldApplyNumericDrift = secondsSinceUpdate >= 300

        if shouldDropUnfinishedThought(state: next, now: now) {
            next = clearUnfinishedThought(in: next)
        }

        if shouldApplyNumericDrift, let lastInteractionAt = next.lastInteractionAt {
            let idleSeconds = now.timeIntervalSince(lastInteractionAt)

            if idleSeconds > 1800 {
                next.socialNeed = clamp(next.socialNeed + 8)
            }

            if idleSeconds > 7200 {
                next.socialNeed = clamp(next.socialNeed + 12)
                next.frustration = clamp(next.frustration + 8)
            }
        } else if shouldApplyNumericDrift {
            next.socialNeed = clamp(next.socialNeed + 4)
        }

        if shouldApplyNumericDrift {
            switch timePeriod {
            case .lateNight:
                next.energy = clamp(next.energy - 10)
                if next.mood != .concerned {
                    next.mood = .sleepy
                }
                if next.currentGoal == nil || next.currentGoal?.isEmpty == true {
                    next.currentGoal = "想催他早点休息"
                }
            case .night:
                next.energy = clamp(next.energy - 4)
            case .morning:
                next.energy = clamp(next.energy + 4)
            default:
                break
            }
        }

        switch userEmotion {
        case .sad, .stressed, .anxious:
            next.mood = .concerned
            next.currentGoal = "想先确认他是不是需要安慰"
        case .happy, .excited:
            if next.frustration < 30 {
                next.mood = .happy
            }
            if next.currentGoal == nil || next.currentGoal?.isEmpty == true {
                next.currentGoal = "想跟着他的好心情多待一会"
            }
        default:
            break
        }

        if activeDuration > 3600 && !activeApp.isEmpty {
            next.curiosityFocus = "\(activeApp)里发生的事"

            if userEmotion == .busy || userEmotion == .focused {
                next.currentGoal = "想尽量安静地陪他撑完这一段"
            }
        }

        if next.socialNeed >= 72 && userEmotion != .sad && userEmotion != .stressed && userEmotion != .anxious {
            next.mood = .clingy
            next.currentGoal = "想让他注意到我"
        }

        if next.frustration >= 68 && userEmotion != .sad && userEmotion != .stressed && userEmotion != .anxious {
            next.mood = .sulky
            next.currentGoal = "想等他先来理我"
        }

        return normalized(next)
    }

    // MARK: - Persistence

    private func saveState(_ state: PetInternalState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageFile, options: .atomic)
            stateCache = state
            print("🧠 PetInternalStateManager: Saved state - mood=\(state.mood.rawValue), socialNeed=\(state.socialNeed), frustration=\(state.frustration)")
        } catch {
            print("⚠️ PetInternalStateManager: Failed to save state - \(error.localizedDescription)")
        }
    }

    private static func loadState(from file: URL) -> PetInternalState? {
        guard FileManager.default.fileExists(atPath: file.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: file)
            return try JSONDecoder().decode(PetInternalState.self, from: data)
        } catch {
            print("⚠️ PetInternalStateManager: Failed to load state - \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private func normalized(_ state: PetInternalState) -> PetInternalState {
        var next = state
        next.energy = clamp(next.energy)
        next.socialNeed = clamp(next.socialNeed)
        next.attachmentLevel = clamp(next.attachmentLevel)
        next.frustration = clamp(next.frustration)
        return next
    }

    private func applyEmotionInsight(
        _ insight: EmotionInsightSnapshot?,
        to state: PetInternalState,
        now: Date
    ) -> PetInternalState {
        guard let insight, insight.confidence >= 0.55 else {
            return normalized(state)
        }

        var next = state

        switch insight.emotion {
        case .sad, .stressed, .anxious:
            next.mood = .concerned
            next.currentGoal = insight.suggestedPetGoal ?? "想先轻轻安慰一下他"
            next = storeUnfinishedThought(
                in: next,
                thought: insight.unfinishedTopic ?? "想晚一点再确认他的状态有没有缓下来",
                kind: .comfort,
                now: now
            )
        case .happy, .excited:
            next.mood = .happy
            next.currentGoal = insight.suggestedPetGoal ?? "想顺着他的开心再多陪一会"
        case .busy, .focused:
            next.mood = .calm
            next.currentGoal = insight.suggestedPetGoal ?? "想先安静陪着，不打断他"
        case .tired:
            next.mood = .concerned
            next.currentGoal = insight.suggestedPetGoal ?? "想提醒他别太硬撑"
            if insight.confidence >= 0.7 {
                next = storeUnfinishedThought(
                    in: next,
                    thought: insight.unfinishedTopic ?? "想找机会提醒他休息一下",
                    kind: .comfort,
                    now: now
                )
            }
        case .relaxed, .neutral:
            if let goal = insight.suggestedPetGoal, !goal.isEmpty {
                next.currentGoal = goal
            }
        }

        if let topic = insight.unfinishedTopic,
           !topic.isEmpty,
           next.unfinishedThought == nil,
           insight.confidence >= 0.72 {
            next = storeUnfinishedThought(
                in: next,
                thought: topic,
                kind: inferredThoughtKind(from: insight.emotion),
                now: now
            )
        }

        return normalized(next)
    }

    private func consumeContextualUnfinishedThought(
        now: Date,
        shouldMention: (PetInternalState) -> Bool
    ) -> String? {
        let current = getCurrentState()

        guard let thought = current.unfinishedThought, !thought.isEmpty else {
            return nil
        }

        guard !shouldDropUnfinishedThought(state: current, now: now) else {
            let cleared = clearUnfinishedThought(in: current)
            saveState(cleared)
            return nil
        }

        if let lastMentionedAt = current.unfinishedThoughtLastMentionedAt,
           now.timeIntervalSince(lastMentionedAt) < thoughtMentionCooldown(for: current.unfinishedThoughtKind) {
            return nil
        }

        guard shouldMention(current) else {
            return nil
        }

        var next = current
        next.unfinishedThoughtLastMentionedAt = now
        next.unfinishedThoughtMentionCount += 1
        next.updatedAt = now
        saveState(next)
        return thought
    }

    private func thoughtMentionCooldown(for kind: UnfinishedThoughtKind?) -> TimeInterval {
        switch kind {
        case .plan:
            return 3600
        case .comfort:
            return 1800
        case .followUp:
            return 5400
        case nil:
            return 3600
        }
    }

    private func shouldDropUnfinishedThought(state: PetInternalState, now: Date) -> Bool {
        guard let updatedAt = state.unfinishedThoughtUpdatedAt else {
            return false
        }

        let age = now.timeIntervalSince(updatedAt)
        if age >= 3 * 24 * 3600 {
            return true
        }

        if state.unfinishedThoughtMentionCount >= 3 && age >= 12 * 3600 {
            return true
        }

        return false
    }

    private func isThoughtRelevantToConversation(
        thought: String?,
        kind: UnfinishedThoughtKind?,
        userInput: String
    ) -> Bool {
        guard thought != nil else { return false }

        switch kind {
        case .plan:
            return containsAny(userInput, keywords: ["明天", "下周", "计划", "安排", "记得", "之后"])
        case .comfort:
            return containsAny(userInput, keywords: ["累", "难过", "焦虑", "压力", "烦", "崩溃", "还好", "好多了"])
        case .followUp:
            return containsAny(userInput, keywords: ["刚刚", "刚才", "之后", "回头", "再说", "继续", "那个"])
        case nil:
            return false
        }
    }

    private func isThoughtRelevantToSelfTalk(state: PetInternalState, triggerScene: BubbleTriggerScene) -> Bool {
        switch state.unfinishedThoughtKind {
        case .comfort:
            return state.mood == .concerned || state.socialNeed >= 58
        case .plan:
            return triggerScene == .stationaryTimeout || triggerScene == .random
        case .followUp:
            return triggerScene == .stationaryTimeout && state.socialNeed >= 64
        case nil:
            return false
        }
    }

    private func storeUnfinishedThought(
        in state: PetInternalState,
        thought: String,
        kind: UnfinishedThoughtKind,
        now: Date
    ) -> PetInternalState {
        var next = state
        next.unfinishedThought = thought
        next.unfinishedThoughtKind = kind
        next.unfinishedThoughtUpdatedAt = now
        next.unfinishedThoughtLastMentionedAt = nil
        next.unfinishedThoughtMentionCount = 0
        return next
    }

    private func clearUnfinishedThought(in state: PetInternalState) -> PetInternalState {
        var next = state
        next.unfinishedThought = nil
        next.unfinishedThoughtKind = nil
        next.unfinishedThoughtUpdatedAt = nil
        next.unfinishedThoughtLastMentionedAt = nil
        next.unfinishedThoughtMentionCount = 0
        return next
    }

    private func inferredThoughtKind(from emotion: UserEmotionState) -> UnfinishedThoughtKind {
        switch emotion {
        case .sad, .stressed, .anxious, .tired:
            return .comfort
        case .busy, .focused:
            return .followUp
        default:
            return .plan
        }
    }

    private func clamp(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    private func containsAny(_ content: String, keywords: [String]) -> Bool {
        keywords.contains { content.contains($0) }
    }
}

extension PetInternalState: Equatable {}
