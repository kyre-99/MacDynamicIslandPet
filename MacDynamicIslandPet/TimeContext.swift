import Foundation
import Combine

/// Manages time context awareness for the pet
/// US-006: Provides time-based context for comment generation
class TimeContext: ObservableObject {
    static let shared = TimeContext()

    // MARK: - Published Properties

    /// Current time period (早晨/上午/中午/下午/傍晚/晚上/深夜)
    @Published var currentPeriod: TimePeriod

    /// Whether it's work time (9-18)
    @Published var isWorkTime: Bool = false

    /// Whether it's rest/break time
    @Published var isRestTime: Bool = false

    /// Whether it's weekend
    @Published var isWeekend: Bool = false

    /// Whether it's a holiday (simplified check for common holidays)
    @Published var isHoliday: Bool = false

    /// Current hour (for reference)
    @Published var currentHour: Int = 0

    /// Current date description (for context)
    @Published var dateDescription: String = ""

    // MARK: - Private Properties

    private var updateTimer: Timer?

    // MARK: - Comment Tendencies

    /// Default comment tendency for each time period
    struct CommentTendency {
        let style: CommentStyle
        let topics: [String]
        let intensity: Double  // 0.0-1.0, how strongly to apply this tendency
    }

    /// Comment styles for different periods
    enum CommentStyle: String {
        case caring      // 关心提醒（深夜、长时间工作）
        case playful     // 搞怪调侃（休闲时间）
        case supportive  // 温和鼓励（工作时间）
        case curious     // 好奇询问（空闲时间）
    }

    // MARK: - Initialization

