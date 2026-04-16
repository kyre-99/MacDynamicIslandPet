import Foundation

/// 性格模板枚举，提供5种预设性格配置
///
/// 每种模板代表一种典型的性格组合：
/// - energetic: 活泼型 - 主动活跃、喜欢探索、爱调侃
/// - gentle: 温柔型 - 关心体贴、温柔内敛
/// - rebellious: 叛逆型 - 搞怪吐槽、个性张扬
/// - scholar: 学者型 - 好学专注、正经表达
/// - introverted: 宅型 - 安静内敛、渴望陪伴
enum PersonalityTemplate: String, Codable, CaseIterable {
    /// 活泼型 - 外向度高、好奇心强、幽默感高
    /// 特点：主动活跃、喜欢探索新话题、爱调侃
    case energetic = "energetic"

    /// 温柔型 - 温柔度高、粘人程度高、幽默感低
    /// 特点：关心体贴、渴望陪伴、正经表达
    case gentle = "gentle"

    /// 叛逆型 - 叛逆度高、幽默感高、外向度高
    /// 特点：搞怪吐槽、爱开玩笑、个性张扬
    case rebellious = "rebellious"

    /// 学者型 - 好奇心极高、外向度低、温柔度适中
    /// 特点：好学专注、正经表达、稳重内敛
    case scholar = "scholar"

    /// 宅型 - 外向度低、粘人程度高、叛逆度适中
    /// 特点：安静内敛、渴望陪伴、独立又有依赖感
    case introverted = "introverted"

    /// 模板的本地化显示名称
    var displayName: String {
        switch self {
        case .energetic:
            return "活泼型"
        case .gentle:
            return "温柔型"
        case .rebellious:
            return "叛逆型"
        case .scholar:
            return "学者型"
        case .introverted:
            return "宅型"
        }
    }

    /// 模板的描述文字
    var description: String {
        switch self {
        case .energetic:
            return "主动活跃，喜欢探索新话题，爱调侃幽默"
        case .gentle:
            return "关心体贴，渴望陪伴，温柔内敛"
        case .rebellious:
            return "搞怪吐槽，爱开玩笑，个性张扬"
        case .scholar:
            return "好学专注，正经表达，稳重内敛"
        case .introverted:
            return "安静内敛，渴望陪伴，独立又有依赖感"
        }
    }

    /// 模板对应的预设性格参数
    /// - Returns: 该模板的PersonalityProfile配置
    func profile() -> PersonalityProfile {
        switch self {
        case .energetic:
            // 活泼型：外向度80、好奇心70、粘人程度60、幽默感75、温柔度50、叛逆度30
            return PersonalityProfile(
                extroversion: 80,
                curiosity: 70,
                clinginess: 60,
                humor: 75,
                gentleness: 50,
                rebellion: 30
            )
        case .gentle:
            // 温柔型：外向度40、好奇心60、粘人程度70、幽默感30、温柔度85、叛逆度10
            return PersonalityProfile(
                extroversion: 40,
                curiosity: 60,
                clinginess: 70,
                humor: 30,
                gentleness: 85,
                rebellion: 10
            )
        case .rebellious:
            // 叛逆型：外向度70、好奇心80、粘人程度30、幽默感85、温柔度20、叛逆度80
            return PersonalityProfile(
                extroversion: 70,
                curiosity: 80,
                clinginess: 30,
                humor: 85,
                gentleness: 20,
                rebellion: 80
            )
        case .scholar:
            // 学者型：外向度30、好奇心95、粘人程度40、幽默感40、温柔度60、叛逆度20
            return PersonalityProfile(
                extroversion: 30,
                curiosity: 95,
                clinginess: 40,
                humor: 40,
                gentleness: 60,
                rebellion: 20
            )
        case .introverted:
            // 宅型：外向度20、好奇心50、粘人程度80、幽默感60、温柔度70、叛逆度40
            return PersonalityProfile(
                extroversion: 20,
                curiosity: 50,
                clinginess: 80,
                humor: 60,
                gentleness: 70,
                rebellion: 40
            )
        }
    }

    /// 从字符串解析性格模板
    /// - Parameter string: 模板名称字符串
    /// - Returns: 对应的性格模板，如果无法解析则返回nil
    static func fromString(_ string: String) -> PersonalityTemplate? {
        return PersonalityTemplate(rawValue: string.lowercased())
    }

    /// 所有模板的数组，用于UI显示
    static var allTemplates: [PersonalityTemplate] {
        return PersonalityTemplate.allCases
    }

    /// 模板数量
    static var count: Int {
        return PersonalityTemplate.allCases.count
    }
}