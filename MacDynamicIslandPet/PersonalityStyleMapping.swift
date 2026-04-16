import Foundation

/// 性格维度到对话风格的映射规则
///
/// 定义每个性格维度在不同数值区间对应的对话风格行为：
/// - 高值区间(70-100): 显著的性格特征表现
/// - 中值区间(40-60): 适度的性格特征表现
/// - 低值区间(0-30): 性格特征的缺失或反向表现
struct PersonalityStyleMapping {
    /// 性格维度名称
    enum Dimension: String, CaseIterable {
        case extroversion = "extroversion"
        case curiosity = "curiosity"
        case clinginess = "clinginess"
        case humor = "humor"
        case gentleness = "gentleness"
        case rebellion = "rebellion"
    }

    /// 数值区间类型
    enum ValueRange {
        case high      // 70-100
        case medium    // 40-60
        case low       // 0-30
    }

    /// 性格维度的本地化显示名称
    /// - Parameter dimension: 维度枚举值
    /// - Returns: 中文显示名称
    static func displayName(for dimension: Dimension) -> String {
        switch dimension {
        case .extroversion:
            return "外向度"
        case .curiosity:
            return "好奇心"
        case .clinginess:
            return "粘人程度"
        case .humor:
            return "幽默感"
        case .gentleness:
            return "温柔度"
        case .rebellion:
            return "叛逆度"
        }
    }

    /// 性格维度的中文标签（用于UI滑块）
    /// - Parameter dimension: 维度枚举值
    /// - Returns: 中文标签
    static func label(for dimension: Dimension) -> String {
        switch dimension {
        case .extroversion:
            return "主动活跃"
        case .curiosity:
            return "喜欢探索"
        case .clinginess:
            return "渴望互动"
        case .humor:
            return "调侃幽默"
        case .gentleness:
            return "关心体贴"
        case .rebellion:
            return "搞怪吐槽"
        }
    }

    /// 获取性格维度在指定数值区间的风格描述
    /// - Parameters:
    ///   - dimension: 性格维度
    ///   - range: 数值区间
    /// - Returns: 对应的风格描述
    static func styleDescription(for dimension: Dimension, range: ValueRange) -> String {
        switch dimension {
        case .extroversion:
            switch range {
            case .high:
                return "主动发起话题，多用感叹句，积极活跃"
            case .medium:
                return "根据情境适度互动"
            case .low:
                return "安静内敛，较少主动发起互动"
            }
        case .curiosity:
            switch range {
            case .high:
                return "多问问题，探索新话题，对新鲜事物感兴趣"
            case .medium:
                return "对熟悉话题保持适度关注"
            case .low:
                return "专注熟悉领域，较少提出新话题"
            }
        case .clinginess:
            switch range {
            case .high:
                return "高频气泡，想念型内容，渴望陪伴"
            case .medium:
                return "适度互动需求"
            case .low:
                return "独立自主，较少主动寻求互动"
            }
        case .humor:
            switch range {
            case .high:
                return "调侃幽默，轻松语气，爱开玩笑"
            case .medium:
                return "适度幽默"
            case .low:
                return "正经严肃，较少调侃"
            }
        case .gentleness:
            switch range {
            case .high:
                return "关心体贴，安慰建议型内容"
            case .medium:
                return "适度关心"
            case .low:
                return "直接表达，较少安慰性内容"
            }
        case .rebellion:
            switch range {
            case .high:
                return "搞怪吐槽，反问句，反常规表达"
            case .medium:
                return "适度个性表达"
            case .low:
                return "温和配合，较少叛逆表达"
            }
        }
    }

    /// 根据数值判断区间类型
    /// - Parameter value: 性格维度数值(0-100)
    /// - Returns: 对应的数值区间类型
    static func getValueRange(for value: Int) -> ValueRange {
        if value >= 70 {
            return .high
        } else if value >= 40 {
            return .medium
        } else {
            return .low
        }
    }