    private init() {
        currentPeriod = TimePeriod.fromHour(Calendar.current.component(.hour, from: Date()))
        updateTimeContext()
        startUpdateTimer()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Timer Setup

    /// Start timer to update time context every minute
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateTimeContext()
        }
        RunLoop.current.add(updateTimer!, forMode: .common)
    }

    // MARK: - Time Context Update

    /// Update all time context properties
    func updateTimeContext() {
        let now = Date()
        let calendar = Calendar.current

        // Update current hour
        currentHour = calendar.component(.hour, from: now)

        // Update time period
        currentPeriod = TimePeriod.fromHour(currentHour)

        // Check work time (9-18)
        isWorkTime = currentHour >= 9 && currentHour < 18

        // Check rest time (evening, night, or lunch break)
        isRestTime = currentHour >= 18 || currentHour < 6 || (currentHour >= 12 && currentHour < 14)

        // Check weekend
        let weekday = calendar.component(.weekday, from: now)
        isWeekend = weekday == 1 || weekday == 7  // Sunday=1, Saturday=7

        // Check holidays (simplified - major Chinese holidays)
        isHoliday = checkHoliday(now)

        // Build date description
        dateDescription = buildDateDescription(now)
    }

    /// Check if today is a major holiday
    private func checkHoliday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        // Simplified holiday check for common holidays
        // New Year: Jan 1
        // Spring Festival: Usually Jan/Feb (variable, simplified as Feb 10-17)
        // Labor Day: May 1
        // National Day: Oct 1
        // Christmas: Dec 25

        let holidays: [(month: Int, day: Int)] = [
            (1, 1),   // New Year
            (1, 2),   // New Year continuation
            (2, 10), (2, 11), (2, 12), (2, 13), (2, 14), (2, 15), (2, 16), (2, 17),  // Spring Festival approximation
            (5, 1),   // Labor Day
            (10, 1), (10, 2), (10, 3),  // National Day
            (12, 25)  // Christmas
        ]

        return holidays.contains { $0.month == month && $0.day == day }
    }

    /// Build a human-readable date description
    private func buildDateDescription(_ date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekdayName = weekdayNames[weekday - 1]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM月dd日"
        let dateStr = dateFormatter.string(from: date)

        var description = "\(dateStr) \(weekdayName)"

        if isWeekend {
            description += " (周末)"
        }

        if isHoliday {
            description += " (节假日)"
        }

        description += " \(currentPeriod.displayName)"

        return description
    }

    // MARK: - Comment Tendency

    /// Get comment tendency for current time period
    func getCommentTendency() -> CommentTendency {
        switch currentPeriod {
        case .lateNight:
            // 深夜: 关心休息，强烈建议睡觉
            return CommentTendency(
                style: .caring,
                topics: ["该休息了", "熬夜伤身体", "早点睡吧"],
                intensity: 0.9
            )
        case .morning:
            // 早晨: 温和鼓励，新的一天
            return CommentTendency(
                style: .supportive,
                topics: ["早上好", "新的一天", "元气满满"],
                intensity: 0.5
            )
        case .morningLate:
            // 上午: 工作时间，调侃效率
            if isWorkTime {
                return CommentTendency(
                    style: .playful,
                    topics: ["努力工作", "效率满满", "加油"],
                    intensity: 0.6
                )
            }
            return CommentTendency(style: .curious, topics: ["今天干嘛呢"], intensity: 0.3)
        case .noon:
            // 中午: 休息时间，关心吃饭
            return CommentTendency(
                style: .caring,
                topics: ["该吃午饭了", "休息一下", "吃好吃的"],
                intensity: 0.7
            )
        case .afternoon:
            // 下午: 工作时间，鼓励加油
            if isWorkTime {
                return CommentTendency(
                    style: .supportive,
                    topics: ["下午加油", "继续努力", "还有半天"],
                    intensity: 0.5
                )
            }
            return CommentTendency(style: .curious, topics: ["下午干嘛呢"], intensity: 0.3)
        case .evening:
            // 傍晚: 休息时间，放松心情
            return CommentTendency(
                style: .playful,
                topics: ["下班啦", "放松放松", "晚餐时间"],
                intensity: 0.6
            )
        case .night:
            // 晚上: 休闲时间，搞怪调侃
            return CommentTendency(
                style: .playful,
                topics: ["晚上好", "今天过得怎么样", "放松一下"],
                intensity: 0.5
            )
        }
    }

    /// Get comment tendency considering both time and activity duration
    func getCommentTendency(activityDuration: TimeInterval) -> CommentTendency {
        // If user has been doing something for a long time, override with caring tendency
        if activityDuration > 3600 {  // More than 1 hour
            // Long activity - care about rest
            if currentPeriod == .lateNight || currentPeriod == .night {
                return CommentTendency(
                    style: .caring,
                    topics: ["已经很久了", "该休息了", "注意身体"],
                    intensity: 0.9
                )
            }
            // Long work during work time - encourage
            if isWorkTime {
                return CommentTendency(
                    style: .supportive,
                    topics: ["辛苦了", "休息一下", "喝杯水"],
                    intensity: 0.8
                )
            }
        }

        return getCommentTendency()
    }

    // MARK: - Context for LLM

    /// Build time context string for LLM prompt
    func buildTimeContextForLLM() -> String {
        var context = "当前时间：\(dateDescription)\n"

        if isWorkTime {
            context += "状态：工作时间\n"
        }

        if isRestTime {
            context += "状态：休息时间\n"
        }

        if isWeekend {
            context += "今天是周末\n"
        }

        if isHoliday {
            context += "今天是节假日\n"
        }

        let tendency = getCommentTendency()
        context += "建议吐槽风格：\(tendency.style.rawValue)\n"
        context += "建议话题：\(tendency.topics.joined(separator: ", "))\n"

        return context
    }

    /// Build full context including time and user activity (简洁版)
    func buildFullContext(appName: String, activityDuration: TimeInterval, memoryContext: String? = nil) -> String {
        var context = "时间：\(dateDescription)\n"

        if isWorkTime {
            context += "状态：工作时间\n"
        } else if isRestTime {
            context += "状态：休息时间\n"
        }

        context += "应用：\(appName)\n"
        context += "时长：\(Int(activityDuration / 60))分钟\n"

        // 只在需要时添加记忆（保持简洁）
        if let memory = memoryContext, !memory.isEmpty {
            context += memory
        }

        return context
    }
}