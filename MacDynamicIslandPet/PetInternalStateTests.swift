import Foundation
import Combine

/// 小人内部状态验证测试
class PetInternalStateTests: ObservableObject {
    static let shared = PetInternalStateTests()

    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
    }

    @Published var allResults: [TestResult] = []

    private let stateManager = PetInternalStateManager.shared

    private init() {}

    func runAllTests() -> [TestResult] {
        let results = [
            runConversationStartTest(),
            runPassiveDriftTest(),
            runSelfTalkTriggerTest(),
            runComfortContextTest(),
            runHybridEmotionInsightTest(),
            runUnfinishedThoughtCreationTest(),
            runUnfinishedThoughtCooldownTest()
        ]

        allResults = results
        return results
    }

    func runConversationStartTest() -> TestResult {
        let testName = "对话开始降低社交饥渴"
        let initial = PetInternalState(
            mood: .lonely,
            energy: 70,
            socialNeed: 82,
            attachmentLevel: 50,
            frustration: 30,
            curiosityFocus: nil,
            currentGoal: "想被注意到",
            unfinishedThought: nil,
            unfinishedThoughtKind: nil,
            unfinishedThoughtUpdatedAt: nil,
            unfinishedThoughtLastMentionedAt: nil,
            unfinishedThoughtMentionCount: 0,
            lastInteractionAt: Date().addingTimeInterval(-7200),
            updatedAt: Date()
        )

        let next = stateManager.reducedState(
            from: initial,
            event: .conversationStarted(userInput: "我今天有点累，但想和你聊聊"),
            now: Date()
        )

        let passed = next.socialNeed < initial.socialNeed &&
            next.attachmentLevel > initial.attachmentLevel &&
            next.mood == .concerned

        let details = "socialNeed: \(initial.socialNeed) -> \(next.socialNeed), attachment: \(initial.attachmentLevel) -> \(next.attachmentLevel), mood: \(next.mood.rawValue)"
        return TestResult(testName: testName, passed: passed, details: details)
    }

    func runPassiveDriftTest() -> TestResult {
        let testName = "长时间未互动会变得更想被理"
        let initial = PetInternalState(
            mood: .calm,
            energy: 60,
            socialNeed: 35,
            attachmentLevel: 45,
            frustration: 10,
            curiosityFocus: nil,
            currentGoal: nil,
            unfinishedThought: nil,
            unfinishedThoughtKind: nil,
            unfinishedThoughtUpdatedAt: nil,
            unfinishedThoughtLastMentionedAt: nil,
            unfinishedThoughtMentionCount: 0,
            lastInteractionAt: Date().addingTimeInterval(-10800),
            updatedAt: Date().addingTimeInterval(-900)
        )

        let next = stateManager.applyPassiveContext(
            to: initial,
            now: Date(),
            userEmotion: .neutral,
            timePeriod: .afternoon,
            activeApp: "Xcode",
            activeDuration: 4200
        )

        let passed = next.socialNeed > initial.socialNeed &&
            next.frustration >= initial.frustration &&
            (next.currentGoal?.contains("陪") == true || next.currentGoal?.contains("注意") == true)

        let details = "socialNeed: \(initial.socialNeed) -> \(next.socialNeed), frustration: \(initial.frustration) -> \(next.frustration), goal: \(next.currentGoal ?? "无")"
        return TestResult(testName: testName, passed: passed, details: details)
    }

    func runSelfTalkTriggerTest() -> TestResult {
        let testName = "自言自语触发会形成主动目标"
        let initial = PetInternalState(
            mood: .calm,
            energy: 66,
            socialNeed: 68,
            attachmentLevel: 52,
            frustration: 14,
            curiosityFocus: nil,
            currentGoal: nil,
            unfinishedThought: nil,
            unfinishedThoughtKind: nil,
            unfinishedThoughtUpdatedAt: nil,
            unfinishedThoughtLastMentionedAt: nil,
            unfinishedThoughtMentionCount: 0,
            lastInteractionAt: Date().addingTimeInterval(-2400),
            updatedAt: Date()
        )

        let next = stateManager.reducedState(
            from: initial,
            event: .selfTalkTriggered(reason: "edge"),
            now: Date()
        )

        let passed = next.mood == .playful &&
            next.socialNeed > initial.socialNeed &&
            next.currentGoal?.contains("刷存在感") == true

        let details = "mood: \(initial.mood.rawValue) -> \(next.mood.rawValue), socialNeed: \(initial.socialNeed) -> \(next.socialNeed), goal: \(next.currentGoal ?? "无")"
        return TestResult(testName: testName, passed: passed, details: details)
    }

    func runComfortContextTest() -> TestResult {
        let testName = "用户低落时小人转为关心模式"
        let initial = PetInternalState.initialState()

        let next = stateManager.applyPassiveContext(
            to: initial,
            now: Date(),
            userEmotion: .sad,
            timePeriod: .evening,
            activeApp: "Notes",
            activeDuration: 600
        )

        let passed = next.mood == .concerned &&
            next.currentGoal?.contains("安慰") == true

        let details = "mood: \(next.mood.rawValue), goal: \(next.currentGoal ?? "无")"
        return TestResult(testName: testName, passed: passed, details: details)
    }

    func runHybridEmotionInsightTest() -> TestResult {
        let testName = "高置信度理解会加强关心与挂念"
        let now = Date()
        stateManager.overwriteStateForTesting(PetInternalState.initialState())

        let insight = EmotionInsightSnapshot(
            emotion: .stressed,
            confidence: 0.84,
            source: "rules+llm",
            unfinishedTopic: "想晚点再问问他这个压力源有没有缓一点",
            suggestedPetGoal: "先轻轻安慰一下，不要追问太重",
            summary: "用户像是在扛压力，但还想继续撑着",
            trend: "最近几次更偏疲惫或压力"
        )

        stateManager.recordConversationStarted(
            userInput: "今天事情好多，真的有点顶不住",
            emotionInsight: insight,
            now: now
        )

        let current = stateManager.getCurrentState()
        let passed = current.mood == .concerned &&
            current.currentGoal?.contains("安慰") == true &&
            current.unfinishedThought?.contains("压力源") == true

        let details = "mood: \(current.mood.rawValue), goal: \(current.currentGoal ?? "无"), thought: \(current.unfinishedThought ?? "无")"
        return TestResult(testName: testName, passed: passed, details: details)
    }

    func runUnfinishedThoughtCreationTest() -> TestResult {
        let testName = "提到安排后会形成挂念"
        let next = stateManager.reducedState(
            from: PetInternalState.initialState(),
            event: .conversationStarted(userInput: "我下周想去复查一下牙，得记得提前安排时间"),
            now: Date()
        )

        let passed = next.unfinishedThought?.contains("安排") == true &&
            next.unfinishedThoughtKind == .plan &&
            next.unfinishedThoughtMentionCount == 0

        let details = "thought: \(next.unfinishedThought ?? "无"), kind: \(next.unfinishedThoughtKind?.rawValue ?? "无")"
        return TestResult(testName: testName, passed: passed, details: details)
    }

    func runUnfinishedThoughtCooldownTest() -> TestResult {
        let testName = "挂念有冷却不会连续复读"
        let now = Date()
        let initial = PetInternalState(
            mood: .concerned,
            energy: 64,
            socialNeed: 62,
            attachmentLevel: 58,
            frustration: 12,
            curiosityFocus: nil,
            currentGoal: "想再关心他一下",
            unfinishedThought: "想晚一点再确认他有没有好一点",
            unfinishedThoughtKind: .comfort,
            unfinishedThoughtUpdatedAt: now.addingTimeInterval(-900),
            unfinishedThoughtLastMentionedAt: nil,
            unfinishedThoughtMentionCount: 0,
            lastInteractionAt: now.addingTimeInterval(-1200),
            updatedAt: now.addingTimeInterval(-600)
        )

        stateManager.overwriteStateForTesting(initial)

        let firstMention = stateManager.consumeContextualUnfinishedThought(forSelfTalk: .stationaryTimeout, now: now)
        let secondMention = stateManager.consumeContextualUnfinishedThought(forSelfTalk: .stationaryTimeout, now: now.addingTimeInterval(300))
        let current = stateManager.getCurrentState()

        let passed = firstMention != nil && secondMention == nil
        let details = "first: \(firstMention ?? "无"), second: \(secondMention ?? "无"), mentions: \(current.unfinishedThoughtMentionCount)"
        return TestResult(testName: testName, passed: passed, details: details)
    }
}
