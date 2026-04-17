import Foundation
import Combine

class RelationshipMemoryTests: ObservableObject {
    static let shared = RelationshipMemoryTests()

    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
    }

    @Published var allResults: [TestResult] = []

    private let memoryManager = MemoryManager.shared
    private let relationshipMemoryManager = RelationshipMemoryManager.shared
    private let evolutionManager = EvolutionManager.shared

    private init() {}

    func runAllTests() -> [TestResult] {
        let results = [
            runSnapshotRefreshTest(),
            runEmotionAwareSummaryTest()
        ]

        allResults = results
        return results
    }

    private func runSnapshotRefreshTest() -> TestResult {
        evolutionManager.updateDaysTogether(12)

        memoryManager.saveConversation(
            userInput: "我最近工作有点忙，不过还是想和你说说今天发生了什么",
            petResponse: "那你慢慢说，我会认真记着你今天的心情和节奏"
        )
        memoryManager.saveConversation(
            userInput: "下周我想去看展，想提前安排一下时间",
            petResponse: "好呀，这种计划我会替你放在心上"
        )

        let snapshot = relationshipMemoryManager.refreshRelationshipSnapshot()
        let passed = !snapshot.stageSummary.isEmpty &&
            (snapshot.preferredTone?.isEmpty == false) &&
            !snapshot.interactionPatterns.isEmpty

        return TestResult(
            testName: "关系快照刷新测试",
            passed: passed,
            details: "stage=\(snapshot.stageSummary), tone=\(snapshot.preferredTone ?? "无"), patterns=\(snapshot.interactionPatterns.count)"
        )
    }

    private func runEmotionAwareSummaryTest() -> TestResult {
        evolutionManager.updateDaysTogether(40)

        memoryManager.saveConversation(
            userInput: "我这两天压力有点大，心情也不太好，但还是想跟你讲讲",
            petResponse: "那我先安静陪你，把这些难受一点点接住"
        )
        memoryManager.saveConversation(
            userInput: "谢谢你一直记着我说过的话，有你在真的会安心一点",
            petResponse: "你愿意这样告诉我，我会更认真地照顾你的情绪"
        )

        let snapshot = relationshipMemoryManager.refreshRelationshipSnapshot()
        let hasSensitiveMood = snapshot.sensitiveTopics.contains("心情")
        let hasInterpretation = snapshot.petInterpretations.contains { interpretation in
            interpretation.contains("想到你") ||
            interpretation.contains("认真接住") ||
            interpretation.contains("陪伴")
        }

        return TestResult(
            testName: "关系摘要情绪感知测试",
            passed: hasSensitiveMood && hasInterpretation,
            details: "sensitive=\(snapshot.sensitiveTopics.joined(separator: ",")), interpretations=\(snapshot.petInterpretations.joined(separator: " | "))"
        )
    }
}
