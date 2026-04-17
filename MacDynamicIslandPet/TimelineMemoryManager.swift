import Foundation
import Combine

// MARK: - Event Type Definition

/// 事件类型枚举，定义时间线记忆的事件分类
///
/// 用于L3中期记忆的事件时间线存储
/// 每种事件类型有不同的触发机制和提醒内容模板
enum EventType: String, Codable, CaseIterable {
    /// 生日 - 用户或重要人物的生日
    case birthday = "生日"
    /// 纪念日 - 重要纪念日期
    case anniversary = "纪念日"
    /// 用户成就 - 用户取得的成就或里程碑
    case achievement = "用户成就"
    /// 首次互动 - 与精灵的首次互动记录
    case firstInteraction = "首次互动"
    /// 里程碑 - 重要的人生或互动里程碑
    case milestone = "里程碑"
    /// 重要日程 - 重要日程安排
    case importantSchedule = "重要日程"

    /// 获取事件类型的描述说明
    var description: String {
        switch self {
        case .birthday:
            return "生日 - 用户或重要人物的生日，当天提醒生日快乐"
        case .anniversary:
            return "纪念日 - 重要纪念日期，当天提醒纪念日意义"
        case .achievement:
            return "用户成就 - 用户取得的成就，如通过考试、升职等"
        case .firstInteraction:
            return "首次互动 - 与精灵的首次互动记录，标记关系的开始"
        case .milestone:
            return "里程碑 - 重要的人生或互动里程碑，如认识100天等"
        case .importantSchedule:
            return "重要日程 - 重要日程安排，如面试、出差、会议等"
        }
    }

    /// 获取事件提醒气泡的内容模板
    var reminderTemplate: String {
        switch self {
        case .birthday:
            return "今天是你生日！祝你生日快乐~"
        case .anniversary:
            return "今天是{description}纪念日，还记得吗？"
        case .achievement:
            return "恭喜你！{description}成就达成~"
        case .firstInteraction:
            return "这是我们第一次互动的日子，{description}"
        case .milestone:
            return "今天是{description}的里程碑，值得庆祝！"
        case .importantSchedule:
            return "今天有{description}安排，别忘了哦"
        }
    }

    /// 获取事件类型的图标名称（用于UI显示）
    var icon: String {
        switch self {
        case .birthday:
            return "🎂"
        case .anniversary:
            return "💕"
        case .achievement:
            return "🏆"
        case .firstInteraction:
            return "👋"
        case .milestone:
            return "🌟"
        case .importantSchedule:
            return "📅"
        }
    }
}

// MARK: - Timeline Event Structure

/// 时间线事件结构体，存储L3中期记忆的事件记录
///
/// 每个事件包含完整的元数据：日期、类型、描述、重要性、来源、关联对话等
/// 存储路径：~/Library/Application Support/MacDynamicIslandPet/memory/timeline.json
struct TimelineEvent: Codable, Identifiable {
    /// 事件唯一标识（UUID）
    var id: String

    /// 事件日期（可能只包含月日，如生日；也可能包含完整日期）
    var date: Date

    /// 事件类型
    var type: EventType

    /// 事件描述
    var description: String

    /// 事件重要性评分（1-10）
    var importance: Int

    /// 事件来源：conversation（从对话自动提取）或 manual（手动添加）
    var source: String

    /// 关联对话ID列表
    var relatedConversations: [String]

    /// 事件创建时间
    var createdAt: Date

    /// 是否为每年重复事件（如生日、纪念日）
    var isRecurring: Bool

    /// 创建新的时间线事件
    /// - Parameters:
    ///   - date: 事件日期
    ///   - type: 事件类型
    ///   - description: 事件描述
    ///   - importance: 重要性评分（1-10）
    ///   - source: 事件来源
    ///   - relatedConversations: 关联对话ID
    ///   - isRecurring: 是否每年重复
    /// - Returns: 新的时间线事件实例
    static func create(
        date: Date,
        type: EventType,
        description: String,
        importance: Int = 5,
        source: String = "manual",
        relatedConversations: [String] = [],
        isRecurring: Bool = false
    ) -> TimelineEvent {
        return TimelineEvent(
            id: UUID().uuidString,
            date: date,
            type: type,
            description: description,
            importance: max(1, min(10, importance)),
            source: source,
            relatedConversations: relatedConversations,
            createdAt: Date(),
            isRecurring: isRecurring
        )
    }

    /// 获取事件的提醒气泡内容
    /// - Returns: 根据事件类型和描述生成的提醒内容
    func generateReminderContent() -> String {
        let template = type.reminderTemplate
        return template.replacingOccurrences(of: "{description}", with: description)
    }

    /// 检查事件日期是否匹配今天（考虑重复事件）
    /// - Returns: 如果事件日期匹配今天返回true
    func isToday() -> Bool {
        let calendar = Calendar.current
        let today = Date()

        if isRecurring {
            // 重复事件只比较月日
            let eventComponents = calendar.dateComponents([.month, .day], from: date)
            let todayComponents = calendar.dateComponents([.month, .day], from: today)
            return eventComponents.month == todayComponents.month &&
                   eventComponents.day == todayComponents.day
        } else {
            // 非重复事件比较完整日期
            return calendar.isDate(date, inSameDayAs: today)
        }
    }

