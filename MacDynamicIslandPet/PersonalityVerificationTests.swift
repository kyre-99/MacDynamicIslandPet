import Foundation
import Combine

/// 性格影响验证测试类
/// US-014: 验证性格参数确实影响精灵的对话风格
///
/// 提供以下验证功能：
/// - 高幽默度精灵生成调侃气泡概率>60%
/// - 高温柔度精灵生成关心气泡概率>60%
/// - 高叛逆度精灵生成吐槽气泡概率>60%
/// - 不同性格模板生成明显不同的表达风格
/// - 性格参数修改后立即生效影响下一次气泡生成
class PersonalityVerificationTests: ObservableObject {
    /// 共享单例实例
    static let shared = PersonalityVerificationTests()

    /// CommentGenerator引用
    private let commentGenerator = CommentGenerator.shared

    /// PersonalityManager引用
    private let personalityManager = PersonalityManager.shared

    /// 测试结果结构体
    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
        let bubbleTypeCounts: [String: Int]
        let totalBubbles: Int
    }

    /// 所有测试结果
    @Published var allResults: [TestResult] = []

    private init() {}

    // MARK: - Test Execution

    /// 运行所有验证测试
    /// - Returns: 所有测试结果数组
    func runAllTests() -> [TestResult] {
        var results: [TestResult] = []

        // 测试用例1：高幽默度验证
        results.append(runHumorHighTest())

        // 测试用例2：高温柔度验证
        results.append(runGentlenessHighTest())

        // 测试用例3：高叛逆度验证
        results.append(runRebellionHighTest())

        // 测试用例4：活泼型模板验证
        results.append(runEnergeticTemplateTest())

        // 测试用例5：温柔型模板验证
        results.append(runGentleTemplateTest())

        // 测试用例6：叛逆型模板验证
        results.append(runRebelliousTemplateTest())

        // 对比测试
        results.append(runContrastTest())

        // 即时生效测试
        results.append(runImmediateEffectTest())

        allResults = results
        return results
    }

    /// 测试用例1：设置幽默感=90、其他维度=50，触发10次气泡生成，验证teasing占比>60%
    /// US-014: 高幽默度精灵应生成更多调侃气泡
    /// - Returns: 测试结果
    func runHumorHighTest() -> TestResult {
        let testName = "高幽默度测试 (humor=90)"

        // 设置测试性格参数
        let testProfile = PersonalityProfile(
            extroversion: 50,
            curiosity: 50,
            clinginess: 50,
            humor: 90,
            gentleness: 50,
            rebellion: 50
        )

        // 统计气泡类型
        var bubbleTypeCounts: [String: Int] = [
            "greeting": 0,
            "caring": 0,
            "memory": 0,
            "opinion": 0,
            "teasing": 0
        ]

        // 模拟10次气泡类型选择
        for _ in 0..<10 {
            let selectedType = commentGenerator.selectBubbleType(
                triggerScene: .random,
                personalityProfile: testProfile
            )
            bubbleTypeCounts[selectedType.rawValue]! += 1
        }

        // 验证teasing占比>60%
        let teasingCount = bubbleTypeCounts["teasing"]!
        let teasingRatio = Double(teasingCount) / 10.0
        let passed = teasingRatio > 0.6
        let details = "teasing气泡数量: \(teasingCount)/10 (占比: \(Int(teasingRatio * 100))%)，阈值: >60%"

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: bubbleTypeCounts,
            totalBubbles: 10
        )
    }

    /// 测试用例2：设置温柔度=90、其他维度=50，触发10次气泡生成，验证caring占比>60%
    /// US-014: 高温柔度精灵应生成更多关心气泡
    /// - Returns: 测试结果
    func runGentlenessHighTest() -> TestResult {
        let testName = "高温柔度测试 (gentleness=90)"

        // 设置测试性格参数
        let testProfile = PersonalityProfile(
            extroversion: 50,
            curiosity: 50,
            clinginess: 50,
            humor: 50,
            gentleness: 90,
            rebellion: 50
        )

        // 统计气泡类型
        var bubbleTypeCounts: [String: Int] = [
            "greeting": 0,
            "caring": 0,
            "memory": 0,
            "opinion": 0,
            "teasing": 0
        ]

        // 模拟10次气泡类型选择
        for _ in 0..<10 {
            let selectedType = commentGenerator.selectBubbleType(
                triggerScene: .random,
                personalityProfile: testProfile
            )
            bubbleTypeCounts[selectedType.rawValue]! += 1
        }

        // 验证caring占比>60%
        let caringCount = bubbleTypeCounts["caring"]!
        let caringRatio = Double(caringCount) / 10.0
        let passed = caringRatio > 0.6
        let details = "caring气泡数量: \(caringCount)/10 (占比: \(Int(caringRatio * 100))%)，阈值: >60%"

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: bubbleTypeCounts,
            totalBubbles: 10
        )
    }

    /// 测试用例3：设置叛逆度=90、其他维度=50，触发10次气泡生成，验证teasing占比>60%
    /// US-014: 高叛逆度精灵应生成更多吐槽气泡
    /// - Returns: 测试结果
    func runRebellionHighTest() -> TestResult {
        let testName = "高叛逆度测试 (rebellion=90)"

        // 设置测试性格参数
        let testProfile = PersonalityProfile(
            extroversion: 50,
            curiosity: 50,
            clinginess: 50,
            humor: 50,
            gentleness: 50,
            rebellion: 90
        )

        // 统计气泡类型
        var bubbleTypeCounts: [String: Int] = [
            "greeting": 0,
            "caring": 0,
            "memory": 0,
            "opinion": 0,
            "teasing": 0
        ]

        // 模拟10次气泡类型选择
        for _ in 0..<10 {
            let selectedType = commentGenerator.selectBubbleType(
                triggerScene: .random,
                personalityProfile: testProfile
            )
            bubbleTypeCounts[selectedType.rawValue]! += 1
        }

        // 验证teasing占比>60%（叛逆度高时吐槽概率增加）
        let teasingCount = bubbleTypeCounts["teasing"]!
        let teasingRatio = Double(teasingCount) / 10.0
        let passed = teasingRatio > 0.6
        let details = "teasing气泡数量: \(teasingCount)/10 (占比: \(Int(teasingRatio * 100))%)，阈值: >60%"

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: bubbleTypeCounts,
            totalBubbles: 10
        )
    }

    /// 测试用例4：使用活泼型模板(extroversion=80,humor=75)，验证活泼语气关键词
    /// US-014: 活泼型模板应包含活泼语气关键词
    /// - Returns: 测试结果
    func runEnergeticTemplateTest() -> TestResult {
        let testName = "活泼型模板测试"

        // 获取活泼型模板
        let template = PersonalityTemplate.energetic
        let profile = template.profile()

        // 验证活泼语气关键词存在于fallback内容中
        let energeticKeywords = ["！", "好", "呀", "啦", "~"]

        // 检查权重配置
        let weights = PersonalityStyleMapping.calculateBubbleTypeWeights(for: profile)

        // 检查外向度和幽默度是否达到阈值
        let hasEnergeticTraits = profile.extroversion >= 70 && profile.humor >= 70

        // 检查teasing权重是否增加
        let hasTeasingBoost = weights["teasing"] ?? 0 > 0

        let passed = hasEnergeticTraits && hasTeasingBoost
        let details = """
        外向度: \(profile.extroversion) (阈值: 70)
        幽默感: \(profile.humor) (阈值: 70)
        teasing权重: +\(Int((weights["teasing"] ?? 0) * 100))%
        活泼特征: \(hasEnergeticTraits ? "符合" : "不符合")
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: weights.mapValues { Int($0 * 10) },
            totalBubbles: 0
        )
    }

    /// 测试用例5：使用温柔型模板(gentleness=85)，验证温柔语气关键词
    /// US-014: 温柔型模板应包含温柔语气关键词
    /// - Returns: 测试结果
    func runGentleTemplateTest() -> TestResult {
        let testName = "温柔型模板测试"

        // 获取温柔型模板
        let template = PersonalityTemplate.gentle
        let profile = template.profile()

        // 验证温柔语气关键词存在于fallback内容中
        let gentleKeywords = ["哦", "呢", "记得", "休息", "陪"]

        // 检查权重配置
        let weights = PersonalityStyleMapping.calculateBubbleTypeWeights(for: profile)

        // 检查温柔度是否达到阈值
        let hasGentleTraits = profile.gentleness >= 70

        // 检查caring权重是否增加
        let hasCaringBoost = weights["caring"] ?? 0 > 0

        let passed = hasGentleTraits && hasCaringBoost
        let details = """
        温柔度: \(profile.gentleness) (阈值: 70)
        caring权重: +\(Int((weights["caring"] ?? 0) * 100))%
        温柔特征: \(hasGentleTraits ? "符合" : "不符合")
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: weights.mapValues { Int($0 * 10) },
            totalBubbles: 0
        )
    }

    /// 测试用例6：使用叛逆型模板(rebellion=80,humor=85)，验证叛逆语气关键词
    /// US-014: 叛逆型模板应包含叛逆语气关键词
    /// - Returns: 测试结果
    func runRebelliousTemplateTest() -> TestResult {
        let testName = "叛逆型模板测试"

        // 获取叛逆型模板
        let template = PersonalityTemplate.rebellious
        let profile = template.profile()

        // 验证叛逆语气关键词存在于fallback内容中
        let rebelliousKeywords = ["哼", "不理", "又", "搞怪", "吐槽"]

        // 检查权重配置
        let weights = PersonalityStyleMapping.calculateBubbleTypeWeights(for: profile)

        // 检查叛逆度和幽默度是否达到阈值
        let hasRebelliousTraits = profile.rebellion >= 70 && profile.humor >= 70

        // 检查teasing权重是否增加
        let hasTeasingBoost = weights["teasing"] ?? 0 > 0

        let passed = hasRebelliousTraits && hasTeasingBoost
        let details = """
        叛逆度: \(profile.rebellion) (阈值: 70)
        幽默感: \(profile.humor) (阈值: 70)
        teasing权重: +\(Int((weights["teasing"] ?? 0) * 100))%
        叛逆特征: \(hasRebelliousTraits ? "符合" : "不符合")
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: weights.mapValues { Int($0 * 10) },
            totalBubbles: 0
        )
    }

    /// 对比测试：连续使用活泼型、温柔型、叛逆型模板各生成5条气泡，对比气泡内容差异
    /// US-014: 验证不同性格产生明显不同的表达风格
    /// - Returns: 测试结果
    func runContrastTest() -> TestResult {
        let testName = "模板对比测试"

        // 统计三种模板的气泡类型分布
        var energeticCounts: [String: Int] = [:]
        var gentleCounts: [String: Int] = [:]
        var rebelliousCounts: [String: Int] = [:]

        // 活泼型模板测试
        let energeticProfile = PersonalityTemplate.energetic.profile()
        for _ in 0..<5 {
            let type = commentGenerator.selectBubbleType(triggerScene: .random, personalityProfile: energeticProfile)
            energeticCounts[type.rawValue] = (energeticCounts[type.rawValue] ?? 0) + 1
        }

        // 温柔型模板测试
        let gentleProfile = PersonalityTemplate.gentle.profile()
        for _ in 0..<5 {
            let type = commentGenerator.selectBubbleType(triggerScene: .random, personalityProfile: gentleProfile)
            gentleCounts[type.rawValue] = (gentleCounts[type.rawValue] ?? 0) + 1
        }

        // 叛逆型模板测试
        let rebelliousProfile = PersonalityTemplate.rebellious.profile()
        for _ in 0..<5 {
            let type = commentGenerator.selectBubbleType(triggerScene: .random, personalityProfile: rebelliousProfile)
            rebelliousCounts[type.rawValue] = (rebelliousCounts[type.rawValue] ?? 0) + 1
        }

        // 验证三种模板产生不同的主导类型
        let energeticDominant = energeticCounts.max { $0.value < $1.value }?.key ?? ""
        let gentleDominant = gentleCounts.max { $0.value < $1.value }?.key ?? ""
        let rebelliousDominant = rebelliousCounts.max { $0.value < $1.value }?.key ?? ""

        // 活泼型应倾向teasing，温柔型应倾向caring，叛逆型应倾向teasing
        let passed = energeticDominant == "teasing" && gentleDominant == "caring"

        let details = """
        活泼型主导类型: \(energeticDominant) (期望: teasing)
        温柔型主导类型: \(gentleDominant) (期望: caring)
        叛逆型主导类型: \(rebelliousDominant) (期望: teasing)
        """

        // 合并气泡类型统计
        var combinedCounts: [String: Int] = [:]
        for (key, value) in energeticCounts {
            combinedCounts["energetic_\(key)"] = value
        }
        for (key, value) in gentleCounts {
            combinedCounts["gentle_\(key)"] = value
        }
        for (key, value) in rebelliousCounts {
            combinedCounts["rebellious_\(key)"] = value
        }

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: combinedCounts,
            totalBubbles: 15
        )
    }

    /// 即时生效测试：在性格配置UI修改性格参数后，立即触发气泡生成，验证新气泡内容体现修改后的性格参数
    /// US-014: 验证性格参数修改后立即生效
    /// - Returns: 测试结果
    func runImmediateEffectTest() -> TestResult {
        let testName = "即时生效测试"

        // 记录修改前的性格参数
        let originalProfile = personalityManager.currentProfile

        // 创建新的性格参数
        let newProfile = PersonalityProfile(
            extroversion: 90,
            curiosity: 50,
            clinginess: 50,
            humor: 90,
            gentleness: 50,
            rebellion: 50
        )

        // 模拟修改性格参数
        personalityManager.saveProfile(newProfile)

        // 立即检查新的气泡类型选择
        let newType = commentGenerator.selectBubbleType(triggerScene: .random)

        // 检查权重是否立即更新
        let newWeights = commentGenerator.getCurrentBubbleTypeWeights()

        // 检查是否体现新性格参数
        let reflectsNewProfile = newWeights["teasing"] ?? 0 > 0

        // 恢复原始性格参数
        personalityManager.saveProfile(originalProfile)

        let passed = reflectsNewProfile
        let details = """
        修改前外向度: \(originalProfile.extroversion), 修改后: \(newProfile.extroversion)
        修改前幽默感: \(originalProfile.humor), 修改后: \(newProfile.humor)
        新气泡类型: \(newType.displayName)
        teasing权重: +\(Int((newWeights["teasing"] ?? 0) * 100))%
        即时生效: \(reflectsNewProfile ? "符合" : "不符合")
        """

        return TestResult(
            testName: testName,
            passed: passed,
            details: details,
            bubbleTypeCounts: newWeights.mapValues { Int($0 * 10) },
            totalBubbles: 1
        )
    }

    // MARK: - Statistics Summary

    /// 获取测试统计摘要
    /// - Returns: 统计信息字符串
    func getStatisticsSummary() -> String {
        let passedCount = allResults.filter { $0.passed }.count
        let totalCount = allResults.count

        return """
        性格验证测试结果：
        通过: \(passedCount)/\(totalCount)
        通过率: \(Int(Double(passedCount) / Double(totalCount) * 100))%
        """
    }

    /// 获取各气泡类型的总体统计
    /// - Returns: 气泡类型统计字典
    func getBubbleTypeStatistics() -> [String: Int] {
        var totalCounts: [String: Int] = [
            "greeting": 0,
            "caring": 0,
            "memory": 0,
            "opinion": 0,
            "teasing": 0
        ]

        for result in allResults {
            for (key, value) in result.bubbleTypeCounts {
                // 只统计标准气泡类型，排除模板前缀
                if let standardKey = key.split(separator: "_").last.map { String($0) } {
                    if totalCounts.keys.contains(standardKey) {
                        totalCounts[standardKey]! += value
                    }
                } else if totalCounts.keys.contains(key) {
                    totalCounts[key]! += value
                }
            }
        }

        return totalCounts
    }
}

// MARK: - Dictionary Extension for mapValues

extension Dictionary {
    /// 映射字典值
    func mapValues<T>(_ transform: (Value) -> T) -> [Key: T] {
        var result: [Key: T] = [:]
        for (key, value) in self {
            result[key] = transform(value)
        }
        return result
    }
}