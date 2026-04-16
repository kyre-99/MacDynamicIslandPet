import SwiftUI
import AppKit

/// Settings window controller using NSWindowController for proper lifecycle management
class SettingsWindowController: NSWindowController {
    convenience init() {
        // 创建 SwiftUI 视图
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "小精灵设置"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("⚙️ SettingsWindowController created")
    }

    deinit {
        print("⚙️ SettingsWindowController deinit")
    }
}

/// Settings view for configuring LLM API and other options
struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var apiBaseUrl: String = "https://api.openai.com/v1"
    @State private var modelName: String = "gpt-4o-mini"
    @State private var maxTokens: String = "100"
    @State private var memoryRetentionDays: String = "30"
    @State private var visionModelName: String = "gpt-4o"
    @State private var saveMessage: String = ""
    @State private var showingSaveSuccess: Bool = false

    /// 用于取消异步任务的标记
    @State private var hideSuccessTask: Task<Void, Never>?

    private let configManager = AppConfigManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("小精灵智能吐槽设置")
                    .font(.headline)
                    .padding(.bottom, 8)

            // API Key
            VStack(alignment: .leading) {
                Text("API Key:")
                    .font(.subheadline)
                SecureField("输入API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            // API Base URL
            VStack(alignment: .leading) {
                Text("API地址:")
                    .font(.subheadline)
                TextField("https://api.openai.com/v1", text: $apiBaseUrl)
                    .textFieldStyle(.roundedBorder)
                Text("支持OpenAI、Azure或其他兼容API")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Model Name
            VStack(alignment: .leading) {
                Text("模型名称:")
                    .font(.subheadline)
                TextField("gpt-4o-mini", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                Text("推荐: gpt-4o-mini (快速), gpt-4o (高质量)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }



            // Vision Model Name
            VStack(alignment: .leading) {
                Text("视觉模型名称:")
                    .font(.subheadline)
                TextField("gpt-4o", text: $visionModelName)
                    .textFieldStyle(.roundedBorder)
                Text("用于屏幕分析，需要支持视觉的模型如 gpt-4o")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            // Max Tokens
            VStack(alignment: .leading) {
                Text("最大输出长度:")
                    .font(.subheadline)
                TextField("100", text: $maxTokens)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            // Memory Retention
            VStack(alignment: .leading) {
                Text("记忆保留天数:")
                    .font(.subheadline)
                TextField("30", text: $memoryRetentionDays)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            // Status message
            if showingSaveSuccess {
                Text(saveMessage)
                    .foregroundColor(.green)
                    .font(.subheadline)
            }

            HStack {
                Button("保存") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)

                Button("打开配置文件") {
                    openConfigFile()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("配置文件位置:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(AppConfigManager.configFilePath.path)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
    .frame(minWidth: 400, minHeight: 300)
    .onAppear {
        loadConfig()
    }
    .onDisappear {
        // 取消异步任务，防止窗口关闭后访问已释放内存
        hideSuccessTask?.cancel()
    }
}

    private func loadConfig() {
        if let config = configManager.config {
            apiKey = config.openaiApiKey
            apiBaseUrl = config.apiBaseUrl
            modelName = config.modelName
            maxTokens = String(config.maxTokens)
            memoryRetentionDays = String(config.memoryRetentionDays)
            visionModelName = config.visionModelName ?? "gpt-4o"
        }
    }

    private func saveConfig() {
        let config = AppConfig(
            openaiApiKey: apiKey,
            apiBaseUrl: apiBaseUrl,
            modelName: modelName,
            visionModelName: visionModelName,
            maxTokens: Int(maxTokens) ?? 100,
            memoryRetentionDays: Int(memoryRetentionDays) ?? 30,
            personality: PersonalityProfile.defaultProfile
        )

        do {
            let data = try JSONEncoder().encode(config)
            FileManager.default.createFile(
                atPath: AppConfigManager.configFilePath.path,
                contents: data,
                attributes: nil
            )
            configManager.loadConfig()
            // 通知 LLMService 重新加载配置
            LLMService.shared.loadConfig()
            saveMessage = "配置已保存!"
            showingSaveSuccess = true

            // 取消之前的任务
            hideSuccessTask?.cancel()

            // 使用 Task 替代 DispatchQueue，Task 会随视图销毁自动取消
            hideSuccessTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }
                showingSaveSuccess = false
            }
        } catch {
            saveMessage = "保存失败: \(error.localizedDescription)"
            showingSaveSuccess = true
        }
    }

    private func openConfigFile() {
        let configPath = AppConfigManager.configFilePath

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: configPath.path) {
            // Create default config if not exists
            saveConfig()
        }

        NSWorkspace.shared.open(configPath)
    }
}

#Preview {
    SettingsView()
}