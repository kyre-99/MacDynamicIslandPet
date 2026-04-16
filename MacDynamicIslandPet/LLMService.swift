import Foundation

/// Structured result from visual analysis
/// US-004: Provides structured activity detection
struct VisualAnalysisResult: Codable {
    let activityType: String           // e.g., "programming", "browsing", "meeting"
    let mainWindow: String?            // 主要窗口描述
    let visibleText: String?           // 提取的关键文本
    let uiElements: String?            // 识别的 UI 元素
    let briefDescription: String       // 简述
    let userBehavior: String?          // 推断的用户行为
    let confidence: Double             // Confidence level (0.0-1.0)

    /// 获取详细的分析描述（用于生成气泡）
    var detailedDescription: String {
        var parts: [String] = [briefDescription]

        if let main = mainWindow, !main.isEmpty {
            parts.append("窗口：\(main)")
        }
        if let text = visibleText, !text.isEmpty {
            parts.append("可见文本：\(text)")
        }
        if let ui = uiElements, !ui.isEmpty {
            parts.append("界面：\(ui)")
        }
        if let behavior = userBehavior, !behavior.isEmpty {
            parts.append("行为：\(behavior)")
        }

        return parts.joined(separator: " | ")
    }
}

/// Service for interacting with OpenAI GPT API
/// US-004: Extended to support multimodal vision API
class LLMService {
    /// Shared singleton instance
    static let shared = LLMService()

    /// API configuration loaded from config
    private var config: AppConfig?

    /// Request timeout in seconds
    private let timeout: TimeInterval = 30.0

    private init() {
        loadConfig()
    }

    /// Load configuration from AppConfigManager
    func loadConfig() {
        config = AppConfigManager.shared.config
    }

    /// Check if the service is properly configured
    func isConfigured() -> Bool {
        return config?.isValid() ?? false
    }

    /// Send a chat message and get a response
    /// - Parameters:
    ///   - userMessage: The user's input message
    ///   - context: Optional context from memory (recent conversations)
    ///   - completion: Callback with result or error
    func sendMessage(
        userMessage: String,
        context: String? = nil,
        completion: @escaping (Result<String, LLMError>) -> Void
    ) {
        guard isConfigured() else {
            completion(.failure(.notConfigured))
            return
        }

        let messages = buildMessages(userMessage: userMessage, context: context)
        sendRequest(messages: messages, completion: completion)
    }

    /// 发送对话消息（带完整对话历史）
    /// 修复：使用标准OpenAI SDK格式（system + user/assistant对话历史）
    /// - Parameters:
    ///   - messages: 完整的消息数组，包含system prompt和对话历史
    ///   - maxTokens: 最大返回token数
    ///   - completion: 回调
    func sendConversationWithHistory(
        messages: [[String: String]],
        maxTokens: Int = 150,
        completion: @escaping (Result<String, LLMError>) -> Void
    ) {
        guard isConfigured() else {
            completion(.failure(.notConfigured))
            return
        }

        print("🟢 LLMService.sendConversationWithHistory: Messages count = \(messages.count)")
        sendRequest(messages: messages, maxTokens: maxTokens, completion: completion)
    }

    /// 发送自言自语（只用 system message）
    /// 修复：包含精灵信息 + 主人状态，让精灵自然发挥
    /// - Parameters:
    ///   - systemContent: System message 内容（精灵信息 + 主人状态 + 记忆）
    ///   - maxTokens: 最大返回 token 数
    ///   - completion: 回调
    func sendSelfTalkSystem(
        systemContent: String,
        maxTokens: Int = 50,
        completion: @escaping (Result<String, LLMError>) -> Void
    ) {
        guard isConfigured() else {
            completion(.failure(.notConfigured))
            return
        }

        // 只发送 system message
        let messages: [[String: String]] = [
            ["role": "system", "content": systemContent]
        ]

        print("🟢 LLMService.sendSelfTalkSystem: Single system message")
        sendRequest(messages: messages, maxTokens: maxTokens, completion: completion)
    }

    /// Generate a self-talk phrase (short, cute)
    /// DEPRECATED: 自言自语已使用 sendSelfTalkSystem() + CommentGenerator.buildSelfTalkSystemMessage()
    /// - Parameter completion: Callback with result or error
    func generateSelfTalk(completion: @escaping (Result<String, LLMError>) -> Void) {
        guard isConfigured() else {
            completion(.failure(.notConfigured))
            return
        }

        let messages = buildMessages(userMessage: "现在你在做什么呢？", context: nil)
        sendRequest(messages: messages, completion: completion)
    }

    // MARK: - US-004: Vision Analysis

