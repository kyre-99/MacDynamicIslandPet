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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
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

    // MARK: - 语音配置状态
    @State private var speechEnabled: Bool = false
    @State private var bubbleSpeechEnabled: Bool = true
    @State private var conversationSpeechEnabled: Bool = false
    @State private var selectedVoice: SpeechService.CosyVoice = .longanhuan
    @State private var selectedSpeed: SpeechService.TTSSpeed = .normal
    @State private var selectedModel: SpeechService.TTSModel = .cosyvoice_v3_flash
    @State private var speechVolume: Double = 0.8
    @State private var isTestingSpeech: Bool = false
    // TTS API 配置（独立于 LLM API）
    @State private var ttsApiKey: String = ""
    @State private var ttsApiBaseUrl: String = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/"

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

            // MARK: - 语音设置分隔线
            Divider()
                .padding(.vertical, 8)

            // MARK: - 语音设置部分
            Text("语音设置")
                .font(.headline)
                .padding(.bottom, 4)

            // 语音总开关
            HStack {
                Toggle("启用语音", isOn: $speechEnabled)
                Spacer()
                if speechEnabled && !isTestingSpeech {
                    Button("测试语音") {
                        testSpeech()
                    }
                    .buttonStyle(.bordered)
                }
                if isTestingSpeech {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if speechEnabled {
                // TTS API Key（独立于 LLM API）
                VStack(alignment: .leading) {
                    Text("TTS API Key:")
                        .font(.subheadline)
                    SecureField("阿里云 DashScope API Key", text: $ttsApiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("语音合成使用阿里云 CosyVoice，需单独配置")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // TTS API URL
                VStack(alignment: .leading) {
                    Text("TTS API 地址:")
                        .font(.subheadline)
                    TextField("wss://dashscope.aliyuncs.com/api-ws/v1/inference/", text: $ttsApiBaseUrl)
                        .textFieldStyle(.roundedBorder)
                    Text("阿里云 DashScope WebSocket 地址")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Divider()
                    .padding(.vertical, 4)

                // 气泡语音开关
                HStack {
                    Toggle("气泡语音", isOn: $bubbleSpeechEnabled)
                    Text("精灵自言自语时播放语音")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // 对话窗口语音开关
                HStack {
                    Toggle("对话语音", isOn: $conversationSpeechEnabled)
                    Text("精灵回复时播放语音")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // 音色选择
                VStack(alignment: .leading) {
                    Text("音色:")
                        .font(.subheadline)

                    Picker("音色", selection: $selectedVoice) {
                        ForEach(SpeechService.CosyVoice.allCases, id: \.self) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(selectedVoice.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 语速选择
                VStack(alignment: .leading) {
                    Text("语速:")
                        .font(.subheadline)

                    Picker("语速", selection: $selectedSpeed) {
                        ForEach(SpeechService.TTSSpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 模型选择
                VStack(alignment: .leading) {
                    Text("TTS模型:")
                        .font(.subheadline)

                    Picker("模型", selection: $selectedModel) {
                        ForEach(SpeechService.TTSModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 音量调节
                VStack(alignment: .leading) {
                    Text("音量:")
                        .font(.subheadline)

                    HStack {
                        Slider(value: $speechVolume, in: 0...1)
                            .frame(width: 200)
                        Text("\(Int(speechVolume * 100))%")
                            .frame(width: 40)
                            .font(.caption)
                    }
                }
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
    .frame(minWidth: 450, minHeight: 400)
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

            // 加载语音配置
            speechEnabled = config.speechConfig.enabled
            bubbleSpeechEnabled = config.speechConfig.bubbleSpeechEnabled
            conversationSpeechEnabled = config.speechConfig.conversationSpeechEnabled
            ttsApiKey = config.speechConfig.ttsApiKey
            ttsApiBaseUrl = config.speechConfig.ttsApiBaseUrl
            if let voice = SpeechService.CosyVoice(rawValue: config.speechConfig.voice) {
                selectedVoice = voice
            } else {
                // Fallback: 处理旧的音色值格式（不带 _v3 后缀）
                // 尝试添加 _v3 后缀来匹配
                let voiceWithSuffix = config.speechConfig.voice + "_v3"
                if let fallbackVoice = SpeechService.CosyVoice(rawValue: voiceWithSuffix) {
                    selectedVoice = fallbackVoice
                    NSLog("🔊 SettingsView: Converted old voice format '%s' to '%s'", config.speechConfig.voice, voiceWithSuffix)
                } else {
                    // 最终 fallback: 使用龙呼呼（天真女童）
                    selectedVoice = .longhuhu
                    NSLog("🔊 SettingsView: Unknown voice '%s', fallback to longhuhu", config.speechConfig.voice)
                }
            }
            if let speed = SpeechService.TTSSpeed(rawValue: config.speechConfig.speed) {
                selectedSpeed = speed
            }
            if let model = SpeechService.TTSModel(rawValue: config.speechConfig.model) {
                selectedModel = model
            }
            speechVolume = config.speechConfig.volume
        }
    }

    private func saveConfig() {
        let speechConfig = SpeechConfig(
            enabled: speechEnabled,
            bubbleSpeechEnabled: bubbleSpeechEnabled,
            conversationSpeechEnabled: conversationSpeechEnabled,
            voice: selectedVoice.rawValue,
            speed: selectedSpeed.rawValue,
            model: selectedModel.rawValue,
            volume: speechVolume,
            ttsApiKey: ttsApiKey,
            ttsApiBaseUrl: ttsApiBaseUrl
        )

        let config = AppConfig(
            openaiApiKey: apiKey,
            apiBaseUrl: apiBaseUrl,
            modelName: modelName,
            visionModelName: visionModelName,
            maxTokens: Int(maxTokens) ?? 100,
            memoryRetentionDays: Int(memoryRetentionDays) ?? 30,
            personality: PersonalityProfile.defaultProfile,
            speechConfig: speechConfig
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
            // 通知 SpeechService 重新加载配置
            SpeechService.shared.loadConfig()
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

    private func testSpeech() {
        NSLog("🔴 testSpeech 按钮被点击! 开始测试语音...")
        isTestingSpeech = true

        // 检查配置是否已保存
        NSLog("🔴 当前配置: speechEnabled=%\(speechEnabled), ttsApiKey长度=%\(ttsApiKey.count)")

        if ttsApiKey.isEmpty {
            NSLog("🔴 TTS API Key 为空，请先保存配置!")
            isTestingSpeech = false
            let alert = NSAlert()
            alert.messageText = "配置未保存"
            alert.informativeText = "请先点击「保存」按钮保存语音配置，然后再测试语音。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }

        let testText = "你好呀，我是桌面小精灵！很高兴见到你~"
        NSLog("🔴 准备调用 SpeechService.shared.speak...")
        NSLog("🔴 文本: '%\(testText)'")
        NSLog("🔴 音色: %\(selectedVoice.rawValue)")
        NSLog("🔴 语速: %\(selectedSpeed.rawValue)")
        NSLog("🔴 模型: %\(selectedModel.rawValue)")

        SpeechService.shared.speak(
            text: testText,
            voice: selectedVoice,
            speed: selectedSpeed,
            model: selectedModel,
            completion: { result in
                NSLog("🔴 SpeechService completion 回调收到!")
                DispatchQueue.main.async {
                    self.isTestingSpeech = false
                    switch result {
                    case .success:
                        NSLog("🔴 测试语音播放成功!")
                        let alert = NSAlert()
                        alert.messageText = "语音测试成功"
                        alert.informativeText = "语音已成功播放！"
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "确定")
                        alert.runModal()
                    case .failure(let error):
                        NSLog("🔴 测试语音播放失败: %\(error.errorDescription ?? "unknown")")
                        let alert = NSAlert()
                        alert.messageText = "语音测试失败"
                        alert.informativeText = "错误: %\(error.errorDescription ?? "未知错误")"
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: "确定")
                        alert.runModal()
                    }
                }
            }
        )
        NSLog("🔴 SpeechService.shared.speak 已调用，等待回调...")
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