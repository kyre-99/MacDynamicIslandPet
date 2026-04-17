import Foundation

// MARK: - Memory Layer Definition

/// 记忆层次枚举，定义精灵记忆系统的四层结构
///
/// 记忆层次遵循衰减规则：
/// - L1即时记忆：会话结束清空，临时存储当前对话
/// - L2短期记忆：30天清理，每日对话的Markdown文件
/// - L3中期记忆：永久保留，事件时间线JSON文件
/// - L4长期记忆：永久保留，用户画像JSON文件
///
/// 每层记忆有不同的容量限制、存储格式和检索策略
enum MemoryLayer: String, Codable {
    /// L1即时记忆 - 当前会话对话，容量限制5条
    case instant = "L1"
    /// L2短期记忆 - 每日对话Markdown文件，保留30天
    case shortTerm = "L2"
    /// L3中期记忆 - 事件时间线JSON文件，永久保留
    case mediumTerm = "L3"
    /// L4长期记忆 - 用户画像JSON文件，永久保留
    case longTerm = "L4"

    /// 获取该层记忆的描述
    var description: String {
        switch self {
        case .instant:
            return "即时记忆 - 当前会话对话，容量限制5条，会话结束清空"
        case .shortTerm:
            return "短期记忆 - 每日对话Markdown文件，保留30天后自动清理"
        case .mediumTerm:
            return "中期记忆 - 事件时间线JSON文件，永久保留"
        case .longTerm:
            return "长期记忆 - 用户画像JSON文件，永久保留"
        }
    }

    /// 获取该层记忆的容量限制
    var capacityLimit: Int {
        switch self {
        case .instant:
            return 5  // L1: 最多5条当前对话
        case .shortTerm:
            return 30  // L2: 保留30天的文件
        case .mediumTerm, .longTerm:
            return -1  // L3/L4: 无容量限制（永久保留）
        }
    }

    /// 获取该层记忆的衰减天数
    var decayDays: Int? {
        switch self {
        case .instant:
            return 0  // L1: 会话结束立即清空
        case .shortTerm:
            return 30  // L2: 30天后清理
        case .mediumTerm, .longTerm:
            return nil  // L3/L4: 永不衰减
        }
    }
}

// MARK: - Memory Configuration

/// 记忆配置结构体，定义每层记忆的具体配置参数
///
/// 配置包括：
/// - 每层记忆的容量限制
/// - 存储文件格式（内存映射或文件）
/// - 衰减和清理规则
/// - 检索策略参数
struct MemoryConfig: Codable {
    /// L1即时记忆配置 - 当前会话对话存储
    var instantMemory: InstantMemoryConfig

    /// L2短期记忆配置 - 每日对话Markdown文件
    var shortTermMemory: ShortTermMemoryConfig

    /// L3中期记忆配置 - 事件时间线JSON文件
    var mediumTermMemory: MediumTermMemoryConfig

    /// L4长期记忆配置 - 用户画像JSON文件
    var longTermMemory: LongTermMemoryConfig

    /// 默认记忆配置
    static let defaultConfig = MemoryConfig(
        instantMemory: InstantMemoryConfig(),
        shortTermMemory: ShortTermMemoryConfig(),
        mediumTermMemory: MediumTermMemoryConfig(),
        longTermMemory: LongTermMemoryConfig()
    )
}

/// L1即时记忆配置
struct InstantMemoryConfig: Codable {
    /// 容量限制 - 最多存储5条当前会话对话
    var capacity: Int = 5

    /// 存储方式 - 内存映射（不持久化到文件）
    var storageType: String = "memory"

    /// 衰减规则 - 会话结束时清空
    var decayRule: String = "sessionEnd"
}

/// L2短期记忆配置
struct ShortTermMemoryConfig: Codable {
    /// 容量限制 - 按日存储，保留30天
    var capacityDays: Int = 30