    /// Vision analysis system prompt
    private let visionAnalysisPrompt: String = """
请详细观察屏幕截图，提取以下信息。

## 任务
1. 判断活动类型（从选项中选择）
2. 详细描述屏幕内容
3. 识别关键 UI 元素和文本信息

## 活动类型选项
编程、浏览网页、看视频、听音乐、开会、聊天、写文档、玩游戏、阅读、购物、其他

## 分析维度
请从以下维度详细分析：
- **主要窗口**：识别主要的应用窗口及其内容
- **可见文本**：提取标题、关键文字内容（如文档标题、视频标题、聊天对象等）
- **UI 元素**：识别明显的 UI 元素（如播放按钮、代码编辑器、视频播放器、聊天对话框等）
- **颜色/布局**：简要描述界面颜色和布局特征
- **用户行为推断**：根据屏幕内容推断用户可能在做什么

## 输出格式（严格按此 JSON 格式）
{
    "activityType": "活动类型",
    "mainWindow": "主要窗口描述",
    "visibleText": "提取的关键文本",
    "uiElements": "识别的 UI 元素",
    "briefDescription": "简述（综合分析，生动描述用户正在做什么）",
    "userBehavior": "推断的用户行为"
}

## 示例
{
    "activityType": "编程",
    "mainWindow": "Xcode 编辑器窗口",
    "visibleText": "ContentView.swift, struct PetViewxxxx",
    "uiElements": "代码编辑器、行号、语法高亮、左侧文件导航器",
    "briefDescription": "主人正在用 Xcode 写 Swift 代码，编辑的是 ContentView.swift 文件",
    "userBehavior": "正在编写或调试 SwiftUI 代码"
}
"""

    /// Analyze a screenshot with vision API (multimodal)
    /// - Parameters:
    ///   - imageBase64: Base64 encoded image (JPEG)
    ///   - appName: Current active application name (for fallback context)
    ///   - completion: Callback with structured analysis result
    func analyzeScreenWithVision(
        imageBase64: String,
        appName: String? = nil,
        completion: @escaping (Result<VisualAnalysisResult, LLMError>) -> Void
    ) {
        print("🟣 LLMService.analyzeScreenWithVision: Starting analysis")

        guard isConfigured() else {
            print("🟣 LLMService.analyzeScreenWithVision: NOT CONFIGURED")
            completion(.failure(.notConfigured))
            return
        }

        guard let config = config else {
            print("🟣 LLMService.analyzeScreenWithVision: No config")
            completion(.failure(.notConfigured))
            return
        }

        print("🟣 LLMService.analyzeScreenWithVision: Config OK, apiBaseUrl=\(config.apiBaseUrl), visionModel=\(config.getVisionModelName())")

        // Build multimodal message with image
        let messages = buildVisionMessages(imageBase64: imageBase64, appName: appName)

        // Build request body with vision support - use vision model
        let requestBody: [String: Any] = [
            "model": config.getVisionModelName(),  // Use vision-capable model
            "messages": messages,
            "max_tokens": 150,
            "temperature": 0.3  // Lower temperature for more consistent analysis
        ]

        guard let url = URL(string: config.apiBaseUrl + "/chat/completions") else {
            print("🟣 LLMService.analyzeScreenWithVision: Invalid URL")
            completion(.failure(.invalidURL))
            return
        }

        print("🟣 LLMService.analyzeScreenWithVision: URL = \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.openaiApiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.encodingError(error.localizedDescription)))
            return
        }

        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            if httpResponse.statusCode >= 400 {
                // Fallback to window-only analysis on error
                if let appName = appName {
                    let fallbackResult = self.analyzeFromAppName(appName)
                    completion(.success(fallbackResult))
                } else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let choices = json?["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    // Fallback on parse error
                    if let appName = appName {
                        let fallbackResult = self.analyzeFromAppName(appName)
                        completion(.success(fallbackResult))
                    } else {
                        completion(.failure(.parseError))
                    }
                    return
                }

                // Parse structured response
                let result = self.parseVisionResponse(content)
                completion(.success(result))
            } catch {
                // Fallback on error
                if let appName = appName {
                    let fallbackResult = self.analyzeFromAppName(appName)
                    completion(.success(fallbackResult))
                } else {
                    completion(.failure(.parseError))
                }
            }
        }

