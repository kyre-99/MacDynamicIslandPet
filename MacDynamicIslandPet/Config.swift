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
        customRSSSources: nil
    )

    /// Validate the configuration
    func isValid() -> Bool {
        return !openaiApiKey.isEmpty &&
               !apiBaseUrl.isEmpty &&
               !modelName.isEmpty &&
               maxTokens > 0 &&
               memoryRetentionDays > 0 &&
               personality.isValid()
    }

    /// Get vision model name (fallback to modelName if not specified)
    func getVisionModelName() -> String {
        return visionModelName ?? modelName
    }
}