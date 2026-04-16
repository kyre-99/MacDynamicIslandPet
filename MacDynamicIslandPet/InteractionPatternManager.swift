import Foundation
import Combine

// MARK: - Bubble Feedback Enum

/// 气泡反馈类型枚举
///
/// 用于记录用户对气泡的反馈，帮助精灵调整行为
/// US-007: 互动模式记忆实现
enum BubbleFeedback: String, Codable {
    /// 忽略 - 用户没有注意到气泡（3秒内未点击）
    case ignored = "忽略"
    /// 点击 - 用户主动点击了气泡
    case clicked = "点击"
    /// 自动消失 - 气泡自然消失未点击
    case dismissed = "自动消失"
}

// MARK: - Interaction Metrics Structure

/// 互动指标结构体
///
/// 存储用户与精灵的互动统计数据
/// 用于分析互动模式并调整精灵行为
/// US-007: 互动模式记忆实现
struct InteractionMetrics: Codable {
    /// 每小时互动次数（按小时统计，key为小时数0-23）
    var hourlyInteractionCount: [Int: Int] = [:]

    /// 最佳互动时段（互动次数最多的时段列表）
    var bestInteractionTimeSlots: [String] = []

    /// 用户偏好的气泡类型（基于clickRate最高的类型）
    var preferredBubbleType: String = "gentleTease"

    /// 用户忽略气泡的比例（0.0-1.0）
    var ignoreRate: Double = 0.0

    /// 用户点击气泡的比例（0.0-1.0）
    var clickRate: Double = 0.0

    /// 用户平均响应时间（秒）
    var avgResponseTime: Double = 0.0

    /// 总气泡显示次数
    var totalBubbleCount: Int = 0

    /// 总点击次数
    var totalClickCount: Int = 0

    /// 总忽略次数
    var totalIgnoreCount: Int = 0

    /// 最后更新时间
    var lastUpdated: Date = Date()

    /// 创建默认的互动指标
    static let empty = InteractionMetrics()

    /// 计算点击率
    func calculateClickRate() -> Double {
        if totalBubbleCount == 0 { return 0.0 }
        return Double(totalClickCount) / Double(totalBubbleCount)
    }

    /// 计算忽略率
    func calculateIgnoreRate() -> Double {
        if totalBubbleCount == 0 { return 0.0 }
        return Double(totalIgnoreCount) / Double(totalBubbleCount)
    }

    /// 获取最佳互动时段描述
    func getBestTimeSlotsDescription() -> String {
        if bestInteractionTimeSlots.isEmpty {
            return "暂无最佳时段数据"
        }
        return "最佳时段：" + bestInteractionTimeSlots.joined(separator: ", ")
    }
}

// MARK: - Bubble Interaction Record

/// 气泡互动记录结构体
///
/// 记录每次气泡显示和用户反馈的详细信息
struct BubbleInteractionRecord: Codable {
    /// 记录ID
    var id: String

    /// 气泡显示时间
    var showTime: Date

    /// 气泡类型（gentleTease/caringAdvice/playfulRoast）
    var bubbleType: String

    /// 气泡内容
    var bubbleContent: String

    /// 用户反馈（ignored/clicked/dismissed）
    var feedback: BubbleFeedback

    /// 用户响应时间（秒，点击时记录点击延迟）
    var responseTime: Double

    /// 显示时段（用于时段统计）
    var timeSlot: String

    /// 创建新的气泡互动记录
    static func create(
        bubbleType: String,
        bubbleContent: String,
        feedback: BubbleFeedback,
        responseTime: Double
    ) -> BubbleInteractionRecord {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let timeSlot = getTimeSlotName(hour)

        return BubbleInteractionRecord(
            id: UUID().uuidString,
            showTime: now,
            bubbleType: bubbleType,
            bubbleContent: bubbleContent,
            feedback: feedback,
            responseTime: responseTime,
            timeSlot: timeSlot
        )
    }

