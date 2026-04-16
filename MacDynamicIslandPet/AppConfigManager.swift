import Foundation

/// Manages application configuration loading and validation
class AppConfigManager {
    static let shared = AppConfigManager()

    /// The loaded configuration (may be nil if not found or invalid)
    private(set) var config: AppConfig?

    /// Directory for config and memory files
    static let appSupportDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MacDynamicIslandPet")
    }()

    /// Path to the configuration file
    static let configFilePath: URL = {
        return appSupportDirectory.appendingPathComponent("config.json")
    }()

    /// Path to the template config file (bundled with app)
    var templateConfigPath: URL? {
        Bundle.main.url(forResource: "config.template", withExtension: "json")
    }

    private init() {
        loadConfig()
    }

    /// Load configuration from file
    func loadConfig() {
        // Ensure app support directory exists
        ensureDirectoryExists()

        let configPath = AppConfigManager.configFilePath

        // Check if config file exists - if not, create default config
        if !FileManager.default.fileExists(atPath: configPath.path) {
            print("⚠️ Config file not found, creating default config")
            createDefaultConfig()
            return
        }

        // Load and decode config
        do {
            let data = FileManager.default.contents(atPath: configPath.path)
            if let data = data {
                config = try JSONDecoder().decode(AppConfig.self, from: data)
                print("✅ Config loaded successfully from: \(configPath.path)")
            }
        } catch {
            print("⚠️ Failed to decode config: \(error.localizedDescription)")
            // Try to recreate default config if decode failed
            createDefaultConfig()
        }
    }

    /// Create default configuration file
    private func createDefaultConfig() {
        let defaultConfig = AppConfig.defaultConfig

        do {
            let data = try JSONEncoder().encode(defaultConfig)
            try data.write(to: AppConfigManager.configFilePath)
            config = defaultConfig
            print("✅ Default config created at: \(AppConfigManager.configFilePath.path)")
        } catch {
            config = defaultConfig  // At least use default in memory
            print("⚠️ Failed to create default config file: \(error.localizedDescription)")
        }
    }

    /// Check if configuration exists and is valid
    func isConfigValid() -> Bool {
        return config?.isValid() ?? false
    }

    /// Ensure the app support directory exists
    private func ensureDirectoryExists() {
        let dir = AppConfigManager.appSupportDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                print("📁 Created app support directory: \(dir.path)")
            } catch {
                print("⚠️ Failed to create app support directory: \(error.localizedDescription)")
            }
        }
    }

    /// Get the configuration status for display
    func getConfigStatus() -> ConfigStatus {
        let configPath = AppConfigManager.configFilePath

        if !FileManager.default.fileExists(atPath: configPath.path) {
            return .missing
        }

        if config?.isValid() ?? false {
            return .valid
        } else {
            return .invalid
        }
    }

    /// Save configuration to file
    /// - Parameter newConfig: The new configuration to save
    /// - Returns: Whether the save was successful
    func saveConfig(_ newConfig: AppConfig) -> Bool {
        ensureDirectoryExists()

        let configPath = AppConfigManager.configFilePath

        do {
            let data = try JSONEncoder().encode(newConfig)
            try data.write(to: configPath)
            config = newConfig
            print("✅ Config saved successfully to: \(configPath.path)")
            return true
        } catch {
            print("⚠️ Failed to save config: \(error.localizedDescription)")
            return false
        }
    }
}

/// Configuration status for UI display
enum ConfigStatus {
    case missing
    case invalid
    case valid

    var message: String {
        switch self {
        case .missing:
            return "Config file not found. Please create config.json from config.template.json."
        case .invalid:
            return "Config file is invalid. Please check API key and other settings."
        case .valid:
            return "Configuration loaded successfully."
        }
    }

    var showAlert: Bool {
        switch self {
        case .missing, .invalid:
            return true
        case .valid:
            return false
        }
    }
}