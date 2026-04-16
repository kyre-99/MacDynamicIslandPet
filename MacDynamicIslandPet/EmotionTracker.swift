import Foundation
import Combine

// MARK: - User Emotion State Enum

/// 用户情感状态枚举
///
/// 用于追踪用户的情感变化轨迹，从对话内容、屏幕活动和时间上下文推断
/// 每种情感状态有对应的关键词匹配规则和触发条件
/// US-006: 情感状态追踪记忆实现
enum UserEmotionState: String, Codable, CaseIterable {
    /// 忙碌 - 高强度工作状态
    case busy = "忙碌"
    /// 放松 - 轻松休闲状态
    case relaxed = "放松"
    /// 焦虑 - 紧张担忧状态
    case anxious = "焦虑"
    /// 专注 - 高度集中状态
    case focused = "专注"
    /// 开心 - 积极正面状态
    case happy = "开心"
    /// 沮丧 - 低落负面状态
    case sad = "沮丧"
    /// 兴奋 - 高能量正面状态
    case excited = "兴奋"
    /// 疲惫 - 精力不足状态
    case tired = "疲惫"
    /// 压力 - 心理压力状态
    case stressed = "压力"
    /// 中性 - 平稳无波动状态
    case neutral = "中性"

    /// 获取情感状态的描述说明
    var description: String {
        switch self {
        case .busy:
            return "忙碌 - 高强度工作状态，快速切换任务或长时间专注工作"
        case .relaxed:
            return "放松 - 轻松休闲状态，浏览娱乐内容或休息时间"
        case .anxious:
            return "焦虑 - 紧张担忧状态，频繁切换应用或表现出紧张情绪"
        case .focused:
            return "专注 - 高度集中状态，长时间在同一应用工作"
        case .happy:
            return "开心 - 积极正面状态，表达喜悦满足的情绪"
        case .sad:
            return "沮丧 - 低落负面状态，表达失落难过的情绪"
        case .excited:
            return "兴奋 - 高能量正面状态，表达期待激动的情绪"
        case .tired:
            return "疲惫 - 精力不足状态，深夜时段或长时间使用后"
        case .stressed:
            return "压力 - 心理压力状态，表达紧张焦虑的情绪"
        case .neutral:
            return "中性 - 平稳无波动状态，无明显情感倾向"
        }
    }

    /// 获取对话关键词匹配列表（用于从对话内容推断情感）
    var conversationKeywords: [String] {
        switch self {
        case .busy:
            return ["忙", "没空", "来不及", "赶", "加班", "好多事", "来不及了"]
        case .relaxed:
            return ["放松", "休息", "不用忙", "轻松", "没事", "悠闲", "舒服"]
        case .anxious:
            return ["焦虑", "紧张", "担心", "害怕", "着急", "不安", "恐慌", "压力大"]
        case .focused:
            return ["专注", "集中", "思考", "研究", "深入", "认真", "投入"]
        case .happy:
            return ["开心", "高兴", "快乐", "幸福", "喜悦", "棒", "好", "太好了", "哈哈", "笑死"]
        case .sad:
            return ["难过", "伤心", "沮丧", "失望", "郁闷", "不开心", "哭", "泪", "悲伤"]
        case .excited:
            return ["兴奋", "激动", "期待", "太棒了", "迫不及待", "超级", "终于", "哇", "厉害"]
        case .tired:
            return ["累", "疲惫", "困", "没精神", "想睡", "好累", "撑不住了", "熬不动了"]
        case .stressed:
            return ["压力大", "压力", "烦躁", "崩溃", "受不了", "太烦", "好多压力", "快疯了"]
        case .neutral:
            return []  // 中性状态无关键词匹配，作为默认fallback
        }
    }

    /// 获取情感状态的图标（用于UI显示）
    var icon: String {
        switch self {
        case .busy: return "🏃"
        case .relaxed: return "😌"
        case .anxious: return "😰"
        case .focused: return "🎯"
        case .happy: return "😊"
        case .sad: return "😢"
        case .excited: return "🎉"
        case .tired: return "😴"
        case .stressed: return "😣"
        case .neutral: return "😐"
        }
    }