    /// 存储格式 - Markdown文件
    var fileFormat: String = "markdown"

    /// 衰减规则 - 超过30天的文件自动删除
    var decayRule: String = "30days"

    /// 文件命名模式 - memory-YYYY-MM-DD.md
    var fileNamePattern: String = "memory-{date}.md"
}

/// L3中期记忆配置
struct MediumTermMemoryConfig: Codable {
    /// 存储文件 - timeline.json事件时间线
    var storageFile: String = "timeline.json"

    /// 事件类型支持 - 生日、纪念日、成就、里程碑等
    var supportedEventTypes: [String] = ["birthday", "anniversary", "achievement", "milestone", "importantSchedule", "firstInteraction"]

    /// 衰减规则 - 永久保留，提供手动清理接口
    var decayRule: String = "permanent"
}

/// L4长期记忆配置
struct LongTermMemoryConfig: Codable {
    /// 存储文件 - user-profile.json用户画像
    var storageFile: String = "user-profile.json"

    /// 用户画像字段 - 基本信息偏好、情感历史、互动模式等
    var profileFields: [String] = ["preferences", "emotionHistory", "interactionPatterns", "emotionPatterns"]

    /// 衰减规则 - 永久保留
    var decayRule: String = "permanent"
}

// MARK: - Memory Storage Path Structure

/// 记忆存储路径结构设计
///
/// 目录结构：
/// ~/Library/Application Support/MacDynamicIslandPet/memory/
/// ├── instant/          (L1即时记忆 - 内存映射目录)
/// ├── daily/            (L2每日Markdown文件)
/// ├── timeline.json     (L3事件时间线)
/// ├── user-profile.json (L4用户画像)
/// ├── pet-internal-state.json (小人内部状态)
/// ├── memory-cards.json (结构化记忆卡片)
/// ├── relationship-summary.json (关系摘要)
/// ├── autonomous/       (自主思考历史)
/// └── evolution.json    (进化状态)
enum MemoryStoragePath {
    /// 记忆根目录
    static let memoryDirectory: URL = {
        let baseDir = AppConfigManager.appSupportDirectory
        return baseDir.appendingPathComponent("memory")
    }()

    /// L1即时记忆目录 - 内存映射（实际不存储文件）
    static let instantDirectory: URL = memoryDirectory.appendingPathComponent("instant")

    /// L2短期记忆目录 - 每日Markdown文件
    static let dailyDirectory: URL = memoryDirectory.appendingPathComponent("daily")

    /// L3中期记忆文件 - timeline.json事件时间线
    static let timelineFile: URL = memoryDirectory.appendingPathComponent("timeline.json")

    /// L4长期记忆文件 - user-profile.json用户画像
    static let userProfileFile: URL = memoryDirectory.appendingPathComponent("user-profile.json")

    /// 小人内部状态文件
    static let petInternalStateFile: URL = memoryDirectory.appendingPathComponent("pet-internal-state.json")

    /// 结构化记忆卡片文件
    static let memoryCardsFile: URL = memoryDirectory.appendingPathComponent("memory-cards.json")

    /// 关系摘要文件
    static let relationshipSummaryFile: URL = memoryDirectory.appendingPathComponent("relationship-summary.json")

    /// 自主思考历史目录
    static let autonomousDirectory: URL = memoryDirectory.appendingPathComponent("autonomous")

    /// 自主思考历史文件 - thoughts-history.json
    static let thoughtsHistoryFile: URL = autonomousDirectory.appendingPathComponent("thoughts-history.json")

    /// 进化状态文件 - evolution.json
    static let evolutionFile: URL = memoryDirectory.appendingPathComponent("evolution.json")