    /// 检查事件日期是否在指定天数范围内
    /// - Parameter days: 天数范围
    /// - Returns: 如果事件在指定天数内返回true
    func isWithinDays(_ days: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let futureDate = calendar.date(byAdding: .day, value: days, to: today) ?? today

        if isRecurring {
            // 重复事件：检查今年或明年的日期是否在范围内
            let year = calendar.component(.year, from: today)
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)

            let thisYearEvent = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? date

            if thisYearEvent >= today && thisYearEvent <= futureDate {
                return true
            }

            // 检查明年
            let nextYear = year + 1
            let nextYearEvent = calendar.date(from: DateComponents(year: nextYear, month: month, day: day)) ?? date

            return nextYearEvent >= today && nextYearEvent <= futureDate
        } else {
            return date >= today && date <= futureDate
        }
    }
}

// MARK: - Timeline Memory Manager

/// 时间线记忆管理器（L3中期记忆）
///
/// 管理事件时间线的存储、检索和提醒
/// 存储文件：~/Library/Application Support/MacDynamicIslandPet/memory/timeline.json
///
/// 主要功能：
/// - 事件的添加、删除、更新
/// - 按日期、类型、重要性检索事件
/// - 每日00:00自动检查今日事件并触发提醒
class TimelineMemoryManager {
    /// 单例实例
    static let shared = TimelineMemoryManager()

    /// 存储文件路径
    private let storageFile: URL = MemoryStoragePath.timelineFile

    /// 事件列表
    private var events: [TimelineEvent] = []

    /// 每日提醒检查Timer
    private var dailyCheckTimer: Timer?

    /// Combine订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// 今日提醒事件（用于气泡触发）
    @Published var todayReminders: [TimelineEvent] = []

    /// 初始化
    private init() {
        // 确保存储目录存在
        MemoryStoragePath.ensureAllDirectoriesExist()

        // 加载已有事件
        loadEvents()

        // 设置每日提醒检查
        setupDailyReminderCheck()

        // 立即检查今日事件
        checkTodayEvents()

        print("📅 TimelineMemoryManager initialized with \(events.count) events")
    }

    // MARK: - Event Storage Operations

    /// 加载已有事件
    private func loadEvents() {
        guard FileManager.default.fileExists(atPath: storageFile.path) else {
            // 文件不存在，使用空列表
            events = []
            saveEvents()
            print("📅 Created new timeline.json file")
            return
        }

        do {
            let data = FileManager.default.contents(atPath: storageFile.path)
            if let data = data {
                events = try JSONDecoder().decode([TimelineEvent].self, from: data)
                print("📅 Loaded \(events.count) events from timeline.json")
            }
        } catch {
            print("⚠️ Failed to load timeline.json: \(error.localizedDescription)")
            events = []
        }
    }

