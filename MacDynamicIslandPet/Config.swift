import Foundation

/// Configuration for the pet's conversation and memory features
struct AppConfig: Codable {
    /// OpenAI API key for GPT calls
    var openaiApiKey: String

    /// API base URL (for custom endpoints, default: OpenAI)
    var apiBaseUrl: String

    /// Model name to use for text generation (e.g., "gpt-4o-mini", "gpt-4o")
    var modelName: String

    /// Vision model name for screen analysis (e.g., "gpt-4o", "gpt-4-vision-preview")
    /// Must support multimodal input
    var visionModelName: String?

    /// Maximum tokens for API responses
    var maxTokens: Int

    /// Number of days to retain conversation memory
    var memoryRetentionDays: Int

    /// Personality profile for the sprite
    /// Contains 6 personality dimensions that affect dialogue style
    var personality: PersonalityProfile

    /// News interests configuration (US-010)
    /// Array of news categories the sprite is interested in
    var newsInterests: [String]?

    /// Custom RSS sources (US-011)
    /// Array of custom RSS URLs for autonomous thinking
    var customRSSSources: [String]?

    /// Speech synthesis configuration
    /// Controls TTS voice settings for the girl sprite
    var speechConfig: SpeechConfig

    /// Default configuration with placeholder values
    static let defaultConfig = AppConfig(
        openaiApiKey: "",
        apiBaseUrl: "https://api.openai.com/v1",
        modelName: "gpt-4o-mini",
        visionModelName: "gpt-4o",
        maxTokens: 100,
        memoryRetentionDays: 30,
        personality: PersonalityProfile.defaultProfile,
        newsInterests: ["科技", "娱乐", "游戏"],  // Default: tech, entertainment, games
        customRSSSources: nil,
        speechConfig: SpeechConfig.defaultConfig  // 语音配置（女孩精灵默认用龙呼呼音色）
    )

    /// Validate the configuration
    func isValid() -> Bool {
        return !openaiApiKey.isEmpty &&
               !apiBaseUrl.isEmpty &&
               !modelName.isEmpty &&
               maxTokens > 0 &&
               memoryRetentionDays > 0 &&
               personality.isValid() &&
               speechConfig.isValid()
    }

    /// Get vision model name (fallback to modelName if not specified)
    func getVisionModelName() -> String {
        return visionModelName ?? modelName
    }
}

// MARK: - Speech Configuration

/// 语音配置结构
struct SpeechConfig: Codable {
    var enabled: Bool                    // 总开关
    var bubbleSpeechEnabled: Bool        // 气泡语音开关
    var conversationSpeechEnabled: Bool  // 对话窗口语音开关
    var voice: String                    // 音色（默认龙呼呼 - 天真女童）
    var speed: Int                       // 语速 (50/100/150)
    var model: String                    // TTS模型
    var volume: Double                   // 音量 0.0-1.0

    // TTS API 配置（独立于 LLM API）
    var ttsApiKey: String                // TTS API Key（阿里云 DashScope）
    var ttsApiBaseUrl: String            // TTS API 地址

    /// 默认配置 - 精灵是女孩，使用龙呼呼音色（天真女童，需要 _v3 后缀）
    static let defaultConfig = SpeechConfig(
        enabled: false,
        bubbleSpeechEnabled: true,
        conversationSpeechEnabled: false,
        voice: "longhuhu_v3",       // 龙呼呼 - 天真女童（需要 _v3 后缀）
        speed: 100,
        model: "cosyvoice-v3-flash",
        volume: 0.8,
        ttsApiKey: "",
        ttsApiBaseUrl: "wss://dashscope.aliyuncs.com/api-ws/v1/inference/"
    )

    func isValid() -> Bool {
        return volume >= 0 && volume <= 1 && speed > 0 && speed <= 200
    }

    /// 检查 TTS 是否已配置（有 API Key）
    func isTTSConfigured() -> Bool {
        return !ttsApiKey.isEmpty
    }
}