    /// 确保所有记忆目录存在
    static func ensureAllDirectoriesExist() {
        let directories = [memoryDirectory, instantDirectory, dailyDirectory, autonomousDirectory]

        for directory in directories {
            if !FileManager.default.fileExists(atPath: directory.path) {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    print("📁 Created memory directory: \(directory.path)")
                } catch {
                    print("⚠️ Failed to create memory directory: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 获取指定层级的存储路径
    /// - Parameter layer: 记忆层级
    /// - Returns: 该层级对应的存储路径
    static func pathForLayer(_ layer: MemoryLayer) -> URL {
        switch layer {
        case .instant:
            return instantDirectory
        case .shortTerm:
            return dailyDirectory
        case .mediumTerm:
            return timelineFile
        case .longTerm:
            return userProfileFile
        }
    }
}

// MARK: - Memory Item Base Structure

/// 记忆条目基础结构，所有记忆类型继承此结构
struct MemoryItem: Codable {
    /// 记忆唯一标识
    var id: String

    /// 记忆创建时间
    var timestamp: Date

    /// 记忆所属层级
    var layer: MemoryLayer

    /// 记忆内容
    var content: String

    /// 话题标签（用于检索）
    var topics: [String]

    /// 情感标签（用于检索）
    var emotions: [String]

    /// 重要性评分（1-10）
    var importanceScore: Int

    /// 创建新的记忆条目
    /// - Parameters:
    ///   - layer: 记忆层级
    ///   - content: 记忆内容
    ///   - topics: 话题标签
    ///   - emotions: 情感标签
    ///   - importance: 重要性评分
    /// - Returns: 新的记忆条目
    static func create(
        layer: MemoryLayer,
        content: String,
        topics: [String] = [],
        emotions: [String] = [],
        importance: Int = 1
    ) -> MemoryItem {
        return MemoryItem(
            id: UUID().uuidString,
            timestamp: Date(),
            layer: layer,
            content: content,
            topics: topics,
            emotions: emotions,
            importanceScore: max(1, min(10, importance))
        )
    }
}

// MARK: - Search Criteria

/// 记忆检索条件枚举
enum MemorySearchCriteria {
    /// 按话题检索
    case topic(String)
    /// 按情感检索
    case emotion(String)
    /// 按重要性检索
    case importance(Int)
    /// 按时间范围检索
    case timeRange(start: Date, end: Date)
    /// 综合检索（多个条件组合）
    case comprehensive(criteria: [MemorySearchCriteria])
}

/// 记忆检索结果
struct MemorySearchResult {
    /// 匹配的记忆条目
    var items: [MemoryItem]

    /// 检索耗时（毫秒）
    var searchTimeMs: Double

    /// 匹配的记忆层级
    var matchedLayers: [MemoryLayer]

    /// 检索条件摘要
    var criteriaSummary: String
}

// MARK: - Conversation Topic

/// 对话话题分类枚举
///
/// 用于按话题分类存储对话记忆，便于后续检索和个性化内容生成
/// 每个话题类别包含相关的关键词匹配规则
enum ConversationTopic: String, Codable, CaseIterable {
    /// 工作 - 工作相关话题
    case work = "工作"
    /// 娱乐 - 娱乐活动话题
    case entertainment = "娱乐"
    /// 心情 - 情感状态话题
    case mood = "心情"
    /// 计划 - 未来计划话题
    case plan = "计划"
    /// 日常 - 日常生活话题
    case daily = "日常"
    /// 兴趣 - 兴趣爱好话题
    case hobby = "兴趣"
    /// 关系 - 人际关系话题
    case relationship = "关系"

    /// 获取话题的描述说明
    var description: String {
        switch self {
        case .work:
            return "工作相关话题：工作内容、项目、会议、加班等"
        case .entertainment:
            return "娱乐活动话题：游戏、电影、音乐、读书等"
        case .mood:
            return "情感状态话题：开心、沮丧、焦虑、平静等心情表达"
        case .plan:
            return "未来计划话题：旅行计划、学习计划、生活安排等"
        case .daily:
            return "日常生活话题：吃饭、睡觉、天气、作息等日常琐事"
        case .hobby:
            return "兴趣爱好话题：运动、收藏、创作、研究等兴趣活动"
        case .relationship:
            return "人际关系话题：朋友、家人、同事、恋爱等关系相关"
        }
    }

    /// 获取话题匹配的关键词列表
    var keywords: [String] {
        switch self {
        case .work:
            return ["工作", "公司", "项目", "会议", "加班", "任务", " deadline", "报告", "领导", "同事", "邮件", "客户", "面试"]
        case .entertainment:
            return ["游戏", "电影", "音乐", "电视剧", "动漫", "小说", "看书", "综艺", "演出", "演唱会", "追剧"]
        case .mood:
            return ["开心", "难过", "累", "烦", "焦虑", "压力大", "心情", "感觉", "很高兴", "好烦", "郁闷", "爽", "无聊"]
        case .plan:
            return ["计划", "打算", "准备", "想去", "下周", "明天", "周末", "假期", "旅行", "安排", "目标", "想要", "想学"]
        case .daily:
            return ["吃饭", "睡觉", "起床", "天气", "今天", "昨晚", "早餐", "午餐", "晚餐", "外卖", "咖啡", "洗澡", "出门"]
        case .hobby:
            return ["喜欢", "兴趣", "爱好", "运动", "健身", "跑步", "摄影", "画画", "乐器", "收藏", "手工", "编程"]
        case .relationship:
            return ["朋友", "家人", "爸妈", "恋爱", "对象", "男朋友", "女朋友", "聊天", "约会", "吵架", "聚会", "亲", "爱"]
        }
    }

    /// 根据对话内容自动识别话题分类
    /// - Parameter content: 对话内容字符串
    /// - Returns: 匹配的话题分类数组（可能匹配多个话题）
    static func classify(content: String) -> [ConversationTopic] {
        var matchedTopics: [ConversationTopic] = []

        for topic in ConversationTopic.allCases {
            for keyword in topic.keywords {
                if content.contains(keyword) {
                    matchedTopics.append(topic)
                    break  // 每个话题只匹配一次
                }
            }
        }

        // 如果没有匹配到任何话题，归类为日常
        if matchedTopics.isEmpty {
            matchedTopics.append(.daily)
        }

        return matchedTopics
    }
}

// MARK: - Emotion Tag

/// 对话情感标签枚举
///
/// 用于标记对话的情感色彩，便于情感检索和情感状态追踪
/// 每次对话保存时调用LLM分析对话情感并添加标签
enum EmotionTag: String, Codable, CaseIterable {
    /// 开心 - 积极正面情感
    case happy = "开心"
    /// 沮丧 - 低落负面情感
    case sad = "沮丧"
    /// 兴奋 - 高能量正面情感
    case excited = "兴奋"
    /// 焦虑 - 紧张担忧情感
    case anxious = "焦虑"
    /// 平静 - 中性稳定情感
    case calm = "平静"
    /// 烦恼 - 不满厌烦情感
    case annoyed = "烦恼"
    /// 感激 - 感恩致谢情感
    case grateful = "感激"
    /// 自信 - 自信坚定情感
    case confident = "自信"

    /// 获取情感标签的描述说明
    var description: String {
        switch self {
        case .happy:
            return "开心 - 积极正面的情感状态，表达喜悦和满足"
        case .sad:
            return "沮丧 - 低落负面的情感状态，表达失落和难过"
        case .excited:
            return "兴奋 - 高能量正面情感状态，表达期待和激动"
        case .anxious:
            return "焦虑 - 紧张担忧的情感状态，表达压力和不安"
        case .calm:
            return "平静 - 中性稳定的情感状态，表达平和和放松"
        case .annoyed:
            return "烦恼 - 不满厌烦的情感状态，表达烦躁和不快"
        case .grateful:
            return "感激 - 感恩致谢的情感状态，表达感谢和认可"
        case .confident:
            return "自信 - 自信坚定的情感状态，表达确信和决心"
        }
    }

    /// 获取情感匹配的关键词列表
    var keywords: [String] {
        switch self {
        case .happy:
            return ["开心", "高兴", "快乐", "幸福", "喜悦", "棒", "好", "太好了", "哈哈", "笑死", "不错"]
        case .sad:
            return ["难过", "伤心", "沮丧", "失望", "郁闷", "不开心", "伤心", "哭", "泪", "悲伤"]
        case .excited:
            return ["兴奋", "激动", "期待", "太棒了", "迫不及待", "超级", "终于", "哇", "厉害"]
        case .anxious:
            return ["焦虑", "紧张", "担心", "害怕", "压力", "压力大", "不安", "着急", "恐慌"]
        case .calm:
            return ["平静", "放松", "淡定", "还好", "没事", "一般", "正常", "稳定"]
        case .annoyed:
            return ["烦", "讨厌", "气死", "无语", "烦躁", "不爽", "烦人", "麻烦", "恼火"]
        case .grateful:
            return ["谢谢", "感谢", "感激", "多谢", "辛苦", "帮忙", "帮忙了", "谢了"]
        case .confident:
            return ["自信", "相信", "没问题", "可以", "能行", "搞定", "肯定", "一定", "确定"]
        }
    }

    /// 根据对话内容快速识别情感标签（基于关键词）
    /// - Parameter content: 对话内容字符串
    /// - Returns: 匹配的情感标签（可能匹配多个情感）
    static func quickDetect(content: String) -> [EmotionTag] {
        var matchedEmotions: [EmotionTag] = []

        for emotion in EmotionTag.allCases {
            for keyword in emotion.keywords {
                if content.contains(keyword) {
                    matchedEmotions.append(emotion)
                    break  // 每个情感只匹配一次
                }
            }
        }

        // 如果没有匹配到任何情感，默认为平静
        if matchedEmotions.isEmpty {
            matchedEmotions.append(.calm)
        }

        return matchedEmotions
    }
}

// MARK: - Enhanced Memory Item Structure

/// 增强的记忆条目结构，包含话题和情感标签
///
/// 用于L2每日Markdown文件的增强格式存储
/// 包含完整的元数据头：日期、话题、情感、重要性评分
struct EnhancedMemoryItem: Codable {
    /// 记忆唯一标识
    var id: String

    /// 记忆创建时间
    var timestamp: Date

    /// 用户输入内容
    var userInput: String

    /// 精灵回复内容
    var petResponse: String

    /// 话题标签列表
    var topics: [ConversationTopic]

    /// 情感标签列表
    var emotions: [EmotionTag]

    /// 重要性评分（1-10）
    var importanceScore: Int

    /// 创建增强记忆条目
    /// - Parameters:
    ///   - userInput: 用户输入
    ///   - petResponse: 精灵回复
    ///   - topics: 话题分类
    ///   - emotions: 情感标签
    ///   - importance: 重要性评分
    /// - Returns: 增强记忆条目实例
    static func create(
        userInput: String,
        petResponse: String,
        topics: [ConversationTopic],
        emotions: [EmotionTag],
        importance: Int
    ) -> EnhancedMemoryItem {
        return EnhancedMemoryItem(
            id: UUID().uuidString,
            timestamp: Date(),
            userInput: userInput,
            petResponse: petResponse,
            topics: topics,
            emotions: emotions,
            importanceScore: max(1, min(10, importance))
        )
    }

    /// 转换为基础MemoryItem格式
    func toBaseMemoryItem(layer: MemoryLayer) -> MemoryItem {
        return MemoryItem.create(
            layer: layer,
            content: "用户: \(userInput) | 精灵: \(petResponse)",
            topics: topics.map { $0.rawValue },
            emotions: emotions.map { $0.rawValue },
            importance: importanceScore
        )
    }
}