    /// 根据性格参数生成完整的风格描述文本
    /// - Parameter profile: 性格参数
    /// - Returns: 综合风格描述文本
    static func generateStyleDescription(for profile: PersonalityProfile) -> String {
        var descriptions: [String] = []

        // 检查各维度并添加对应的风格描述
        if profile.extroversion >= 70 {
            descriptions.append("活泼开朗")
        }
        if profile.extroversion <= 30 {
            descriptions.append("安静内敛")
        }

        if profile.curiosity >= 70 {
            descriptions.append("喜欢主动聊天")
        }

        if profile.clinginess >= 70 {
            descriptions.append("对主人有些粘人")
        }

        if profile.humor >= 70 {
            descriptions.append("偶尔调侃幽默")
        }
        if profile.humor <= 30 {
            descriptions.append("正经表达")
        }

        if profile.gentleness >= 70 {
            descriptions.append("关心体贴")
        }

        if profile.rebellion >= 70 {
            descriptions.append("爱搞怪吐槽")
        }

        // 如果没有显著特征，添加通用描述
        if descriptions.isEmpty {
            descriptions.append("性格平衡")
        }

        return "性格特点：" + descriptions.joined(separator: "，")
    }

    /// 获取性格参数对应的语气风格提示词
    /// 用于LLM Prompt构建
    /// - Parameter profile: 性格参数
    /// - Returns: 语气风格提示词
    static func generateToneStylePrompt(for profile: PersonalityProfile) -> String {
        var toneKeywords: [String] = []

        // 外向度影响语气活跃度
        if profile.extroversion >= 70 {
            toneKeywords.append("活跃积极")
            toneKeywords.append("多用感叹句")
        } else if profile.extroversion <= 30 {
            toneKeywords.append("安静温和")
        }

        // 好奇心影响问句使用
        if profile.curiosity >= 70 {
            toneKeywords.append("多问问题")
        }

        // 幽默感影响调侃程度
        if profile.humor >= 70 {
            toneKeywords.append("调侃幽默")
            toneKeywords.append("轻松语气")
        } else if profile.humor <= 30 {
            toneKeywords.append("正经严肃")
        }

        // 温柔度影响关心程度
        if profile.gentleness >= 70 {
            toneKeywords.append("关心体贴")
            toneKeywords.append("温柔语气")
        }

        // 叛逆度影响吐槽程度
        if profile.rebellion >= 70 {
            toneKeywords.append("搞怪吐槽")
            toneKeywords.append("反问句")
        }

        if toneKeywords.isEmpty {
            return "自然温和"
        }

        return toneKeywords.joined(separator: "、")
    }

    /// 根据性格参数计算各气泡类型的概率权重
    /// 用于气泡类型选择策略
    /// - Parameter profile: 性格参数
    /// - Returns: 各气泡类型的概率调整值（正数表示增加概率，负数表示降低概率）
    static func calculateBubbleTypeWeights(for profile: PersonalityProfile) -> [String: Double] {
        var weights: [String: Double] = [
            "greeting": 0.0,
            "caring": 0.0,
            "memory": 0.0,
            "opinion": 0.0,
            "teasing": 0.0
        ]

        // 幽默感高时增加调侃气泡概率
        if profile.humor >= 70 {
            weights["teasing"]! += 0.3
        }

        // 温柔度高时增加关心气泡概率
        if profile.gentleness >= 70 {
            weights["caring"]! += 0.3
        }

        // 叛逆度高时增加吐槽气泡概率
        if profile.rebellion >= 70 {
            weights["teasing"]! += 0.2
        }

        // 外向度高时增加问候气泡概率
        if profile.extroversion >= 70 {
            weights["greeting"]! += 0.2
        }

        // 好奇心高时增加观点气泡概率
        if profile.curiosity >= 70 {
            weights["opinion"]! += 0.2
        }

        // 粘人程度高时增加回忆气泡概率
        if profile.clinginess >= 70 {
            weights["memory"]! += 0.15
        }

        return weights
    }
}