    /// 根据小时数获取时段名称
    static func getTimeSlotName(_ hour: Int) -> String {
        switch hour {
        case 5..<9: return "早晨"
        case 9..<12: return "上午"
        case 12..<14: return "中午"
        case 14..<18: return "下午"
        case 18..<21: return "晚上"
        case 21..<24: return "深夜"
        default: return "凌晨"
        }
    }
}

// MARK: - Interaction Pattern Manager

/// 互动模式管理器
///
/// 分析用户与精灵的互动模式（L4长期记忆的一部分）
/// 记录互动频率、偏好、反馈模式
/// 基于互动模式调整气泡触发策略
/// US-007: 互动模式记忆实现
class InteractionPatternManager {
    /// 共享单例实例
    static let shared = InteractionPatternManager()

    /// 用户画像存储文件路径
    private var userProfilePath: URL {
        return MemoryStoragePath.userProfileFile
    }

    /// 互动历史最大记录数
    private let maxInteractionHistoryCount: Int = 200

    /// 当前显示的气泡记录（用于跟踪反馈）
    private var currentBubbleRecord: BubbleInteractionRecord?

    /// 气泡显示时间（用于计算响应时间）
    private var bubbleShowTime: Date?

    /// 日互动分析定时器
    private var dailyAnalysisTimer: Timer?