    /// 获取气泡内容建议（用于CommentGenerator生成关心类气泡）
    var caringBubbleSuggestions: [String] {
        switch self {
        case .busy:
            return ["忙完了记得休息哦~", "好多事情要做，辛苦啦~", "加油，慢慢来~"]
        case .relaxed:
            return ["难得放松，享受一下~", "休息时间真好~", "心情不错呢~"]
        case .anxious:
            return ["别担心，会好的~", "要不要放松一下？", "深呼吸，慢慢来~", "最近好像压力很大，要不要休息一下？"]
        case .focused:
            return ["专注模式开启~", "很认真呢，加油~", "专注力max~"]
        case .happy:
            return ["心情真好~", "开心就好~", "今天状态不错~"]
        case .sad:
            return ["不开心吗？想聊聊吗？", "别难过啦~", "我陪着你呢~"]
        case .excited:
            return ["好兴奋呀~", "期待期待~", "开心就好~"]
        case .tired:
            return ["累了就休息吧~", "别撑了，睡一会？", "注意休息哦~"]
        case .stressed:
            return ["压力太大了，歇歇吧~", "别太勉强自己~", "放轻松~"]
        case .neutral:
            return ["今天怎么样？", "有什么想聊的？", "陪伴着你呢~"]
        }
    }
}

// MARK: - Emotion Change Structure

/// 情感变化记录结构体
///
/// 记录每次情感状态变化的详细信息
/// 包含时间戳、情感类型、触发来源和置信度
/// US-006: 情感历史存储格式
struct EmotionChange: Codable {
    /// 变化发生时间
    var timestamp: Date

    /// 情感状态类型
    var emotion: UserEmotionState

    /// 触发来源（conversation/screenActivity/timeContext）
    var triggerSource: String

    /// 置信度（0.0-1.0），表示推断的可信程度
    var confidence: Double

    /// 创建新的情感变化记录
    /// - Parameters:
    ///   - emotion: 情感状态
    ///   - triggerSource: 触发来源
    ///   - confidence: 置信度
    /// - Returns: 情感变化记录实例
    static func create(
        emotion: UserEmotionState,
        triggerSource: String,
        confidence: Double
    ) -> EmotionChange {
        return EmotionChange(
            timestamp: Date(),
            emotion: emotion,
            triggerSource: triggerSource,
            confidence: max(0.0, min(1.0, confidence))
        )
    }
}

// MARK: - Emotion Patterns Structure

/// 情感周期模式结构体
///
/// 存储从情感历史分析出的周期规律
/// 包含每周模式、每日模式和频率分布
/// US-006: 情感周期模式分析结果
struct EmotionPatterns: Codable {
    /// 每周各天的主导情感（周一到周日）
    var weeklyPattern: [String: String] = [:]  // key: "周一"/"周二"... value: emotion.rawValue

    /// 各时间段的主导情感
    var dailyPattern: [String: String] = [:]  // key: "早晨"/"上午"... value: emotion.rawValue

    /// 各情感状态出现频率（百分比）
    var emotionFrequency: [String: Double] = [:]  // key: emotion.rawValue, value: frequency

    /// 最后更新时间
    var lastUpdated: Date = Date()

    /// 创建空的情感模式
    static let empty = EmotionPatterns()

    /// 获取每周模式描述
    func getWeeklyPatternDescription() -> String {
        if weeklyPattern.isEmpty {
            return "暂无每周模式数据"
        }

        var desc = ""
        let daysOrder = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        for day in daysOrder {
            if let emotion = weeklyPattern[day] {
                desc += "\(day): \(emotion)\n"
            }
        }
        return desc
    }

    /// 获取每日模式描述
    func getDailyPatternDescription() -> String {
        if dailyPattern.isEmpty {
            return "暂无每日模式数据"
        }

        var desc = ""
        let periodsOrder = ["早晨", "上午", "中午", "下午", "傍晚", "晚上", "深夜"]
        for period in periodsOrder {
            if let emotion = dailyPattern[period] {
                desc += "\(period): \(emotion)\n"
            }
        }
        return desc
    }

    /// 获取频率分布描述
    func getFrequencyDescription() -> String {
        if emotionFrequency.isEmpty {
            return "暂无频率数据"
        }

        var desc = ""
        for emotion in UserEmotionState.allCases {
            if let freq = emotionFrequency[emotion.rawValue] {
                desc += "\(emotion.rawValue): \(Int(freq * 100))%\n"
            }
        }
        return desc
    }
}

// MARK: - Emotion Tracker Manager

