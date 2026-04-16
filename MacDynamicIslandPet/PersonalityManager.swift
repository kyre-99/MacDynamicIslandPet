import Foundation

/// 性格参数管理器，负责性格参数的加载、保存和管理
///
/// 提供以下功能：
/// - 获取默认性格参数
/// - 获取模板性格参数
/// - 保存性格参数到config.json
/// - 加载性格参数从config.json
///
/// 使用单例模式，通过 PersonalityManager.shared 访问
class PersonalityManager {
    /// 共享单例实例
    static let shared = PersonalityManager()

    /// 当前加载的性格参数
    private(set) var currentProfile: PersonalityProfile

    private init() {
        // 从AppConfigManager获取性格参数，如果不存在则使用默认值
        if let config = AppConfigManager.shared.config {
            currentProfile = config.personality
        } else {
            currentProfile = PersonalityProfile.defaultProfile
        }
    }

    /// 获取默认性格参数
    /// 所有维度均为50（中值区间）
    /// - Returns: 默认性格参数
    func getDefaultProfile() -> PersonalityProfile {
        return PersonalityProfile.defaultProfile
    }

    /// 获取指定模板的性格参数
    /// - Parameter template: 性格模板类型
    /// - Returns: 该模板的预设性格参数
    func getTemplateProfile(_ template: PersonalityTemplate) -> PersonalityProfile {
        return template.profile()
    }

    /// 获取所有可用模板的列表
    /// - Returns: 性格模板数组
    func getAllTemplates() -> [PersonalityTemplate] {
        return PersonalityTemplate.allTemplates
    }

    /// 保存性格参数到config.json
    /// - Parameter profile: 要保存的性格参数
    /// - Returns: 是否保存成功
    @discardableResult
    func saveProfile(_ profile: PersonalityProfile) -> Bool {
        // 确保性格参数在有效范围内
        let validProfile = profile.clamped()

        // 更新当前性格参数
        currentProfile = validProfile

        // 加载现有配置
        let configPath = AppConfigManager.configFilePath

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("⚠️ Config file not found, cannot save personality")
            return false
        }

        do {
            // 读取现有配置
            let data = FileManager.default.contents(atPath: configPath.path)
            guard let data = data else {
                print("⚠️ Failed to read config file")
                return false
            }

            // 解码现有配置
            var config = try JSONDecoder().decode(AppConfig.self, from: data)

            // 更新性格参数
            config.personality = validProfile

            // 重新编码并保存
            let newData = try JSONEncoder().encode(config)
            try newData.write(to: configPath)

            // 刷新AppConfigManager的配置
            AppConfigManager.shared.loadConfig()

            print("✅ Personality saved successfully: \(validProfile)")
            return true
        } catch {
            print("⚠️ Failed to save personality: \(error.localizedDescription)")
            return false
        }
    }

    /// 从config.json加载性格参数
    /// - Returns: 加载的性格参数，如果加载失败则返回默认值
    func loadProfile() -> PersonalityProfile {
        if let config = AppConfigManager.shared.config {
            currentProfile = config.personality.clamped()
            return currentProfile
        } else {
            currentProfile = PersonalityProfile.defaultProfile
            return currentProfile
        }
    }

    /// 应用性格模板
    /// 将指定模板的性格参数保存到config.json
    /// - Parameter template: 性格模板类型
    /// - Returns: 是否应用成功
    @discardableResult
    func applyTemplate(_ template: PersonalityTemplate) -> Bool {
        return saveProfile(template.profile())
    }

    /// 重置性格参数到默认值
    /// - Returns: 是否重置成功
    @discardableResult
    func resetToDefault() -> Bool {
        return saveProfile(PersonalityProfile.defaultProfile)
    }

    /// 获取当前性格的风格描述
    /// - Returns: 当前性格参数对应的风格描述文本
    func getCurrentStyleDescription() -> String {
        return PersonalityStyleMapping.generateStyleDescription(for: currentProfile)
    }

    /// 获取当前性格的语气风格提示词
    /// 用于LLM Prompt构建
    /// - Returns: 当前性格参数对应的语气风格提示词
    func getCurrentToneStyle() -> String {
        return PersonalityStyleMapping.generateToneStylePrompt(for: currentProfile)
    }

    /// 获取当前性格的气泡类型权重
    /// 用于气泡类型选择策略
    /// - Returns: 各气泡类型的概率调整值
    func getCurrentBubbleTypeWeights() -> [String: Double] {
        return PersonalityStyleMapping.calculateBubbleTypeWeights(for: currentProfile)
    }

    /// 检查性格参数是否为高活跃度
    /// 用于判断精灵是否应该主动发起互动
    /// - Returns: 外向度是否>=70
    func isHighlyActive() -> Bool {
        return currentProfile.extroversion >= 70
    }

    /// 检查性格参数是否为高粘人程度
    /// 用于判断精灵是否应该频繁互动
    /// - Returns: 粘人程度是否>=70
    func isHighlyClingy() -> Bool {
        return currentProfile.clinginess >= 70
    }

    /// 检查性格参数是否为高幽默感
    /// 用于判断精灵是否应该使用调侃风格
    /// - Returns: 幽默感是否>=70
    func isHighlyHumorous() -> Bool {
        return currentProfile.humor >= 70
    }

    /// 检查性格参数是否为高温柔度
    /// 用于判断精灵是否应该使用关心风格
    /// - Returns: 温柔度是否>=70
    func isHighlyGentle() -> Bool {
        return currentProfile.gentleness >= 70
    }

    /// 检查性格参数是否为高叛逆度
    /// 用于判断精灵是否应该使用吐槽风格
    /// - Returns: 叛逆度是否>=70
    func isHighlyRebellious() -> Bool {
        return currentProfile.rebellion >= 70
    }
}