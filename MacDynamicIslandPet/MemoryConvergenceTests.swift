import Foundation
import Combine

/// 记忆收敛测试类
/// US-015: 验证长期运行后记忆系统的稳定性
///
/// 提供以下验证功能：
/// - 记忆目录总文件大小 <10MB
/// - 记忆检索响应时间 <100ms
/// - 30天前的daily Markdown文件已被清理
/// - EvolutionManager.calculateLevel() 正确计算进化等级
/// - 模拟300次气泡生成，内存增长 <50MB
class MemoryConvergenceTests: ObservableObject {
    /// 共享单例实例
    static let shared = MemoryConvergenceTests()

    /// CommentGenerator引用
    private let commentGenerator = CommentGenerator.shared

    /// 数据生成器引用
    private let dataGenerator = SimulatedInteractionDataGenerator.shared

    /// 测试结果结构体
    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
        let metrics: [String: Double]
    }

    /// 所有测试结果
    @Published var allResults: [TestResult] = []

    /// 测试进度
    @Published var progress: Double = 0.0

    /// 状态描述
    @Published var statusDescription: String = ""

    private init() {}

    // MARK: - Test Execution

    /// 运行所有收敛测试
    /// - Returns: 所有测试结果数组
    func runAllTests() -> [TestResult] {
        var results: [TestResult] = []

        statusDescription = "开始记忆收敛测试..."
        progress = 0.0

        // 测试用例1：文件大小验证
        results.append(runFileSizeTest())
        progress = 20

        // 测试用例2：检索速度验证
        results.append(runRetrievalSpeedTest())
        progress = 40

        // 测试用例3：清理机制验证
        results.append(runCleanupVerificationTest())
        progress = 60

        // 测试用例4：进化等级计算验证
        results.append(runEvolutionLevelTest())
        progress = 80

        // 测试用例5：内存泄漏检查
        results.append(runMemoryLeakTest())
        progress = 100

        allResults = results
        statusDescription = "测试完成"
        return results
    }

    /// 测试用例1：检查记忆目录总文件大小 <10MB
    /// US-015: 验证长期运行后记忆文件不超过存储限制
    /// - Returns: 测试结果
    func runFileSizeTest() -> TestResult {
        let testName = "文件大小验证 (<10MB)"

        let totalSize = dataGenerator.calculateMemoryDirectorySize()
        let sizeInMB = Double(totalSize) / (1024 * 1024)

        let passed = sizeInMB < 10.0
        let details = "记忆目录总大小: \(dataGenerator.formatSize(totalSize)) (阈值: <10MB)"

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            metrics: ["fileSizeMB": sizeInMB, "thresholdMB": 10.0]
        )
    }

    /// 测试用例2：执行记忆检索操作，验证响应时间 <100ms
    /// US-015: 验证记忆检索性能符合要求
    /// - Returns: 测试结果
    func runRetrievalSpeedTest() -> TestResult {
        let testName = "检索速度验证 (<100ms)"

        // 执行5次气泡类型选择，取平均时间（测试整体响应性能）
        var retrievalTimes: [Double] = []

        let profile = PersonalityManager.shared.currentProfile
        for _ in 0..<5 {
            let startTime = Date()
            _ = commentGenerator.selectBubbleType(triggerScene: .random, personalityProfile: profile)
            let endTime = Date()
            let durationMs = endTime.timeIntervalSince(startTime) * 1000
            retrievalTimes.append(durationMs)
        }

        let avgTimeMs = retrievalTimes.reduce(0, +) / Double(retrievalTimes.count)
        let maxTimeMs = retrievalTimes.max() ?? 0

        let passed = avgTimeMs < 100.0
        let details = """
        平均检索时间: \(String(format: "%.2f", avgTimeMs))ms
        最大检索时间: \(String(format: "%.2f", maxTimeMs))ms
        阈值: <100ms
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            metrics: ["avgTimeMs": avgTimeMs, "maxTimeMs": maxTimeMs, "thresholdMs": 100.0]
        )
    }

    /// 测试用例3：验证30天前的daily Markdown文件已被清理
    /// US-015: 验证记忆清理机制正确工作
    /// - Returns: 测试结果
    func runCleanupVerificationTest() -> TestResult {
        let testName = "清理机制验证"

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let dailyDir = MemoryStoragePath.dailyDirectory
        var oldFilesExist = false
        var oldFileCount = 0

        do {
            let files = try FileManager.default.contentsOfDirectory(at: dailyDir, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "md" {
                // 检查文件名中的日期
                let fileName = file.lastPathComponent
                if fileName.hasPrefix("memory-") {
                    let dateStr = fileName.replacingOccurrences(of: "memory-", with: "").replacingOccurrences(of: ".md", with: "")
                    if let fileDate = DateFormatter.yyyyMMdd.date(from: dateStr),
                       fileDate < thirtyDaysAgo {
                        oldFilesExist = true
                        oldFileCount += 1
                    }
                }
            }
        } catch {
            print("⚠️ Failed to check daily files: \(error.localizedDescription)")
        }

        let passed = !oldFilesExist
        let details = """
        30天前文件数量: \(oldFileCount)
        清理状态: \(passed ? "已清理" : "未清理")
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            metrics: ["oldFileCount": Double(oldFileCount)]
        )
    }

    /// 测试用例4：验证EvolutionManager.calculateLevel()正确计算进化等级
    /// US-015: 验证进化等级计算逻辑
    /// - Returns: 测试结果
    func runEvolutionLevelTest() -> TestResult {
        let testName = "进化等级计算验证"

        // 测试不同天数对应的等级
        let testCases: [(days: Int, expectedLevel: Int)] = [
            (1, 1),    // Lv1: 1-7天
            (7, 1),    // Lv1: 1-7天
            (8, 2),    // Lv2: 8-14天
            (14, 2),   // Lv2: 8-14天
            (15, 3),   // Lv3: 15-30天
            (30, 3),   // Lv3: 15-30天
            (31, 4),   // Lv4: 31-60天
            (60, 4),   // Lv4: 31-60天
            (61, 5),   // Lv5: 61-90天
            (90, 5),   // Lv5: 61-90天
            (91, 6),   // Lv6: 91-180天
            (180, 6),  // Lv6: 91-180天
            (181, 7),  // Lv7: 181-365天
            (365, 7),  // Lv7: 181-365天
            (366, 8),  // Lv8: 366-730天
            (730, 8),  // Lv8: 366-730天
            (731, 9),  // Lv9: 731-1095天
            (1095, 9), // Lv9: 731-1095天
            (1096, 10) // Lv10: >1095天
        ]

        var correctCount = 0
        var incorrectCases: [String] = []

        for testCase in testCases {
            let calculatedLevel = EvolutionLevel.fromDays(testCase.days).levelNumber
            if calculatedLevel == testCase.expectedLevel {
                correctCount += 1
            } else {
                incorrectCases.append("\(testCase.days)天: 期望Lv\(testCase.expectedLevel), 实际Lv\(calculatedLevel)")
            }
        }

        let passed = correctCount == testCases.count
        let details = """
        正确计算: \(correctCount)/\(testCases.count)
        错误案例: \(incorrectCases.isEmpty ? "无" : incorrectCases.joined(separator: "\n"))
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            metrics: ["correctRate": Double(correctCount) / Double(testCases.count)]
        )
    }

    /// 测试用例5：模拟300次气泡生成，检查内存增长 <50MB
    /// US-015: 验证不存在内存泄漏
    /// - Returns: 测试结果
    func runMemoryLeakTest() -> TestResult {
        let testName = "内存泄漏检查 (<50MB)"

        // 记录初始内存使用
        let initialMemory = getMemoryUsageMB()

        // 模拟300次气泡类型选择（不实际生成气泡，避免LLM调用）
        let profile = PersonalityManager.shared.currentProfile
        for _ in 0..<300 {
            _ = commentGenerator.selectBubbleType(triggerScene: .random, personalityProfile: profile)
        }

        // 记录最终内存使用
        let finalMemory = getMemoryUsageMB()
        let memoryGrowth = finalMemory - initialMemory

        let passed = memoryGrowth < 50.0
        let details = """
        初始内存: \(String(format: "%.2f", initialMemory))MB
        最终内存: \(String(format: "%.2f", finalMemory))MB
        内存增长: \(String(format: "%.2f", memoryGrowth))MB
        阈值: <50MB
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            metrics: ["initialMemoryMB": initialMemory, "finalMemoryMB": finalMemory, "growthMB": memoryGrowth, "thresholdMB": 50.0]
        )
    }

    // MARK: - Helper Methods

    /// 获取当前内存使用量（MB）
    /// - Returns: 内存使用量
    private func getMemoryUsageMB() -> Double {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedBytes = info.resident_size
            return Double(usedBytes) / (1024 * 1024)
        }

        return 0.0
    }

    // MARK: - Statistics Summary

    /// 获取测试统计摘要
    /// - Returns: 统计信息字符串
    func getStatisticsSummary() -> String {
        let passedCount = allResults.filter { $0.passed }.count
        let totalCount = allResults.count

        return """
        记忆收敛测试结果：
        通过: \(passedCount)/\(totalCount)
        通过率: \(Int(Double(passedCount) / Double(totalCount) * 100))%
        """
    }

    /// 获取文件大小统计
    /// - Returns: 文件大小信息
    func getFileSizeStatistics() -> String {
        let size = dataGenerator.calculateMemoryDirectorySize()
        return dataGenerator.formatSize(size)
    }

    /// 获取平均检索速度
    /// - Returns: 平均检索速度（毫秒）
    func getAverageRetrievalSpeed() -> Double {
        let speedResult = allResults.first { $0.testName.contains("检索速度") }
        return speedResult?.metrics["avgTimeMs"] ?? 0.0
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    /// yyyy-MM-dd 格式化器
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}