import Foundation

// MARK: - Importance Keyword Definitions

/// 高重要性关键词定义
///
/// 对话包含这些关键词时，importanceScore设为10
/// 这些关键词通常代表用户生活中的重要事件或里程碑
struct ImportanceKeyword {
    /// 高重要性关键词列表（importanceScore = 10）
    ///
    /// 包含：生日、面试、出差、纪念日、结婚、升职、毕业、搬家、生病、考试
    /// 这些关键词代表用户生活中的重要事件，精灵需要特别记住
    static let highImportanceKeywords: [String] = [
        "生日",      // 用户或重要人物的生日
        "面试",      // 工作面试等重要机会
        "出差",      // 工作出差行程
        "纪念日",    // 重要纪念日期
        "结婚",      // 婚姻大事
        "升职",      // 职业发展里程碑
        "毕业",      // 学业里程碑
        "搬家",      // 生活重大变化
        "生病",      // 健康状况关注
        "考试",      // 重要考试
        "入职",      // 新工作入职
        "离职",      // 离职变动
        "求婚",      // 感情里程碑
        "怀孕",      // 家庭重大变化
        "订婚",      // 感情里程碑
        "分手",      // 感情变动
        "相亲",      // 感情生活
        "买房",      // 财务里程碑
        "买车",      // 财务里程碑
        "旅游",      // 旅行计划
        "旅行",      // 旅行计划
        "放假",      // 重要假期安排
        "过年",      // 重要节日
        "春节",      // 重要节日
        "中秋",      // 重要节日
        "婚礼",      // 重要事件参与
        "手术",      // 健康重大事件
        "住院",      // 健康状况关注
        "裁员",      // 工作变动
        "跳槽",      // 工作变动
        "offer",     // 工作offer
        "加薪",      // 职业发展
        "年终",      // 工作重要节点
        "答辩",      // 学业重要节点
        "签证",      // 出国相关
        "出国",      // 重要行程
        "回国",      // 重要行程
    ]

    /// 中等重要性关键词（importanceScore = 5-7）
    ///
    /// 包含：约会、聚餐、开会、汇报、加班、健身、学习等日常重要活动
    static let mediumImportanceKeywords: [String] = [
        "约会",      // 社交活动
        "聚餐",      // 社交活动
        "开会",      // 工作活动
        "汇报",      // 工作活动
        "加班",      // 工作状态
        "健身",      // 生活习惯
        "学习",      // 自我提升
        "报名",      // 活动参与
        "报名了",    // 活动参与
        "买票",      // 活动安排
        "预约",      // 活动安排
        "快递",      // 生活琐事
        "打折",      // 购物信息
        "优惠",      // 购物信息
    ]

    /// 检查对话内容是否包含高重要性关键词
    /// - Parameter content: 对话内容字符串
    /// - Returns: 如果包含高重要性关键词返回true，否则返回false
    static func containsHighImportance(content: String) -> Bool {
        for keyword in highImportanceKeywords {
            if content.contains(keyword) {
                return true
            }
        }
        return false
    }

    /// 检查对话内容是否包含中等重要性关键词
    /// - Parameter content: 对话内容字符串
    /// - Returns: 如果包含中等重要性关键词返回true，否则返回false
    static func containsMediumImportance(content: String) -> Bool {
        for keyword in mediumImportanceKeywords {
            if content.contains(keyword) {
                return true
            }
        }
        return false
    }

    /// 根据对话内容计算重要性评分
    /// - Parameter content: 对话内容字符串
    /// - Returns: 重要性评分（1-10）
    ///
    /// 计算规则：
    /// - 包含高重要性关键词：score = 10
    /// - 包含中等重要性关键词：score = 6
    /// - 其他对话：score = 基于情感强度的计算（1-5）
    static func calculateImportance(content: String) -> Int {
        // 首先检查高重要性关键词
        if containsHighImportance(content: content) {
            return 10
        }

        // 检查中等重要性关键词
        if containsMediumImportance(content: content) {
            return 6
        }

        // 基于情感强度计算
        let emotions = EmotionTag.quickDetect(content: content)

        // 情感强度评分
        // happy/excited/grateful/confident = 较高重要性
        // sad/anxious/annoyed = 中等重要性
        // calm = 低重要性
        if emotions.contains(.happy) || emotions.contains(.excited) ||
           emotions.contains(.grateful) || emotions.contains(.confident) {
            return 4
        } else if emotions.contains(.sad) || emotions.contains(.anxious) ||
                  emotions.contains(.annoyed) {
            return 5
        }

        // 默认低重要性
        return 2
    }

    /// 从对话内容提取匹配的高重要性关键词列表
    /// - Parameter content: 对话内容字符串
    /// - Returns: 匹配到的关键词列表
    static func extractHighImportanceKeywords(content: String) -> [String] {
        var matchedKeywords: [String] = []

        for keyword in highImportanceKeywords {
            if content.contains(keyword) {
                matchedKeywords.append(keyword)
            }
        }

        return matchedKeywords
    }

    /// 从对话内容提取匹配的中等重要性关键词列表
    /// - Parameter content: 对话内容字符串
    /// - Returns: 匹配到的关键词列表
    static func extractMediumImportanceKeywords(content: String) -> [String] {
        var matchedKeywords: [String] = []

        for keyword in mediumImportanceKeywords {
            if content.contains(keyword) {
                matchedKeywords.append(keyword)
            }
        }

        return matchedKeywords
    }
}