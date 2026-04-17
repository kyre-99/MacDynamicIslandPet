import Foundation
import Combine

class MemoryCardTests: ObservableObject {
    static let shared = MemoryCardTests()

    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
    }

    @Published var allResults: [TestResult] = []

    private init() {}

    func runAllTests() -> [TestResult] {
        let results = [
            runConversationIngestTest(),
            runPerceptionRecallTest()
        ]
        allResults = results
        return results
    }

    private func runConversationIngestTest() -> TestResult {
        let manager = MemoryCardManager.shared
        let beforeCount = manager.getAllCards().count

        manager.ingestConversation(
            userInput: "我下周想去旅行，最近压力也有点大",
            petResponse: "那我先帮你记着这件事，也别把自己逼太紧啦",
            topics: [.plan, .mood],
            emotions: [.anxious],
            importanceScore: 7
        )

        let afterCards = manager.getAllCards()
        let added = afterCards.count >= beforeCount
        let found = afterCards.contains { $0.summary.contains("下周想去旅行") || $0.summary.contains("压力也有点大") }

        return TestResult(
            testName: "对话建卡测试",
            passed: added && found,
            details: "before=\(beforeCount), after=\(afterCards.count), found=\(found)"
        )
    }

    private func runPerceptionRecallTest() -> TestResult {
        let manager = MemoryCardManager.shared

        manager.ingestPerception(
            appName: "Xcode",
            activityDescription: "正在修改拟人化记忆系统",
            screenshotSummary: nil,
            petReaction: "今天也在和代码较劲呀"
        )

        let cards = manager.searchRelevantCards(
            query: MemoryCardQuery(
                text: "记忆系统",
                emotion: .focused,
                appName: "Xcode",
                limit: 3
            )
        )

        let found = cards.contains { $0.summary.contains("Xcode") || $0.summary.contains("记忆系统") }

        return TestResult(
            testName: "感知检索测试",
            passed: found,
            details: "matchedCards=\(cards.count)"
        )
    }
}
