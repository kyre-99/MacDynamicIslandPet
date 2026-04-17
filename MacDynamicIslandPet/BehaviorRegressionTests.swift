import Foundation
import Combine

class BehaviorRegressionTests: ObservableObject {
    static let shared = BehaviorRegressionTests()

    struct SuiteResult {
        let suiteName: String
        let passedCount: Int
        let totalCount: Int
        let details: String

        var passed: Bool {
            passedCount == totalCount
        }
    }

    @Published var suiteResults: [SuiteResult] = []

    private init() {}

    func runAllSuites() -> [SuiteResult] {
        let suites: [(String, [Bool], [String])] = [
            summarize(
                name: "PetInternalState",
                results: PetInternalStateTests.shared.runAllTests().map { ($0.passed, $0.testName) }
            ),
            summarize(
                name: "MemoryCard",
                results: MemoryCardTests.shared.runAllTests().map { ($0.passed, $0.testName) }
            ),
            summarize(
                name: "RelationshipMemory",
                results: RelationshipMemoryTests.shared.runAllTests().map { ($0.passed, $0.testName) }
            ),
            summarize(
                name: "WorkingMemory",
                results: WorkingMemoryTests.shared.runAllTests().map { ($0.passed, $0.testName) }
            )
        ]

        let mapped = suites.map { suite in
            SuiteResult(
                suiteName: suite.0,
                passedCount: suite.1.filter { $0 }.count,
                totalCount: suite.1.count,
                details: suite.2.joined(separator: "、")
            )
        }

        suiteResults = mapped
        return mapped
    }

    private func summarize(name: String, results: [(Bool, String)]) -> (String, [Bool], [String]) {
        let failedTests = results.compactMap { passed, testName in
            passed ? nil : testName
        }
        let detail = failedTests.isEmpty ? "全部通过" : "失败项: " + failedTests.joined(separator: ", ")
        return (name, results.map(\.0), [detail])
    }
}
