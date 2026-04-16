import Foundation

/// 性格参数结构体，定义精灵的6个性格维度
///
/// 每个维度使用0-100的数值范围：
/// - 0-30: 低值区间
/// - 40-60: 中值区间（默认值50）
/// - 70-100: 高值区间
///
/// 性格参数会影响精灵的对话风格、气泡内容、互动频率等行为
struct PersonalityProfile: Codable {
    /// 外向度 - 影响精灵主动互动的程度
    /// - 高值(70-100): 主动发起话题，多用感叹句，积极活跃
    /// - 中值(40-60): 根据情境适度互动
    /// - 低值(0-30): 安静内敛，较少主动发起互动
    var extroversion: Int

    /// 好奇心 - 影响精灵探索新话题的程度
    /// - 高值(70-100): 喜欢探索新话题，多问问题，对新鲜事物感兴趣
    /// - 中值(40-60): 对熟悉话题保持适度关注
    /// - 低值(0-30): 专注熟悉领域，较少提出新话题
    var curiosity: Int

    /// 粘人程度 - 影响精灵渴望与用户互动的程度
    /// - 高值(70-100): 高频互动，想念型内容，渴望陪伴
    /// - 中值(40-60): 适度互动需求
    /// - 低值(0-30): 独立自主，较少主动寻求互动
    var clinginess: Int

    /// 幽默感 - 影响精灵调侃和玩笑的程度
    /// - 高值(70-100): 调侃幽默，轻松语气，爱开玩笑
    /// - 中值(40-60): 适度幽默
    /// - 低值(0-30): 正经严肃，较少调侃
    var humor: Int

    /// 温柔度 - 影响精灵关心体贴的程度
    /// - 高值(70-100): 关心体贴，安慰建议型内容
    /// - 中值(40-60): 适度关心
    /// - 低值(0-30): 直接表达，较少安慰性内容
    var gentleness: Int

    /// 叛逆度 - 影响精灵搞怪吐槽的程度
    /// - 高值(70-100): 搞怪吐槽，反问句，反常规表达
    /// - 中值(40-60): 适度个性表达
    /// - 低值(0-30): 温和配合，较少叛逆表达
    var rebellion: Int

    /// 默认性格参数 - 所有维度设为50（中值）
    static let defaultProfile = PersonalityProfile(
        extroversion: 50,
        curiosity: 50,
        clinginess: 50,
        humor: 50,
        gentleness: 50,
        rebellion: 50
    )

    /// 验证性格参数是否在有效范围内
    /// - Returns: 是否所有维度都在0-100范围内
    func isValid() -> Bool {
        return extroversion >= 0 && extroversion <= 100 &&
               curiosity >= 0 && curiosity <= 100 &&
               clinginess >= 0 && clinginess <= 100 &&
               humor >= 0 && humor <= 100 &&
               gentleness >= 0 && gentleness <= 100 &&
               rebellion >= 0 && rebellion <= 100
    }

    /// 将性格参数值调整到有效范围内
    /// - Returns: 调整后的性格参数
    func clamped() -> PersonalityProfile {
        return PersonalityProfile(
            extroversion: max(0, min(100, extroversion)),
            curiosity: max(0, min(100, curiosity)),
            clinginess: max(0, min(100, clinginess)),
            humor: max(0, min(100, humor)),
            gentleness: max(0, min(100, gentleness)),
            rebellion: max(0, min(100, rebellion))
        )
    }

    /// 判断某个维度是否为高值(>=70)
    /// - Parameter dimension: 维度名称
    /// - Returns: 是否为高值
    func isHighValue(_ dimension: String) -> Bool {
        switch dimension {
        case "extroversion": return extroversion >= 70
        case "curiosity": return curiosity >= 70
        case "clinginess": return clinginess >= 70
        case "humor": return humor >= 70
        case "gentleness": return gentleness >= 70
        case "rebellion": return rebellion >= 70
        default: return false
        }
    }

    /// 判断某个维度是否为低值(<=30)
    /// - Parameter dimension: 维度名称
    /// - Returns: 是否为低值
    func isLowValue(_ dimension: String) -> Bool {
        switch dimension {
        case "extroversion": return extroversion <= 30
        case "curiosity": return curiosity <= 30
        case "clinginess": return clinginess <= 30
        case "humor": return humor <= 30
        case "gentleness": return gentleness <= 30
        case "rebellion": return rebellion <= 30
        default: return false
        }
    }

    /// 判断某个维度是否为中值(40-60)
    /// - Parameter dimension: 维度名称
    /// - Returns: 是否为中值
    func isMediumValue(_ dimension: String) -> Bool {
        switch dimension {
        case "extroversion": return extroversion >= 40 && extroversion <= 60
        case "curiosity": return curiosity >= 40 && curiosity <= 60
        case "clinginess": return clinginess >= 40 && clinginess <= 60
        case "humor": return humor >= 40 && humor <= 60
        case "gentleness": return gentleness >= 40 && gentleness <= 60
        case "rebellion": return rebellion >= 40 && rebellion <= 60
        default: return false
        }
    }
}