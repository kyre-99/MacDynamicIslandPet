import Foundation
import AVFoundation
import Combine

/// 语音合成服务 - 使用阿里云 CosyVoice TTS API
/// 负责：
/// 1. 通过 WebSocket 调用阿里云 CosyVoice API
/// 2. 使用 AVAudioPlayer 播放音频
/// 3. 状态管理（播放中、缓冲中、停止）
class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    // MARK: - Published Properties
    @Published var isSpeaking: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentText: String = ""

    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var config: AppConfig?
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioDataBuffer: Data = Data()
    private var receivedAudioCompletion: ((Result<Void, SpeechError>) -> Void)?
    private var taskId: String = ""
    private let timeout: TimeInterval = 30.0
    private let sampleRate: Int = 22050

    // MARK: - CosyVoice 音色选项

    /// CosyVoice 音色（cosyvoice-v3-flash 模型）
    /// 注意：童声和方言音色需要 _v3 后缀，社交陪伴音色不需要
    enum CosyVoice: String, Codable, CaseIterable {
        // 社交陪伴（标杆音色）- 无 _v3 后缀
        case longanhuan = "longanhuan"      // 欢脱元气女（推荐）
        case longanyang = "longanyang"      // 阳光大男孩

        // 童声（标杆音色）- 需要 _v3 后缀
        case longhuhu = "longhuhu_v3"       // 天真烂漫女童（推荐）
        case longpaopao = "longpaopao_v3"   // 飞天泡泡音女童
        case longjielidou = "longjielidou_v3" // 阳光顽皮男童
        case longxian = "longxian_v3"       // 豪放可爱女童
        case longling = "longling_v3"       // 稚气呆板女童

        // 消费电子-儿童有声书 - 需要 _v3 后缀
        case longshanshan = "longshanshan_v3" // 戏剧化童声
        case longniuniu = "longniuniu_v3"   // 阳光男童声

        var displayName: String {
            switch self {
            case .longanhuan: return "龙安欢 (欢脱元气女)"
            case .longanyang: return "龙安洋 (阳光大男孩)"
            case .longhuhu: return "龙呼呼 (天真女童)"
            case .longpaopao: return "龙泡泡 (泡泡音女童)"
            case .longjielidou: return "龙杰力豆 (顽皮男童)"
            case .longxian: return "龙仙 (豪放可爱女童)"
            case .longling: return "龙铃 (稚气女童)"
            case .longshanshan: return "龙闪闪 (戏剧童声)"
            case .longniuniu: return "龙牛牛 (阳光男童)"
            }
        }

        var description: String {
            switch self {
            case .longanhuan: return "欢脱元气女，20~30岁"
            case .longanyang: return "阳光大男孩，20~30岁"
            case .longhuhu: return "天真烂漫女童，6~10岁（推荐精灵使用）"
            case .longpaopao: return "飞天泡泡音，6~15岁"
            case .longjielidou: return "阳光顽皮男，10岁"
            case .longxian: return "豪放可爱女，12岁"
            case .longling: return "稚气呆板女童，10岁"
            case .longshanshan: return "戏剧化童声，6~15岁"
            case .longniuniu: return "阳光男童声，6~15岁"
            }
        }
    }

    /// 语速选项
    enum TTSSpeed: Int, Codable, CaseIterable {
        case slow = 50     // 0.5x
        case normal = 100  // 1.0x
        case fast = 150    // 1.5x

        var displayName: String {
            switch self {
            case .slow: return "慢速 (0.5x)"
            case .normal: return "正常 (1.0x)"
            case .fast: return "快速 (1.5x)"
            }
        }

        var apiValue: Float {
            return Float(rawValue) / 100.0
        }
    }

    /// 模型选项
    enum TTSModel: String, Codable, CaseIterable {
        case cosyvoice_v3_flash = "cosyvoice-v3-flash"   // 快速（推荐）

        var displayName: String {
            switch self {
            case .cosyvoice_v3_flash: return "CosyVoice v3 Flash (快速)"
            }
        }
    }

    // MARK: - Initialization
    private override init() {
        super.init()
        loadConfig()
    }

    // MARK: - Configuration
    func loadConfig() {
        config = AppConfigManager.shared.config
    }

    func isConfigured() -> Bool {
        guard let config = config else { return false }
        return config.speechConfig.isTTSConfigured()
    }

    private func getTTSApiKey() -> String? {
        return config?.speechConfig.ttsApiKey
    }

    private func getTTSApiBaseUrl() -> String {
        return config?.speechConfig.ttsApiBaseUrl ?? "wss://dashscope.aliyuncs.com/api-ws/v1/inference/"
    }

    // MARK: - Speech Synthesis

    func speak(
        text: String,
        voice: CosyVoice? = nil,
        speed: TTSSpeed? = nil,
        model: TTSModel? = nil,
        completion: @escaping (Result<Void, SpeechError>) -> Void
    ) {
        NSLog("🔴🔴🔴 SpeechService.speak ENTERED - text: '\(text)'")
        NSLog("🔴🔴🔴 Called from thread: \(Thread.current.isMainThread ? "Main" : "Background")")

        stopSpeaking()
        NSLog("🔴🔴🔴 stopSpeaking() completed")

        // 重新加载配置
        loadConfig()

        guard let config = config else {
            NSLog("🔊 SpeechService: config is nil!")
            DispatchQueue.main.async {
                completion(.failure(.notConfigured))
            }
            return
        }

        NSLog("🔊 SpeechService: speechConfig.enabled=\(config.speechConfig.enabled), ttsApiKey=\(config.speechConfig.ttsApiKey.isEmpty ? "empty" : "set")")

        guard config.speechConfig.enabled else {
            NSLog("🔊 SpeechService: speech not enabled")
            DispatchQueue.main.async {
                completion(.failure(.notConfigured))
            }
            return
        }

        guard !config.speechConfig.ttsApiKey.isEmpty else {
            NSLog("🔊 SpeechService: ttsApiKey is empty")
            DispatchQueue.main.async {
                completion(.failure(.notConfigured))
            }
            return
        }

        let speechConfig = config.speechConfig
        var selectedVoice = voice ?? CosyVoice(rawValue: speechConfig.voice)

        // Fallback: 处理旧的音色值格式（不带 _v3 后缀）
        if selectedVoice == nil {
            let voiceWithSuffix = speechConfig.voice + "_v3"
            selectedVoice = CosyVoice(rawValue: voiceWithSuffix)
            if selectedVoice != nil {
                NSLog("🔊 SpeechService: Converted old voice format '%s' to '%s'", speechConfig.voice, voiceWithSuffix)
            }
        }

        // 最终 fallback: 使用龙安欢（社交陪伴音色，不需要 _v3 后缀）
        if selectedVoice == nil {
            selectedVoice = .longanhuan
            NSLog("🔊 SpeechService: Unknown voice '%s', fallback to longanhuan", speechConfig.voice)
        }

        // 此时 selectedVoice 必定不为 nil，强制解包
        let finalVoice = selectedVoice!
        let selectedSpeed = speed ?? TTSSpeed(rawValue: speechConfig.speed) ?? .normal
        let selectedModel = model ?? TTSModel(rawValue: speechConfig.model) ?? .cosyvoice_v3_flash

        NSLog("🔊 SpeechService: voice=\(finalVoice.rawValue), speed=\(selectedSpeed.apiValue), model=\(selectedModel.rawValue)")

        let trimmedText = String(text.prefix(4096))

        DispatchQueue.main.async {
            self.isBuffering = true
            self.currentText = trimmedText
        }

        receivedAudioCompletion = completion
        taskId = UUID().uuidString

        startWebSocketConnection(
            text: trimmedText,
            voice: finalVoice,
            speed: selectedSpeed,
            model: selectedModel
        )
    }

    /// 开始 WebSocket 连接
    private func startWebSocketConnection(
        text: String,
        voice: CosyVoice,
        speed: TTSSpeed,
        model: TTSModel
    ) {
        NSLog("🔴🔴🔴 startWebSocketConnection ENTERED")
        NSLog("🔴🔴🔴 Parameters: voice=\(voice.rawValue), speed=\(speed.apiValue), model=\(model.rawValue), text='\(text)'")

        guard let apiKey = getTTSApiKey(), !apiKey.isEmpty else {
            NSLog("🔴🔴🔴 ERROR: No API Key!")
            DispatchQueue.main.async {
                self.isBuffering = false
                self.receivedAudioCompletion?(.failure(.notConfigured))
                self.receivedAudioCompletion = nil
            }
            return
        }

        // 尝试两种认证方式：URL 参数（JavaScript demo 方式）和 Authorization header
        let urlString = getTTSApiBaseUrl()
        let cleanUrlString = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
        // JavaScript demo 使用 URL 参数：?api_key=xxx
        let urlWithApiKey = "\(cleanUrlString)?api_key=\(apiKey)"
        NSLog("🔴🔴🔴 URL with api_key: \(urlWithApiKey)")

        guard let url = URL(string: urlWithApiKey) else {
            NSLog("🔴🔴🔴 ERROR: Invalid URL string!")
            DispatchQueue.main.async {
                self.isBuffering = false
                self.receivedAudioCompletion?(.failure(.invalidURL))
                self.receivedAudioCompletion = nil
            }
            return
        }

        NSLog("🔴🔴🔴 Creating WebSocket request...")
        NSLog("🔴🔴🔴 URL is valid: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        // 同时设置 Authorization header（Python SDK 方式），双重认证
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        NSLog("🔴🔴🔴 Request created with URL param + Authorization header")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        NSLog("🔴🔴🔴 URLSession created")

        webSocketTask = session.webSocketTask(with: request)
        NSLog("🔴🔴🔴 WebSocketTask created")

        webSocketTask?.resume()
        NSLog("🔴🔴🔴 WebSocketTask resume() called - connection should start now")

        // 保存参数，等待 WebSocket 连接成功后再发送
        pendingVoice = voice
        pendingSpeed = speed
        pendingModel = model
        pendingText = text

        // 开始接收消息（等待连接）
        receiveWebSocketMessages()
    }

    // 待发送的参数
    private var pendingVoice: CosyVoice?
    private var pendingSpeed: TTSSpeed?
    private var pendingModel: TTSModel?
    private var pendingText: String?
    private var isTaskStarted: Bool = false  // 是否已收到 task-started

    /// 发送 continue-task 消息发送文本
    private func sendContinueTaskMessage(text: String) {
        NSLog("🔴🔴🔴 sendContinueTaskMessage - text: '\(text)'")
        // 参考 Python SDK 的 getContinueRequest 格式
        let continueMessage: [String: Any] = [
            "header": [
                "action": "continue-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "model": config?.speechConfig.model ?? "cosyvoice-v3-flash",
                "task_group": "audio",
                "task": "tts",
                "function": "SpeechSynthesizer",
                "input": [
                    "text": text
                ]
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: continueMessage)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            // JavaScript demo 发送字符串格式，不是二进制数据
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask?.send(message) { error in
                if let error = error {
                    NSLog("🔴🔴🔴 continue-task send error - \(error)")
                } else {
                    NSLog("🔴🔴🔴 Text sent (as STRING): '\(text)'")
                    // 发送 finish-task 结束任务
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.sendFinishTaskMessage()
                    }
                }
            }
        } catch {
            NSLog("🔴🔴🔴 continue-task JSON error")
        }
    }

    /// 发送 finish-task 结束任务
    private func sendFinishTaskMessage() {
        NSLog("🔴🔴🔴 sendFinishTaskMessage")
        // 参考 Python SDK 的 getFinishRequest 格式
        let finishMessage: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "model": config?.speechConfig.model ?? "cosyvoice-v3-flash",
                "task_group": "audio",
                "task": "tts",
                "function": "SpeechSynthesizer",
                "input": [:] as [String: Any]
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: finishMessage)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            // JavaScript demo 发送字符串格式
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask?.send(message) { error in
                if let error = error {
                    NSLog("🔴🔴🔴 finish-task send error - \(error)")
                } else {
                    NSLog("🔴🔴🔴 finish-task sent (as STRING)")
                }
            }
        } catch {
            NSLog("🔴🔴🔴 finish-task JSON error")
        }
    }

    /// 接收 WebSocket 消息
    private func receiveWebSocketMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    // PCM 音频数据
                    self.handlePCMData(data)
                    self.receiveWebSocketMessages()

                case .string(let text):
                    // 状态消息
                    self.handleTextMessage(text)
                    self.receiveWebSocketMessages()
                }

            case .failure(let error):
                print("🔊 SpeechService: WebSocket receive error - \(error)")
                self.finishAudioPlayback()
            }
        }
    }

    /// 处理 PCM 音频数据
    private func handlePCMData(_ data: Data) {
        print("🔊 SpeechService: Received PCM data, size: \(data.count) bytes")
        audioDataBuffer.append(data)
    }

    /// 处理文本状态消息
    private func handleTextMessage(_ text: String) {
        NSLog("🔴🔴🔴 Received text message: \(text)")

        do {
            if let json = try JSONSerialization.jsonObject(with: text.data(using: .utf8)!) as? [String: Any],
               let header = json["header"] as? [String: Any],
               let event = header["event"] as? String {

                switch event {
                case "task-started":
                    NSLog("🔴🔴🔴 Task started! Now sending text...")
                    isTaskStarted = true
                    // 收到 task-started 后发送文本
                    if let textToSend = self.pendingText {
                        sendContinueTaskMessage(text: textToSend)
                        self.pendingText = nil
                    }
                case "task-finished":
                    NSLog("🔴🔴🔴 Task finished")
                    finishAudioPlayback()
                default:
                    // 检查错误
                    if let errorCode = header["error_code"] as? Int, errorCode != 0 {
                        let errorMsg = header["error_message"] as? String ?? "Unknown error"
                        NSLog("🔴🔴🔴 Error - code: \(errorCode), message: \(errorMsg)")
                        self.handleError(.serverError(errorCode))
                    }
                }
            }
        } catch {
            NSLog("🔴🔴🔴 JSON parse error: \(error)")
        }
    }

    /// 处理错误
    private func handleError(_ error: SpeechError) {
        DispatchQueue.main.async {
            self.isBuffering = false
            self.isSpeaking = false
            self.receivedAudioCompletion?(.failure(error))
            self.receivedAudioCompletion = nil
        }
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
    }

    /// 完成音频播放
    private func finishAudioPlayback() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        DispatchQueue.main.async {
            self.isBuffering = false
        }

        if !audioDataBuffer.isEmpty {
            playPCMBuffer()
        } else {
            DispatchQueue.main.async {
                self.receivedAudioCompletion?(.failure(.noData))
                self.receivedAudioCompletion = nil
            }
        }
    }

    /// 播放 PCM 音频
    private func playPCMBuffer() {
        // 将 PCM 转换为 WAV 格式以便播放
        let wavData = convertPCMToWAV(pcmData: audioDataBuffer, sampleRate: sampleRate)
        audioDataBuffer = Data()

        DispatchQueue.main.async {
            self.isSpeaking = true
        }

        do {
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("🔊 SpeechService: Playing WAV audio, size: \(wavData.count) bytes")
        } catch {
            print("🔊 SpeechService: Audio player error - \(error)")
            DispatchQueue.main.async {
                self.isSpeaking = false
                self.receivedAudioCompletion?(.failure(.playbackError))
                self.receivedAudioCompletion = nil
            }
        }
    }

    /// 将 PCM 数据转换为 WAV 格式
    private func convertPCMToWAV(pcmData: Data, sampleRate: Int) -> Data {
        var wavData = Data()

        // WAV 文件头参数
        let numChannels: Int = 1
        let bitsPerSample: Int = 16
        let byteRate = sampleRate * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = pcmData.count
        let fileSize = dataSize + 44 - 8

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(uint32ToBytes(UInt32(fileSize)))
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(uint32ToBytes(UInt32(16))) // chunk size
        wavData.append(uint16ToBytes(UInt16(1)))  // audio format (PCM)
        wavData.append(uint16ToBytes(UInt16(numChannels)))
        wavData.append(uint32ToBytes(UInt32(sampleRate)))
        wavData.append(uint32ToBytes(UInt32(byteRate)))
        wavData.append(uint16ToBytes(UInt16(blockAlign)))
        wavData.append(uint16ToBytes(UInt16(bitsPerSample)))

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(uint32ToBytes(UInt32(dataSize)))
        wavData.append(pcmData)

        return wavData
    }

    /// 将 UInt32 转换为字节（小端序）
    private func uint32ToBytes(_ value: UInt32) -> Data {
        var bytes = Data(count: 4)
        bytes[0] = UInt8(value & 0xFF)
        bytes[1] = UInt8((value >> 8) & 0xFF)
        bytes[2] = UInt8((value >> 16) & 0xFF)
        bytes[3] = UInt8((value >> 24) & 0xFF)
        return bytes
    }

    /// 将 UInt16 转换为字节（小端序）
    private func uint16ToBytes(_ value: UInt16) -> Data {
        var bytes = Data(count: 2)
        bytes[0] = UInt8(value & 0xFF)
        bytes[1] = UInt8((value >> 8) & 0xFF)
        return bytes
    }

    // MARK: - Control

    func stopSpeaking() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        audioPlayer?.stop()
        audioPlayer = nil

        audioDataBuffer = Data()

        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isBuffering = false
            self.currentText = ""
            self.receivedAudioCompletion = nil
        }
        print("🔊 SpeechService: Speech stopped")
    }

    // MARK: - Estimated Duration

    func estimateDuration(text: String, speed: TTSSpeed) -> TimeInterval {
        let charCount = text.count
        let baseDuration = Double(charCount) / 150.0
        return baseDuration / Double(speed.apiValue)
    }

    /// 在 WebSocket 连接成功后发送消息（定义在类内部）
    private func sendRunTaskMessageAfterConnect(voice: CosyVoice, speed: TTSSpeed, model: TTSModel, text: String) {
        // 保存文本，等待 task-started 后再发送
        pendingText = text
        isTaskStarted = false

        // 阿里云 CosyVoice 正确的请求格式（参考 Python SDK）
        // 注意：model 必须在 payload 顶层，不在 parameters 里
        let runTaskMessage: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "model": model.rawValue,
                "task_group": "audio",
                "task": "tts",
                "function": "SpeechSynthesizer",
                "input": [:] as [String: Any],
                "parameters": [
                    "voice": voice.rawValue,
                    "volume": Int((config?.speechConfig.volume ?? 0.8) * 100),
                    "text_type": "PlainText",
                    "sample_rate": sampleRate,
                    "rate": speed.apiValue,
                    "format": "pcm",
                    "pitch": 1.0,
                    "seed": 0,
                    "type": 0
                ]
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: runTaskMessage)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "无法解析"
            NSLog("🔴🔴🔴 发送的 JSON: \(jsonString)")

            // JavaScript demo 发送的是字符串格式，不是二进制数据！
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask?.send(message) { error in
                if let error = error {
                    NSLog("🔴🔴🔴 run-task send error - \(error)")
                    self.handleError(.networkError(error.localizedDescription))
                } else {
                    NSLog("🔴🔴🔴 run-task sent successfully (as STRING), waiting for task-started event...")
                    // 不在这里发送文本，等待 task-started 事件后再发送
                }
            }
        } catch {
            NSLog("🔴🔴🔴 JSON encoding error - \(error)")
            handleError(.encodingError)
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension SpeechService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
        NSLog("🔴🔴🔴🔴 WebSocket CONNECTED SUCCESSFULLY! Protocol: \(proto ?? "none")")

        // WebSocket 连接成功，发送消息
        if let voice = pendingVoice, let speed = pendingSpeed, let model = pendingModel, let text = pendingText {
            NSLog("🔴🔴🔴🔴 Pending params found, sending run-task...")
            // 先清除 voice/speed/model，但保留 text（函数内部会设置）
            pendingVoice = nil
            pendingSpeed = nil
            pendingModel = nil
            // 不要在这里清除 pendingText！sendRunTaskMessageAfterConnect 内部会设置它
            sendRunTaskMessageAfterConnect(voice: voice, speed: speed, model: model, text: text)
        } else {
            NSLog("🔴🔴🔴🔴 ERROR: No pending params!")
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        NSLog("🔴🔴🔴 WebSocket CLOSED - code: \(closeCode.rawValue), reason: \(reason?.debugDescription ?? "none")")
        if isBuffering || isSpeaking {
            finishAudioPlayback()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("🔴🔴🔴 URLSession task completed with error: \(error?.localizedDescription ?? "none")")
        if let error = error {
            DispatchQueue.main.async {
                self.isBuffering = false
                self.receivedAudioCompletion?(.failure(.networkError(error.localizedDescription)))
                self.receivedAudioCompletion = nil
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension SpeechService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            if let completion = self.receivedAudioCompletion {
                completion(.success(()))
                self.receivedAudioCompletion = nil
            }
        }
        print("🔊 SpeechService: Audio finished playing")
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            if let completion = self.receivedAudioCompletion {
                completion(.failure(.playbackError))
                self.receivedAudioCompletion = nil
            }
        }
        print("🔊 SpeechService: Audio decode error")
    }
}

// MARK: - Speech Errors

enum SpeechError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidApiKey
    case rateLimited
    case serverError(Int)
    case invalidResponse
    case noData
    case playbackError
    case networkError(String)
    case encodingError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "语音服务未配置"
        case .invalidURL: return "无效的 API URL"
        case .invalidApiKey: return "无效的 API Key"
        case .rateLimited: return "请求频率限制"
        case .serverError(let code): return "服务器错误: \(code)"
        case .invalidResponse: return "无效的响应"
        case .noData: return "未收到音频数据"
        case .playbackError: return "音频播放错误"
        case .networkError(let msg): return "网络错误: \(msg)"
        case .encodingError: return "编码错误"
        case .unknownError: return "未知错误"
        }
    }
}