        task.resume()
    }

    /// Build vision messages with image content (OpenAI multimodal format)
    private func buildVisionMessages(imageBase64: String, appName: String?) -> [[String: Any]] {
        var messages: [[String: Any]] = []

        // System prompt
        messages.append(["role": "system", "content": visionAnalysisPrompt])

        // Build user message with image
        var userContent: [[String: Any]] = []

        // Text part
        var textContent = "请观察这个屏幕截图，分析用户正在做什么。"
        if let app = appName {
            textContent += " 当前活跃应用是: \(app)。"
        }
        userContent.append(["type": "text", "text": textContent])

        // Image part (OpenAI vision format)
        userContent.append([
            "type": "image_url",
            "image_url": [
                "url": "data:image/jpeg;base64,\(imageBase64)",
                "detail": "low"  // Use low detail for faster processing
            ]
        ])

        messages.append(["role": "user", "content": userContent])

        return messages
    }

    /// Parse vision response into structured result
    private func parseVisionResponse(_ content: String) -> VisualAnalysisResult {
        // 尝试解析 JSON 格式
        var activityType = "其他"
        var mainWindow: String?
        var visibleText: String?
        var uiElements: String?
        var briefDescription = "用户在电脑上活动"
        var userBehavior: String?

        do {
            // 尝试从字符串中提取 JSON 部分
            let jsonString = extractJSON(from: content)
            if let jsonData = jsonString.data(using: .utf8) {
                let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

                activityType = json?["activityType"] as? String ?? "其他"
                mainWindow = json?["mainWindow"] as? String
                visibleText = json?["visibleText"] as? String
                uiElements = json?["uiElements"] as? String
                briefDescription = json?["briefDescription"] as? String ?? "用户在电脑上活动"
                userBehavior = json?["userBehavior"] as? String

                // 验证活动类型是否有效
                let validTypes = ["编程", "浏览网页", "看视频", "听音乐", "开会", "聊天", "写文档", "玩游戏", "阅读", "购物", "其他"]
                if !validTypes.contains(activityType) {
                    activityType = "其他"
                }
            }
        } catch {
            print("LLMService: JSON parse error, falling back to line parsing")
        }

        // Fallback: 如果 JSON 解析失败，尝试行解析
        if mainWindow == nil || mainWindow?.isEmpty == true {
            let lines = content.split(separator: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("活动类型：") || trimmed.hasPrefix("活动类型:") {
                    activityType = trimmed.replacingOccurrences(of: "活动类型：", with: "")
                        .replacingOccurrences(of: "活动类型:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("简述：") || trimmed.hasPrefix("简述:") {
                    briefDescription = trimmed.replacingOccurrences(of: "简述：", with: "")
                        .replacingOccurrences(of: "简述:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return VisualAnalysisResult(
            activityType: activityType,
            mainWindow: mainWindow,
            visibleText: visibleText,
            uiElements: uiElements,
            briefDescription: briefDescription,
            userBehavior: userBehavior,
            confidence: 0.85
        )
    }

    /// Extract JSON from model response (handle markdown code blocks)
    private func extractJSON(from content: String) -> String {
        var jsonStr = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 移除 markdown 代码块标记
        if jsonStr.hasPrefix("```json") {
            jsonStr = jsonStr.replacingOccurrences(of: "```json", with: "")
        }
        if jsonStr.hasPrefix("```") {
            jsonStr = jsonStr.replacingOccurrences(of: "```", with: "")
        }
        if jsonStr.hasSuffix("```") {
            jsonStr = String(jsonStr.dropLast(3))
        }

        return jsonStr.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fallback analysis from app name only (when vision fails)
    private func analyzeFromAppName(_ appName: String) -> VisualAnalysisResult {
        let lowerName = appName.lowercased()

        var activityType = "其他"
        var briefDescription = "用户在使用\(appName)"

        // Simple heuristic based on app name
        if lowerName.contains("xcode") || lowerName.contains("vscode") || lowerName.contains("terminal") || lowerName.contains("iterm") {
            activityType = "编程"
            briefDescription = "主人在写代码呢~"
        } else if lowerName.contains("safari") || lowerName.contains("chrome") || lowerName.contains("firefox") || lowerName.contains("edge") {
            activityType = "浏览网页"
            briefDescription = "主人在浏览网页"
        } else if lowerName.contains("youtube") || lowerName.contains("netflix") || lowerName.contains("spotify") || lowerName.contains("music") {
            activityType = "看视频"
            briefDescription = "主人在看视频/听音乐"
        } else if lowerName.contains("zoom") || lowerName.contains("teams") || lowerName.contains("slack") || lowerName.contains("discord") {
            activityType = "开会"
            briefDescription = "主人在开会/聊天"
        } else if lowerName.contains("wechat") || lowerName.contains("telegram") || lowerName.contains("messages") {
            activityType = "聊天"
            briefDescription = "主人在聊天"
        } else if lowerName.contains("word") || lowerName.contains("pages") || lowerName.contains("notes") || lowerName.contains("notion") {
            activityType = "写文档"
            briefDescription = "主人在写文档"
        }

        return VisualAnalysisResult(
            activityType: activityType,
            mainWindow: nil,
            visibleText: nil,
            uiElements: nil,
            briefDescription: briefDescription,
            userBehavior: nil,
            confidence: 0.6  // Lower confidence for fallback
        )
    }

    /// Build messages array for API request
    /// 调用方需要在 userMessage 中构建完整的 prompt
    private func buildMessages(userMessage: String, context: String?) -> [[String: String]] {
        var messages: [[String: String]] = []

        // 不再自动添加 systemPrompt，调用方已在 userMessage 中构建完整 prompt

        // Add context from memory if available
        if let context = context, !context.isEmpty {
            messages.append(["role": "system", "content": "这是你最近和主人的对话记忆：\n\(context)"])
        }

        // User message (调用方已构建完整 prompt)
        messages.append(["role": "user", "content": userMessage])

        return messages
    }

    /// Send request to OpenAI API
    /// - Parameters:
    ///   - messages: 消息数组
    ///   - maxTokens: 最大token数（可选，默认使用config配置）
    ///   - completion: 回调
    private func sendRequest(
        messages: [[String: String]],
        maxTokens: Int? = nil,
        completion: @escaping (Result<String, LLMError>) -> Void
    ) {
        guard let config = config else {
            print("🔴 LLMService.sendRequest: No config - returning notConfigured")
            completion(.failure(.notConfigured))
            return
        }

        let tokenLimit = maxTokens ?? config.maxTokens
        print("🟢 LLMService.sendRequest: Starting request to \(config.apiBaseUrl)/chat/completions")
        print("🟢 LLMService.sendRequest: Model = \(config.modelName), Messages count = \(messages.count), maxTokens = \(tokenLimit)")

        // Build request body
        let requestBody: [String: Any] = [
            "model": config.modelName,
            "messages": messages,
            "max_tokens": tokenLimit,
            "temperature": 0.8  // Higher temperature for more creative responses
        ]

        guard let url = URL(string: config.apiBaseUrl + "/chat/completions") else {
            print("🔴 LLMService.sendRequest: Invalid URL")
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.openaiApiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("🔴 LLMService.sendRequest: Encoding error - \(error.localizedDescription)")
            completion(.failure(.encodingError(error.localizedDescription)))
            return
        }

        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network error
            if let error = error {
                print("🔴 LLMService.sendRequest: Network error - \(error.localizedDescription)")
                if (error as NSError).code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔴 LLMService.sendRequest: Invalid response")
                completion(.failure(.invalidResponse))
                return
            }

            print("🟢 LLMService.sendRequest: Response status code = \(httpResponse.statusCode)")

            // Handle error status codes
            if httpResponse.statusCode == 401 {
                print("🔴 LLMService.sendRequest: Invalid API key (401)")
                completion(.failure(.invalidApiKey))
                return
            }

            if httpResponse.statusCode == 429 {
                print("🔴 LLMService.sendRequest: Rate limited (429)")
                completion(.failure(.rateLimited))
                return
            }

            if httpResponse.statusCode >= 400 {
                print("🔴 LLMService.sendRequest: Server error (\(httpResponse.statusCode))")
                completion(.failure(.serverError(httpResponse.statusCode)))
                return
            }

            // Parse response
            guard let data = data else {
                print("🔴 LLMService.sendRequest: No data")
                completion(.failure(.noData))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let choices = json?["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    print("🔴 LLMService.sendRequest: Parse error - JSON structure unexpected")
                    completion(.failure(.parseError))
                    return
                }

                print("🟢 LLMService.sendRequest: SUCCESS - content = '\(content)'")
                completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                print("🔴 LLMService.sendRequest: Parse error - \(error.localizedDescription)")
                completion(.failure(.parseError))
            }
        }

        task.resume()
    }
}

/// Errors that can occur during LLM API calls
enum LLMError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case encodingError(String)
    case networkError(String)
    case timeout
    case invalidResponse
    case invalidApiKey
    case rateLimited
    case serverError(Int)
    case noData
    case parseError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API configuration is missing or invalid"
        case .invalidURL:
            return "Invalid API URL"
        case .encodingError(let detail):
            return "Failed to encode request: \(detail)"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .timeout:
            return "Request timed out (30 seconds)"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidApiKey:
            return "Invalid API key"
        case .rateLimited:
            return "Rate limited - too many requests"
        case .serverError(let code):
            return "Server error: \(code)"
        case .noData:
            return "No data received from server"
        case .parseError:
            return "Failed to parse response"
        }
    }
}