/// 情感状态追踪管理器
///
/// 追踪用户情感变化轨迹（L4长期记忆的一部分）
/// 从对话内容、屏幕活动和时间上下文推断情感状态
/// 记录情感历史并分析周期模式
/// US-006: 情感状态追踪记忆实现
class EmotionTracker {
    /// 共享单例实例
    static let shared = EmotionTracker()

    /// 用户画像存储文件路径
    private var userProfilePath: URL {
        return MemoryStoragePath.userProfileFile
    }

    /// 情感历史最大记录数
    private let maxEmotionHistoryCount: Int = 100

    /// 窗口观察器引用（用于屏幕活动推断）
    private let windowObserver = WindowObserver.shared

    /// 时间上下文引用（用于时间上下文推断）
    private let timeContext = TimeContext.shared

    /// 当前情感状态缓存
    private var currentEmotionCache: UserEmotionState = .neutral
    private var currentEmotionCacheTime: Date = Date()

    /// 缓存有效期（5分钟）
    private let cacheValidityDuration: TimeInterval = 300

    /// Combine订阅
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 监听窗口变化，用于情感推断
        setupWindowObserverSubscription()
    }

    // MARK: - Setup

    /// 设置窗口观察器订阅
    private func setupWindowObserverSubscription() {
        // 监听应用切换，推断情感状态
        windowObserver.$currentActiveApp
            .sink { [weak self] appName in
                self?.inferEmotionFromScreenActivity()
            }
            .store(in: &cancellables)
    }

    // MARK: - Emotion Inference Mechanisms

    /// 从对话内容推断情感状态
    /// - Parameter content: 对话内容字符串
    /// - Returns: 推断的情感状态和置信度
    func inferEmotionFromConversation(content: String) -> (emotion: UserEmotionState, confidence: Double) {
        // 检查每种情感的关键词匹配
        var matchedEmotions: [(emotion: UserEmotionState, matchCount: Int)] = []

        for emotion in UserEmotionState.allCases {
            var matchCount = 0
            for keyword in emotion.conversationKeywords {
                if content.contains(keyword) {
                    matchCount += 1
                }
            }
            if matchCount > 0 {
                matchedEmotions.append((emotion: emotion, matchCount: matchCount))
            }
        }

        // 按匹配数量排序，取最高匹配
        matchedEmotions.sort { $0.matchCount > $1.matchCount }

        if let topMatch = matchedEmotions.first {
            // 置信度基于匹配数量（1-3关键词匹配→0.6置信度，4+→0.85）
            let confidence = topMatch.matchCount >= 4 ? 0.85 : 0.6
            return (emotion: topMatch.emotion, confidence: confidence)
        }

        // 无匹配时返回中性状态
        return (emotion: .neutral, confidence: 0.3)
    }

    /// 从屏幕活动推断情感状态
    /// 使用WindowObserver检测用户在特定应用停留时间和切换频率
    /// - Returns: 推断的情感状态和置信度
    func inferEmotionFromScreenActivity() -> (emotion: UserEmotionState, confidence: Double) {
        let appName = windowObserver.currentActiveApp
        let duration = windowObserver.activeAppDuration
        let appCategory = windowObserver.getAppCategory(appName)

        // 长时间工作应用→busy/focused
        if duration > 3600 {  // 超过1小时
            if appCategory == .development || appCategory == .productivity {
                return (emotion: .focused, confidence: 0.7)
            }
        }

        // 频繁切换应用→anxious
        if windowObserver.isFrequentSwitching(threshold: 5, withinMinutes: 10) {
            return (emotion: .anxious, confidence: 0.65)
        }

        // 深夜刷娱乐应用→relaxed
        if timeContext.currentPeriod == .lateNight || timeContext.currentPeriod == .night {
            if appCategory == .entertainment || appCategory == .browser {
                return (emotion: .relaxed, confidence: 0.55)
            }
        }

        // 长时间使用后→tired
        if duration > 7200 {  // 超过2小时
            return (emotion: .tired, confidence: 0.6)
        }

        // 工作应用短时间→busy
        if appCategory == .development || appCategory == .productivity {
            if duration < 300 && !windowObserver.isFrequentSwitching() {
                return (emotion: .busy, confidence: 0.5)
            }
        }

        // 默认中性
        return (emotion: .neutral, confidence: 0.3)
    }

    /// 从时间上下文推断情感状态
    /// 使用TimeContext检测周一早晨、周五下午、深夜等时段
    /// - Returns: 推断的情感状态和置信度
    func inferEmotionFromTimeContext() -> (emotion: UserEmotionState, confidence: Double) {
        let hour = timeContext.currentHour
        let weekday = Calendar.current.component(.weekday, from: Date())

        // 周一早晨→anxious（周一焦虑）
        if weekday == 2 && hour >= 7 && hour <= 10 {
            return (emotion: .anxious, confidence: 0.55)
        }

        // 周五下午→happy（周五放松期待周末）
        if weekday == 6 && hour >= 14 && hour <= 18 {
            return (emotion: .happy, confidence: 0.55)
        }

        // 深夜→tired
        if timeContext.currentPeriod == .lateNight {
            return (emotion: .tired, confidence: 0.6)
        }

        // 早晨→focused（早晨精力充沛）
        if timeContext.currentPeriod == .morning {
            return (emotion: .focused, confidence: 0.45)
        }

        // 傍晚→relaxed（下班放松）
        if timeContext.currentPeriod == .evening {
            return (emotion: .relaxed, confidence: 0.5)
        }

        // 默认中性
        return (emotion: .neutral, confidence: 0.3)
    }

    /// 综合推断当前情感状态
    /// 结合对话、屏幕活动、时间上下文三源推断
    /// - Parameter conversationContent: 可选的对话内容（如果有）
    /// - Returns: 推断的情感状态和置信度
    func inferCurrentEmotion(conversationContent: String? = nil) -> (emotion: UserEmotionState, confidence: Double) {
        var inferences: [(emotion: UserEmotionState, confidence: Double)] = []

        // 1. 对话内容推断（权重最高）
        if let content = conversationContent, !content.isEmpty {
            let conversationInference = inferEmotionFromConversation(content: content)
            inferences.append(conversationInference)
        }

        // 2. 屏幕活动推断
        let screenInference = inferEmotionFromScreenActivity()
        inferences.append(screenInference)

        // 3. 时间上下文推断
        let timeInference = inferEmotionFromTimeContext()
        inferences.append(timeInference)

        // 选择置信度最高的推断
        inferences.sort { $0.confidence > $1.confidence }

        if let topInference = inferences.first {
            return topInference
        }

        return (emotion: .neutral, confidence: 0.3)
    }

    // MARK: - Get Current Emotion

    /// 获取当前情感状态（使用缓存机制）
    /// - Parameter conversationContent: 可选的对话内容
    /// - Returns: 当前情感状态
    func getCurrentEmotion(conversationContent: String? = nil) -> UserEmotionState {
        // 检查缓存是否有效
        let now = Date()
        if now.timeIntervalSince(currentEmotionCacheTime) < cacheValidityDuration && conversationContent == nil {
            return currentEmotionCache
        }

        // 重新推断
        let inference = inferCurrentEmotion(conversationContent: conversationContent)

        // 更新缓存
        currentEmotionCache = inference.emotion
        currentEmotionCacheTime = now

        // 记录情感变化
        recordEmotionChange(
            emotion: inference.emotion,
            triggerSource: conversationContent != nil ? "conversation" : "screenActivity/timeContext",
            confidence: inference.confidence
        )

        return inference.emotion
    }

    /// 获取情感模式分析结果
    /// - Returns: 情感周期模式数据
    func getEmotionPatterns() -> EmotionPatterns {
        return loadEmotionPatterns()
    }

    // MARK: - Emotion History Management

    /// 记录情感变化
    /// - Parameters:
    ///   - emotion: 情感状态
    ///   - triggerSource: 触发来源
    ///   - confidence: 置信度
    func recordEmotionChange(emotion: UserEmotionState, triggerSource: String, confidence: Double) {
        // 创建情感变化记录
        let change = EmotionChange.create(
            emotion: emotion,
            triggerSource: triggerSource,
            confidence: confidence
        )

        // 加载现有情感历史
        var emotionHistory = loadEmotionHistory()

        // 添加新记录
        emotionHistory.append(change)

        // 保留最近100条
        if emotionHistory.count > maxEmotionHistoryCount {
            emotionHistory = emotionHistory.suffix(maxEmotionHistoryCount)
        }

        // 保存到user-profile.json
        saveEmotionHistory(emotionHistory)

        print("💭 EmotionTracker: Recorded emotion change - \(emotion.rawValue) (source: \(triggerSource), confidence: \(confidence))")
    }

    /// 加载情感历史
    /// - Returns: 情感变化记录数组
    func loadEmotionHistory() -> [EmotionChange] {
        guard FileManager.default.fileExists(atPath: userProfilePath.path) else {
            return []
        }

        do {
            let data = FileManager.default.contents(atPath: userProfilePath.path)
            if let data = data {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let historyArray = json?["emotionHistory"] as? [[String: Any]] {
                    return parseEmotionHistory(historyArray)
                }
            }
        } catch {
            print("⚠️ EmotionTracker: Failed to load emotion history - \(error.localizedDescription)")
        }

        return []
    }

    /// 解析情感历史数组
    /// - Parameter array: 情感历史字典数组
    /// - Returns: 解析后的情感变化记录数组
    private func parseEmotionHistory(_ array: [[String: Any]]) -> [EmotionChange] {
        var history: [EmotionChange] = []

        for dict in array {
            guard let emotionRaw = dict["emotion"] as? String,
                  let emotion = UserEmotionState(rawValue: emotionRaw),
                  let triggerSource = dict["triggerSource"] as? String,
                  let confidence = dict["confidence"] as? Double else {
                continue
            }

            // 解析时间戳
            let timestamp: Date
            if let timestampStr = dict["timestamp"] as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                timestamp = dateFormatter.date(from: timestampStr) ?? Date()
            } else {
                timestamp = Date()
            }

            history.append(EmotionChange(
                timestamp: timestamp,
                emotion: emotion,
                triggerSource: triggerSource,
                confidence: confidence
            ))
        }

        return history
    }

    /// 保存情感历史到user-profile.json
    /// - Parameter history: 情感变化记录数组
    private func saveEmotionHistory(_ history: [EmotionChange]) {
        // 确保目录存在
        MemoryStoragePath.ensureAllDirectoriesExist()

        // 构建情感历史数组
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let historyArray = history.map { change -> [String: Any] in
            return [
                "timestamp": dateFormatter.string(from: change.timestamp),
                "emotion": change.emotion.rawValue,
                "triggerSource": change.triggerSource,
                "confidence": change.confidence
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
                print("⚠️ EmotionTracker: Failed to load existing profile - \(error.localizedDescription)")
            }
        }

        // 更新emotionHistory字段
        existingProfile["emotionHistory"] = historyArray

        // 保存到文件
        do {
            let data = try JSONSerialization.data(withJSONObject: existingProfile, options: [.prettyPrinted])
            try data.write(to: userProfilePath)
        } catch {
            print("⚠️ EmotionTracker: Failed to save emotion history - \(error.localizedDescription)")
        }
    }

    // MARK: - Emotion Pattern Analysis

    /// 分析情感周期模式
    /// 从emotionHistory数据识别周期规律：weeklyPattern、dailyPattern、emotionFrequency
    /// - Returns: 情感模式分析结果
    func analyzeEmotionPatterns() -> EmotionPatterns {
        let history = loadEmotionHistory()

        guard history.count >= 10 else {
            print("💭 EmotionTracker: Not enough history for pattern analysis (need at least 10 records)")
            return EmotionPatterns.empty
        }

        var patterns = EmotionPatterns()

        // 分析每周模式（周一焦虑、周五放松）
        patterns.weeklyPattern = analyzeWeeklyPattern(history)

        // 分析每日模式（早晨focused、晚上relaxed）
        patterns.dailyPattern = analyzeDailyPattern(history)

        // 分析情感频率分布
        patterns.emotionFrequency = analyzeEmotionFrequency(history)

        patterns.lastUpdated = Date()

        // 保存情感模式
        saveEmotionPatterns(patterns)

        print("💭 EmotionTracker: Analyzed emotion patterns - weeklyPattern=\(patterns.weeklyPattern.count), dailyPattern=\(patterns.dailyPattern.count), frequency=\(patterns.emotionFrequency.count)")

        return patterns
    }

    /// 分析每周情感模式
    /// - Parameter history: 情感历史
    /// - Returns: 每周各天的主导情感
    private func analyzeWeeklyPattern(_ history: [EmotionChange]) -> [String: String] {
        var weekdayEmotions: [String: [UserEmotionState]] = [:]
        let days = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

        let calendar = Calendar.current
        for change in history {
            let weekday = calendar.component(.weekday, from: change.timestamp)
            let dayName = days[weekday - 1]  // weekday: 1=周日, 2=周一...

            if weekdayEmotions[dayName] == nil {
                weekdayEmotions[dayName] = []
            }
            weekdayEmotions[dayName]?.append(change.emotion)
        }

        // 找出每天的主导情感（出现次数最多的）
        var weeklyPattern: [String: String] = [:]

        for day in days {
            if let emotions = weekdayEmotions[day], !emotions.isEmpty {
                // 计算每种情感的出现次数
                var emotionCounts: [UserEmotionState: Int] = [:]
                for emotion in emotions {
                    emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1
                }

                // 找出最高次数的情感
                let dominant = emotionCounts.max { $0.value < $1.value }
                if let dominantEmotion = dominant {
                    weeklyPattern[day] = dominantEmotion.key.rawValue
                }
            }
        }

        return weeklyPattern
    }

    /// 分析每日情感模式
    /// - Parameter history: 情感历史
    /// - Returns: 各时间段的主导情感
    private func analyzeDailyPattern(_ history: [EmotionChange]) -> [String: String] {
        var periodEmotions: [String: [UserEmotionState]] = [:]
        let periods = ["早晨", "上午", "中午", "下午", "傍晚", "晚上", "深夜"]

        for change in history {
            let hour = Calendar.current.component(.hour, from: change.timestamp)
            let periodName = getPeriodNameForHour(hour)

            if periodEmotions[periodName] == nil {
                periodEmotions[periodName] = []
            }
            periodEmotions[periodName]?.append(change.emotion)
        }

        // 找出每个时段的主导情感
        var dailyPattern: [String: String] = [:]

        for period in periods {
            if let emotions = periodEmotions[period], !emotions.isEmpty {
                var emotionCounts: [UserEmotionState: Int] = [:]
                for emotion in emotions {
                    emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1
                }

                let dominant = emotionCounts.max { $0.value < $1.value }
                if let dominantEmotion = dominant {
                    dailyPattern[period] = dominantEmotion.key.rawValue
                }
            }
        }

        return dailyPattern
    }

    /// 根据小时数获取时段名称
    /// - Parameter hour: 小时数（0-23）
    /// - Returns: 时段名称
    private func getPeriodNameForHour(_ hour: Int) -> String {
        switch hour {
        case 5..<7: return "早晨"
        case 7..<11: return "上午"
        case 11..<13: return "中午"
        case 13..<17: return "下午"
        case 17..<19: return "傍晚"
        case 19..<23: return "晚上"
        default: return "深夜"  // 0-4, 23-24
        }
    }

    /// 分析情感频率分布
    /// - Parameter history: 情感历史
    /// - Returns: 各情感状态的出现频率（百分比）
    private func analyzeEmotionFrequency(_ history: [EmotionChange]) -> [String: Double] {
        var emotionCounts: [UserEmotionState: Int] = [:]

        for change in history {
            emotionCounts[change.emotion] = (emotionCounts[change.emotion] ?? 0) + 1
        }

        let total = history.count
        var frequency: [String: Double] = [:]

        for emotion in UserEmotionState.allCases {
            let count = emotionCounts[emotion] ?? 0
            frequency[emotion.rawValue] = Double(count) / Double(total)
        }

        return frequency
    }

    /// 加载情感模式
    /// - Returns: 情感模式数据
    private func loadEmotionPatterns() -> EmotionPatterns {
        guard FileManager.default.fileExists(atPath: userProfilePath.path) else {
            return EmotionPatterns.empty
        }

        do {
            let data = FileManager.default.contents(atPath: userProfilePath.path)
            if let data = data {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let patternsDict = json?["emotionPatterns"] as? [String: Any] {
                    return parseEmotionPatterns(patternsDict)
                }
            }
        } catch {
            print("⚠️ EmotionTracker: Failed to load emotion patterns - \(error.localizedDescription)")
        }

        return EmotionPatterns.empty
    }

    /// 解析情感模式字典
    /// - Parameter dict: 情感模式字典
    /// - Returns: 解析后的情感模式
    private func parseEmotionPatterns(_ dict: [String: Any]) -> EmotionPatterns {
        var patterns = EmotionPatterns()

        if let weeklyPattern = dict["weeklyPattern"] as? [String: String] {
            patterns.weeklyPattern = weeklyPattern
        }

        if let dailyPattern = dict["dailyPattern"] as? [String: String] {
            patterns.dailyPattern = dailyPattern
        }

        if let emotionFrequency = dict["emotionFrequency"] as? [String: Double] {
            patterns.emotionFrequency = emotionFrequency
        }

        if let lastUpdatedStr = dict["lastUpdated"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            patterns.lastUpdated = dateFormatter.date(from: lastUpdatedStr) ?? Date()
        }

        return patterns
    }

    /// 保存情感模式到user-profile.json
    /// - Parameter patterns: 情感模式数据
    private func saveEmotionPatterns(_ patterns: EmotionPatterns) {
        MemoryStoragePath.ensureAllDirectoriesExist()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let patternsDict: [String: Any] = [
            "weeklyPattern": patterns.weeklyPattern,
            "dailyPattern": patterns.dailyPattern,
            "emotionFrequency": patterns.emotionFrequency,
            "lastUpdated": dateFormatter.string(from: patterns.lastUpdated)
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
                print("⚠️ EmotionTracker: Failed to load existing profile - \(error.localizedDescription)")
            }
        }

        // 更新emotionPatterns字段
        existingProfile["emotionPatterns"] = patternsDict

        // 保存到文件
        do {
            let data = try JSONSerialization.data(withJSONObject: existingProfile, options: [.prettyPrinted])
            try data.write(to: userProfilePath)
        } catch {
            print("⚠️ EmotionTracker: Failed to save emotion patterns - \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods for CommentGenerator

    /// 获取当前情感状态的描述（用于LLM Prompt）
    /// - Returns: 当前情感描述字符串
    func getCurrentEmotionDescription() -> String {
        let emotion = getCurrentEmotion()
        return emotion.rawValue
    }

    /// 获取情感模式描述（用于LLM Prompt）
    /// - Returns: 情感模式描述字符串
    func getEmotionPatternsDescription() -> String {
        let patterns = getEmotionPatterns()

        var desc = ""

        // 检查是否有焦虑模式
        let anxiousDays = patterns.weeklyPattern.filter { $0.value == "焦虑" }.keys
        if !anxiousDays.isEmpty {
            desc += "焦虑周期：\(anxiousDays.joined(separator: ", "))容易焦虑\n"
        }

        // 检查是否有高频焦虑
        if let anxiousFreq = patterns.emotionFrequency["焦虑"], anxiousFreq > 0.3 {
            desc += "焦虑频率较高(\(Int(anxiousFreq * 100))%)\n"
        }

        // 检查是否有高频压力
        if let stressedFreq = patterns.emotionFrequency["压力"], stressedFreq > 0.2 {
            desc += "压力频率较高(\(Int(stressedFreq * 100))%)\n"
        }

        return desc.isEmpty ? "无明显情感模式" : desc
    }

    /// 判断是否处于焦虑状态或焦虑周期
    /// - Returns: 是否需要给予安慰
    func needsComforting() -> Bool {
        let currentEmotion = getCurrentEmotion()

        // 当前情感为焦虑或压力
        if currentEmotion == .anxious || currentEmotion == .stressed {
            return true
        }

        // 检查焦虑模式
        let patterns = getEmotionPatterns()

        // 今天是否是焦虑周期日
        let weekday = Calendar.current.component(.weekday, from: Date())
        let days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let today = days[weekday - 1]

        if patterns.weeklyPattern[today] == "焦虑" {
            return true
        }

        // 当前时段是否是焦虑时段
        let hour = Calendar.current.component(.hour, from: Date())
        let periodName = getPeriodNameForHour(hour)

        if patterns.dailyPattern[periodName] == "焦虑" {
            return true
        }

        return false
    }

    /// 获取关心类气泡内容建议
    /// 基于当前情感状态生成合适的关心内容
    /// - Returns: 关心类气泡内容
    func getComfortingBubbleContent() -> String {
        let emotion = getCurrentEmotion()

        // 从情感状态的建议列表中随机选择
        let suggestions = emotion.caringBubbleSuggestions
        return suggestions.randomElement() ?? "有什么想聊聊的？"
    }

    /// 检查是否处于放松状态
    /// 用于决定生成轻松调侃类气泡
    /// - Returns: 是否处于放松状态
    func isRelaxedState() -> Bool {
        let emotion = getCurrentEmotion()
        return emotion == .relaxed || emotion == .happy || emotion == .excited
    }
}