    /// 保存事件到文件
    private func saveEvents() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: storageFile)
            print("📅 Saved \(events.count) events to timeline.json")
        } catch {
            print("⚠️ Failed to save timeline.json: \(error.localizedDescription)")
        }
    }

    /// 添加事件
    /// - Parameter event: 要添加的事件
    /// - Returns: 添加成功返回true
    func addEvent(_ event: TimelineEvent) -> Bool {
        // 检查是否已存在相同ID的事件
        if events.contains(where: { $0.id == event.id }) {
            print("⚠️ Event with ID \(event.id) already exists")
            return false
        }

        events.append(event)
        saveEvents()

        MemoryCardManager.shared.ingestTimelineEvent(event)

        // 检查是否是今日事件
        if event.isToday() {
            todayReminders.append(event)
        }

        print("📅 Added event: \(event.type.rawValue) - \(event.description)")
        return true
    }

    /// 删除事件
    /// - Parameter eventId: 事件ID
    /// - Returns: 删除成功返回true
    func deleteEvent(_ eventId: String) -> Bool {
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            let removedEvent = events.remove(at: index)
            saveEvents()

            // 从今日提醒中移除
            todayReminders.removeAll { $0.id == eventId }

            print("📅 Deleted event: \(removedEvent.type.rawValue) - \(removedEvent.description)")
            return true
        }
        return false
    }

    /// 更新事件
    /// - Parameter event: 更新后的事件
    /// - Returns: 更新成功返回true
    func updateEvent(_ event: TimelineEvent) -> Bool {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            saveEvents()

            // 更新今日提醒
            if event.isToday() {
                if !todayReminders.contains(where: { $0.id == event.id }) {
                    todayReminders.append(event)
                }
            } else {
                todayReminders.removeAll { $0.id == event.id }
            }

            print("📅 Updated event: \(event.type.rawValue) - \(event.description)")
            return true
        }
        return false
    }

    // MARK: - Event Retrieval Methods

    /// 获取指定日期的事件
    /// - Parameter date: 目标日期
    /// - Returns: 该日期的事件列表
    func getEventsForDate(_ date: Date) -> [TimelineEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            if event.isRecurring {
                // 重复事件只比较月日
                let eventComponents = calendar.dateComponents([.month, .day], from: event.date)
                let targetComponents = calendar.dateComponents([.month, .day], from: date)
                return eventComponents.month == targetComponents.month &&
                       eventComponents.day == targetComponents.day
            } else {
                return calendar.isDate(event.date, inSameDayAs: date)
            }
        }
    }

    /// 获取即将到来的事件（指定天数范围内）
    /// - Parameter days: 天数范围
    /// - Returns: 未来指定天数内的事件列表，按日期排序
    func getUpcomingEvents(_ days: Int) -> [TimelineEvent] {
        let upcomingEvents = events.filter { event in
            event.isWithinDays(days)
        }

        // 按日期排序
        return upcomingEvents.sorted { $0.date < $1.date }
    }

    /// 获取指定类型的事件
    /// - Parameter type: 事件类型
    /// - Returns: 该类型的事件列表
    func getEventsByType(_ type: EventType) -> [TimelineEvent] {
        return events.filter { $0.type == type }
    }

    /// 获取所有事件
    /// - Returns: 所有事件列表，按重要性排序
    func getAllEvents() -> [TimelineEvent] {
        return events.sorted { $0.importance > $1.importance }
    }

    /// 获取高重要性事件（importance >= 7）
    /// - Returns: 高重要性事件列表
    func getHighImportanceEvents() -> [TimelineEvent] {
        return events.filter { $0.importance >= 7 }
    }

    /// 搜索事件（按描述关键词）
    /// - Parameter keyword: 搜索关键词
    /// - Returns: 匹配的事件列表
    func searchEvents(_ keyword: String) -> [TimelineEvent] {
        return events.filter { event in
            event.description.contains(keyword) || event.type.rawValue.contains(keyword)
        }
    }

    // MARK: - Daily Reminder Mechanism

    /// 设置每日提醒检查（00:00触发）
    private func setupDailyReminderCheck() {
        // 计算下一个00:00的时间
        let calendar = Calendar.current
        let now = Date()

        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        tomorrowComponents.day! += 1
        tomorrowComponents.hour = 0
        tomorrowComponents.minute = 0
        tomorrowComponents.second = 0

        let nextMidnight = calendar.date(from: tomorrowComponents) ?? now
        let timeInterval = nextMidnight.timeIntervalSince(now)

        // 设置Timer在下一个00:00触发，之后每24小时重复
        dailyCheckTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.checkTodayEvents()

            // 设置每24小时重复检查
            self?.dailyCheckTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
                self?.checkTodayEvents()
            }
        }

        print("📅 Daily reminder check scheduled for next midnight (\(nextMidnight))")
    }

    /// 检查今日事件并更新提醒列表
    func checkTodayEvents() {
        let todayEvents = getEventsForDate(Date())

        // 按重要性排序，高重要性事件优先提醒
        todayReminders = todayEvents.sorted { $0.importance > $1.importance }

        print("📅 Checked today events: found \(todayReminders.count) events")

        // 如果有今日事件，触发提醒气泡
        if todayReminders.count > 0 {
            triggerEventReminders()
        }
    }

    /// 触发事件提醒气泡
    private func triggerEventReminders() {
        // 取最高重要性的事件生成提醒
        if let topEvent = todayReminders.first {
            let reminderContent = topEvent.generateReminderContent()
            print("📅 Triggering event reminder: \(reminderContent)")

            // 通过SelfTalkManager显示提醒气泡
            SelfTalkManager.shared.showEventReminder(reminderContent, eventType: topEvent.type)
        }
    }

    /// 获取下一个待提醒的事件
    /// - Returns: 下一个待提醒的事件，如果没有返回nil
    func getNextReminder() -> TimelineEvent? {
        return todayReminders.first
    }

    /// 标记事件已被提醒
    /// - Parameter eventId: 事件ID
    func markEventReminded(_ eventId: String) {
        todayReminders.removeAll { $0.id == eventId }
    }

    // MARK: - Statistics

    /// 获取事件统计信息
    /// - Returns: 各类型事件的数量统计
    func getEventStatistics() -> [EventType: Int] {
        var stats: [EventType: Int] = [:]
        for type in EventType.allCases {
            stats[type] = events.filter { $0.type == type }.count
        }
        return stats
    }

    /// 获取事件总数
    /// - Returns: 事件总数
    func getTotalEventCount() -> Int {
        return events.count
    }

    /// 获取今日事件的 prompt 描述（用于精灵自言自语和对话）
    /// - Returns: 今日事件描述字符串，无事件时返回空字符串
    func getTodayEventsPromptDescription() -> String {
        let todayEvents = getEventsForDate(Date())

        if todayEvents.isEmpty {
            return ""
        }

        // 按重要性排序
        let sortedEvents = todayEvents.sorted { $0.importance > $1.importance }

        var description = ""
        for event in sortedEvents {
            let icon = event.type.icon
            let eventDesc = event.description.isEmpty ? event.type.rawValue : event.description
            description += "\(icon) \(event.type.rawValue)：\(eventDesc)\n"
        }

        return description
    }
}
