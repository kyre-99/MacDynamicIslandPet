import Foundation
import Combine

class WorkingMemoryTests: ObservableObject {
    static let shared = WorkingMemoryTests()

    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
    }

    @Published var allResults: [TestResult] = []

    private let workingMemoryManager = WorkingMemoryManager.shared
    private let petStateManager = PetInternalStateManager.shared
    private let memoryManager = MemoryManager.shared
    private let relationshipManager = RelationshipMemoryManager.shared
    private let memoryCardManager = MemoryCardManager.shared

    private init() {}

    func runAllTests() -> [TestResult] {
        let results = [
            runPromptBlockStructureTest(),
            runConversationContinuityTest(),
            runSelfTalkRecallLimitTest()
        ]

        allResults = results
        return results
    }

    private func runPromptBlockStructureTest() -> TestResult {
        let context = WorkingMemoryContext(
            identitySummary: "你是小精灵。",
            relationshipSummary: "你们已经很熟。",
            internalStateSummary: "你现在有点在意他。",
            environmentSummary: "他正在用 Xcode。",
            recentConversationSummary: "用户说：今天有点累；你回：先歇一下。",
            recalledMemories: ["[对话] 他上周提过旅行计划"],
            unfinishedThought: "想晚点再问一下他的状态"
        )

        let prompt = context.asPromptBlock()
        let passed = prompt.contains("#【身份】") &&
            prompt.contains("#【关系】") &&
            prompt.contains("#【环境】") &&
            prompt.contains("#【未完的念头】")

        return TestResult(
            testName: "工作记忆结构块测试",
            passed: passed,
            details: "length=\(prompt.count), hasThought=\(prompt.contains("未完的念头"))"
        )
    }

    private func runConversationContinuityTest() -> TestResult {
        let now = Date()
        let initial = PetInternalState(
            mood: .concerned,
            energy: 71,
            socialNeed: 58,
            attachmentLevel: 63,
            frustration: 10,
            curiosityFocus: "他今天的状态",
            currentGoal: "想轻一点确认他有没有好一点",
            unfinishedThought: "想晚一点再确认他有没有好一点",
            unfinishedThoughtKind: .comfort,
            unfinishedThoughtUpdatedAt: now.addingTimeInterval(-900),
            unfinishedThoughtLastMentionedAt: nil,
            unfinishedThoughtMentionCount: 0,
            lastInteractionAt: now.addingTimeInterval(-1200),
            updatedAt: now.addingTimeInterval(-600)
        )
        petStateManager.overwriteStateForTesting(initial)

        memoryManager.saveConversation(
            userInput: "我刚刚真的有点累，不过现在缓过来一点了",
            petResponse: "那就好，我刚才还有点担心你会不会撑太久"
        )
        relationshipManager.refreshRelationshipSnapshot()

        let context = workingMemoryManager.buildConversationContext(userInput: "现在好多了，不过还是有一点累")
        let passed = context.unfinishedThought?.contains("好一点") == true &&
            !context.relationshipSummary.isEmpty &&
            !context.internalStateSummary.contains("你心里还挂着一件事")

        return TestResult(
            testName: "对话连续性工作记忆测试",
            passed: passed,
            details: "thought=\(context.unfinishedThought ?? "无"), relationLength=\(context.relationshipSummary.count)"
        )
    }

    private func runSelfTalkRecallLimitTest() -> TestResult {
        let now = Date()
        let initial = PetInternalState(
            mood: .clingy,
            energy: 66,
            socialNeed: 76,
            attachmentLevel: 68,
            frustration: 18,
            curiosityFocus: "最近提过的安排",
            currentGoal: "想轻轻提醒一下自己还记得那件事",
            unfinishedThought: "想记住他刚提到的安排，找机会再轻轻接上",
            unfinishedThoughtKind: .plan,
            unfinishedThoughtUpdatedAt: now.addingTimeInterval(-1800),
            unfinishedThoughtLastMentionedAt: nil,
            unfinishedThoughtMentionCount: 0,
            lastInteractionAt: now.addingTimeInterval(-3600),
            updatedAt: now.addingTimeInterval(-900)
        )
        petStateManager.overwriteStateForTesting(initial)

        memoryManager.saveConversation(
            userInput: "下周还要复盘项目，也许还得安排一次体检",
            petResponse: "好，我把这些都悄悄记住了"
        )
        memoryCardManager.ingestConversation(
            userInput: "明天想早点出门办事",
            petResponse: "那我之后可以提醒你别忘了时间",
            topics: [.plan, .daily],
            emotions: [.calm],
            importanceScore: 7
        )

        let context = workingMemoryManager.buildSelfTalkContext(triggerScene: .stationaryTimeout)
        let passed = context.recalledMemories.count <= 3 &&
            context.unfinishedThought?.contains("安排") == true

        return TestResult(
            testName: "自言自语记忆裁剪测试",
            passed: passed,
            details: "recalled=\(context.recalledMemories.count), thought=\(context.unfinishedThought ?? "无")"
        )
    }
}