    /// 调整后的触发参数缓存
    private var adjustedTriggerProbability: Double = 0.3  // 默认30%
    private var adjustedCooldownPeriod: TimeInterval = 60.0  // 默认60秒

    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 启动每日分析定时器（每天凌晨执行）
        setupDailyAnalysisTimer()
    }

    deinit {
        dailyAnalysisTimer?.invalidate()
    }

    // MARK: - Timer Setup

    /// 设置每日分析定时器
    /// 每天凌晨00:00执行analyzePatterns()
    private func setupDailyAnalysisTimer() {
        // 计算到下一个凌晨的时间
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day! += 1  // 明天
        components.hour = 0
        components.minute = 0
        components.second = 0

        let nextMidnight = calendar.date(from: components) ?? now
        let initialDelay = nextMidnight.timeIntervalSince(now)

        // 首次在凌晨执行
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) { [weak self] in
            self?.analyzePatterns()
            // 之后每24小时执行一次
            self?.dailyAnalysisTimer = Timer.scheduledTimer(
                withTimeInterval: 86400,  // 24小时
                repeats: true
            ) { _ in
                self?.analyzePatterns()
            }
        }
    }

    // MARK: - Interaction Recording

    /// 记录气泡显示（在气泡显示时调用）
    /// - Parameters:
    ///   - bubbleType: 气泡类型
    ///   - bubbleContent: 气泡内容
    func recordBubbleShow(bubbleType: String, bubbleContent: String) {
        // 创建显示记录（暂时标记为dismissed，后续根据用户行为更新）
        currentBubbleRecord = BubbleInteractionRecord.create(
            bubbleType: bubbleType,
            bubbleContent: bubbleContent,
            feedback: .dismissed,
            responseTime: 8.0  // 默认显示时长
        )
        bubbleShowTime = Date()

        print("📊 InteractionPatternManager: Bubble shown - type: \(bubbleType)")
    }

    /// 记录气泡点击反馈（用户点击气泡时调用）
    func recordBubbleClick() {
        guard let showTime = bubbleShowTime else { return }

        // 计算响应时间
        let responseTime = Date().timeIntervalSince(showTime)

        // 更新当前记录为clicked
        if var record = currentBubbleRecord {
            record.feedback = .clicked
            record.responseTime = responseTime

            // 保存记录
            saveInteractionRecord(record)

            print("📊 InteractionPatternManager: Bubble clicked - responseTime: \(responseTime)s")
        }

        // 清除当前记录
        currentBubbleRecord = nil
        bubbleShowTime = nil
    }

    /// 记录气泡忽略反馈（用户3秒内未点击）
    func recordBubbleIgnore() {
        guard let showTime = bubbleShowTime else { return }

        // 计算3秒内的忽略
        let elapsed = Date().timeIntervalSince(showTime)
        if elapsed < 3.0 {
            // 更新当前记录为ignored
            if var record = currentBubbleRecord {
                record.feedback = .ignored
                record.responseTime = elapsed

                // 保存记录
                saveInteractionRecord(record)

                print("📊 InteractionPatternManager: Bubble ignored within 3s")
            }

            // 清除当前记录
            currentBubbleRecord = nil
            bubbleShowTime = nil
        }
    }

    /// 记录气泡自动消失（气泡正常消失未点击）
    func recordBubbleDismiss() {
        // 如果还未记录点击或忽略，则记录为自动消失
        if var record = currentBubbleRecord {
            record.feedback = .dismissed
            record.responseTime = 8.0  // 默认显示时长

            // 保存记录
            saveInteractionRecord(record)

            print("📊 InteractionPatternManager: Bubble dismissed normally")
        }

        // 清除当前记录
        currentBubbleRecord = nil
        bubbleShowTime = nil
    }

    /// 保存互动记录到历史
    private func saveInteractionRecord(_ record: BubbleInteractionRecord) {
        // 加载现有互动历史
        var history = loadInteractionHistory()

        // 添加新记录
        history.append(record)

        // 保留最近200条
        if history.count > maxInteractionHistoryCount {
            history = history.suffix(maxInteractionHistoryCount)
        }

        // 保存到user-profile.json
        saveInteractionHistory(history)
    }

    // MARK: - Interaction History Management

    /// 加载互动历史
    /// - Returns: 互动记录数组
    func loadInteractionHistory() -> [BubbleInteractionRecord] {
        guard FileManager.default.fileExists(atPath: userProfilePath.path) else {
            return []
        }

        do {
            let data = FileManager.default.contents(atPath: userProfilePath.path)
            if let data = data {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let historyArray = json?["interactionHistory"] as? [[String: Any]] {
                    return parseInteractionHistory(historyArray)
                }
            }
        } catch {
            print("⚠️ InteractionPatternManager: Failed to load interaction history - \(error.localizedDescription)")
        }

        return []
    }

    /// 解析互动历史数组
    private func parseInteractionHistory(_ array: [[String: Any]]) -> [BubbleInteractionRecord] {
        var history: [BubbleInteractionRecord] = []

        for dict in array {
            guard let bubbleType = dict["bubbleType"] as? String,
                  let bubbleContent = dict["bubbleContent"] as? String,
                  let feedbackRaw = dict["feedback"] as? String,
                  let feedback = BubbleFeedback(rawValue: feedbackRaw),
                  let responseTime = dict["responseTime"] as? Double,
                  let timeSlot = dict["timeSlot"] as? String else {
                continue
            }

            // 解析时间戳
            let showTime: Date
            if let showTimeStr = dict["showTime"] as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                showTime = dateFormatter.date(from: showTimeStr) ?? Date()
            } else {
                showTime = Date()
            }

            let id = dict["id"] as? String ?? UUID().uuidString

            history.append(BubbleInteractionRecord(
                id: id,
                showTime: showTime,
                bubbleType: bubbleType,
                bubbleContent: bubbleContent,
                feedback: feedback,
                responseTime: responseTime,
                timeSlot: timeSlot
            ))
        }

        return history
    }

    /// 保存互动历史到user-profile.json
    private func saveInteractionHistory(_ history: [BubbleInteractionRecord]) {
        MemoryStoragePath.ensureAllDirectoriesExist()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let historyArray = history.map { record -> [String: Any] in
            return [
                "id": record.id,
                "showTime": dateFormatter.string(from: record.showTime),
                "bubbleType": record.bubbleType,
                "bubbleContent": record.bubbleContent,
                "feedback": record.feedback.rawValue,
                "responseTime": record.responseTime,
                "timeSlot": record.timeSlot
            ]
        }

        // 加载现有user-profile.json
        var existingProfile: [String: Any] = [:]

        if FileManager.default.fileExists(atPath: userProfilePath.path) {
            do {
                let data = FileManager.default.contents(atPath: userProfilePath.path)
                if let data = data {
                    existingProfile = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                }
            } catch {
                print("⚠️ InteractionPatternManager: Failed to load existing profile - \(error.localizedDescription)")
            }
        }

        // 更新interactionHistory字段
        existingProfile["interactionHistory"] = historyArray

        // 保存到文件
        do {
            let data = try JSONSerialization.data(withJSONObject: existingProfile, options: [.prettyPrinted])
            try data.write(to: userProfilePath)
        } catch {
            print("⚠️ InteractionPatternManager: Failed to save interaction history - \(error.localizedDescription)")
        }
    }

    // MARK: - Pattern Analysis

    /// 分析互动模式
    /// 每天凌晨自动调用
    /// - Returns: 更新后的互动指标
    func analyzePatterns() -> InteractionMetrics {
        let history = loadInteractionHistory()

        guard history.count >= 5 else {
            print("📊 InteractionPatternManager: Not enough history for pattern analysis (need at least 5 records)")
            return InteractionMetrics.empty
        }

        var metrics = InteractionMetrics()

        // 分析每小时互动次数
        metrics.hourlyInteractionCount = analyzeHourlyCount(history)

        // 分析最佳互动时段
        metrics.bestInteractionTimeSlots = analyzeBestTimeSlots(history)

        // 分析偏好气泡类型
        metrics.preferredBubbleType = analyzePreferredBubbleType(history)

        // 计算点击率和忽略率
        metrics.totalBubbleCount = history.count
        metrics.totalClickCount = history.filter { $0.feedback == .clicked }.count
        metrics.totalIgnoreCount = history.filter { $0.feedback == .ignored }.count
        metrics.clickRate = metrics.calculateClickRate()
        metrics.ignoreRate = metrics.calculateIgnoreRate()

        // 计算平均响应时间（仅对点击的记录）
        let clickedRecords = history.filter { $0.feedback == .clicked }
        if clickedRecords.isEmpty {
            metrics.avgResponseTime = 0.0
        } else {
            metrics.avgResponseTime = clickedRecords.reduce(0.0) { $0 + $1.responseTime } / Double(clickedRecords.count)
        }

        metrics.lastUpdated = Date()

        // 保存互动指标
        saveInteractionPatterns(metrics)

        // 调整触发策略
        adjustTriggerStrategy(metrics)

        print("📊 InteractionPatternManager: Analyzed patterns - clickRate=\(metrics.clickRate), ignoreRate=\(metrics.ignoreRate), bestSlots=\(metrics.bestInteractionTimeSlots)")

        return metrics
    }

    /// 分析每小时互动次数
    private func analyzeHourlyCount(_ history: [BubbleInteractionRecord]) -> [Int: Int] {
        var hourlyCount: [Int: Int] = [:]

        for record in history {
            let hour = Calendar.current.component(.hour, from: record.showTime)
            hourlyCount[hour] = (hourlyCount[hour] ?? 0) + 1
        }

        return hourlyCount
    }

    /// 分析最佳互动时段
    /// 返回互动次数最多的时段（前3个）
    private func analyzeBestTimeSlots(_ history: [BubbleInteractionRecord]) -> [String] {
        var slotCount: [String: Int] = [:]

        for record in history {
            slotCount[record.timeSlot] = (slotCount[record.timeSlot] ?? 0) + 1
        }

        // 排序取前3个时段
        let sortedSlots = slotCount.sorted { $0.value > $1.value }
        return sortedSlots.prefix(3).map { $0.key }
    }

    /// 分析偏好气泡类型
    /// 返回点击率最高的气泡类型
    private func analyzePreferredBubbleType(_ history: [BubbleInteractionRecord]) -> String {
        var typeClickCount: [String: Int] = [:]
        var typeTotalCount: [String: Int] = [:]

        for record in history {
            typeTotalCount[record.bubbleType] = (typeTotalCount[record.bubbleType] ?? 0) + 1
            if record.feedback == .clicked {
                typeClickCount[record.bubbleType] = (typeClickCount[record.bubbleType] ?? 0) + 1
            }
        }

        // 计算各类型的点击率
        var bestType = "gentleTease"
        var bestRate: Double = 0.0

        for type in typeTotalCount.keys {
            let total = typeTotalCount[type] ?? 0
            let clicks = typeClickCount[type] ?? 0
            let rate = Double(clicks) / Double(total)

            if rate > bestRate {
                bestRate = rate
                bestType = type
            }
        }

        return bestType
    }

    /// 保存互动模式到user-profile.json
    private func saveInteractionPatterns(_ metrics: InteractionMetrics) {
        MemoryStoragePath.ensureAllDirectoriesExist()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let patternsDict: [String: Any] = [
            "hourlyInteractionCount": metrics.hourlyInteractionCount.mapKeys { String($0) },
            "bestInteractionTimeSlots": metrics.bestInteractionTimeSlots,
            "preferredBubbleType": metrics.preferredBubbleType,
            "ignoreRate": metrics.ignoreRate,
            "clickRate": metrics.clickRate,
            "avgResponseTime": metrics.avgResponseTime,
            "totalBubbleCount": metrics.totalBubbleCount,
            "totalClickCount": metrics.totalClickCount,
            "totalIgnoreCount": metrics.totalIgnoreCount,
            "lastUpdated": dateFormatter.string(from: metrics.lastUpdated)
        ]

        // 加载现有user-profile.json
        var existingProfile: [String: Any] = [:]

        if FileManager.default.fileExists(atPath: userProfilePath.path) {
            do {
                let data = FileManager.default.contents(atPath: userProfilePath.path)
                if let data = data {
                    existingProfile = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                }
            } catch {
                print("⚠️ InteractionPatternManager: Failed to load existing profile - \(error.localizedDescription)")
            }
        }

        // 更新interactionPatterns字段
        existingProfile["interactionPatterns"] = patternsDict

        // 保存到文件
        do {
            let data = try JSONSerialization.data(withJSONObject: existingProfile, options: [.prettyPrinted])
            try data.write(to: userProfilePath)
        } catch {
            print("⚠️ InteractionPatternManager: Failed to save interaction patterns - \(error.localizedDescription)")
        }
    }

    // MARK: - Trigger Strategy Adjustment

    /// 调整触发策略
    /// 根据互动模式调整气泡触发参数
    /// - Parameter metrics: 互动指标数据
    func adjustTriggerStrategy(_ metrics: InteractionMetrics) {
        // 1. 忽略率高时降低触发频率
        if metrics.ignoreRate > 0.7 {
            adjustedTriggerProbability = 0.21  // 降低30% (从30%降到21%)
            adjustedCooldownPeriod = 78.0  // 增加30% (从60秒增加到78秒)
            print("📊 InteractionPatternManager: High ignore rate - reducing trigger frequency by 30%")
        }
        // 2. 点击率高时增加触发频率
        else if metrics.clickRate > 0.5 {
            adjustedTriggerProbability = 0.36  // 增加20% (从30%增加到36%)
            adjustedCooldownPeriod = 48.0  // 减少20% (从60秒减少到48秒)
            print("📊 InteractionPatternManager: High click rate - increasing trigger frequency by 20%")
        }
        // 3. 正常情况保持默认
        else {
            adjustedTriggerProbability = 0.3
            adjustedCooldownPeriod = 60.0
        }

        // 通知SelfTalkManager更新参数
        SelfTalkManager.shared.updateTriggerParameters(
            probability: adjustedTriggerProbability,
            cooldown: adjustedCooldownPeriod
        )
    }

    // MARK: - Public Access Methods

    /// 获取当前互动指标
    /// - Returns: 互动指标数据
    func getInteractionPatterns() -> InteractionMetrics {
        return loadInteractionPatterns()
    }

    /// 加载互动模式
    private func loadInteractionPatterns() -> InteractionMetrics {
        guard FileManager.default.fileExists(atPath: userProfilePath.path) else {
            return InteractionMetrics.empty
        }

        do {
            let data = FileManager.default.contents(atPath: userProfilePath.path)
            if let data = data {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let patternsDict = json?["interactionPatterns"] as? [String: Any] {
                    return parseInteractionPatterns(patternsDict)
                }
            }
        } catch {
            print("⚠️ InteractionPatternManager: Failed to load interaction patterns - \(error.localizedDescription)")
        }

        return InteractionMetrics.empty
    }

    /// 解析互动模式字典
    private func parseInteractionPatterns(_ dict: [String: Any]) -> InteractionMetrics {
        var metrics = InteractionMetrics()

        if let hourlyCount = dict["hourlyInteractionCount"] as? [String: Int] {
            // 将String key转回Int
            metrics.hourlyInteractionCount = hourlyCount.compactMapKeys { Int($0) }
        }

        if let bestSlots = dict["bestInteractionTimeSlots"] as? [String] {
            metrics.bestInteractionTimeSlots = bestSlots
        }

        if let preferredType = dict["preferredBubbleType"] as? String {
            metrics.preferredBubbleType = preferredType
        }

        if let ignoreRate = dict["ignoreRate"] as? Double {
            metrics.ignoreRate = ignoreRate
        }

        if let clickRate = dict["clickRate"] as? Double {
            metrics.clickRate = clickRate
        }

        if let avgResponseTime = dict["avgResponseTime"] as? Double {
            metrics.avgResponseTime = avgResponseTime
        }

        if let totalBubbleCount = dict["totalBubbleCount"] as? Int {
            metrics.totalBubbleCount = totalBubbleCount
        }

        if let totalClickCount = dict["totalClickCount"] as? Int {
            metrics.totalClickCount = totalClickCount
        }

        if let totalIgnoreCount = dict["totalIgnoreCount"] as? Int {
            metrics.totalIgnoreCount = totalIgnoreCount
        }

        if let lastUpdatedStr = dict["lastUpdated"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            metrics.lastUpdated = dateFormatter.date(from: lastUpdatedStr) ?? Date()
        }

        return metrics
    }

    /// 获取调整后的触发概率
    /// - Returns: 当前触发概率
    func getAdjustedTriggerProbability() -> Double {
        return adjustedTriggerProbability
    }

    /// 获取调整后的冷却时间
    /// - Returns: 当前冷却时间
    func getAdjustedCooldownPeriod() -> TimeInterval {
        return adjustedCooldownPeriod
    }

    /// 检查当前时段是否是最佳互动时段
    /// - Returns: 是否是最佳时段
    func isBestInteractionTime() -> Bool {
        let metrics = getInteractionPatterns()
        let hour = Calendar.current.component(.hour, from: Date())
        let currentSlot = BubbleInteractionRecord.getTimeSlotName(hour)

        return metrics.bestInteractionTimeSlots.contains(currentSlot)
    }

    /// 获取推荐的气泡类型（基于用户偏好）
    /// - Returns: 推荐的气泡类型
    func getRecommendedBubbleType() -> String {
        let metrics = getInteractionPatterns()
        return metrics.preferredBubbleType
    }
}

// MARK: - Dictionary Helper Extensions

extension Dictionary {
    /// 将Dictionary的keys进行转换
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }

    /// 将Dictionary的keys进行转换，过滤掉nil结果
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}