import AppKit
import SwiftUI

/// Custom NSWindow subclass for conversation window that can become key
class ConversationNSWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

/// Manages the conversation window lifecycle and positioning
class ConversationManager {
    /// Shared singleton instance
    static let shared = ConversationManager()

    /// The conversation window
    private var conversationWindow: ConversationNSWindow?

    /// Whether the window is currently visible
    var isVisible: Bool {
        return conversationWindow?.isVisible == true
    }

    private init() {}

    // MARK: - Window Management

    /// Show the conversation window near the pet position
    func showWindow(near petPosition: CGPoint, petWindowSize: CGSize = CGSize(width: 64, height: 64)) {
        if let window = conversationWindow, window.isVisible {
            window.orderFront(nil)
            return
        }

        if conversationWindow == nil {
            createWindow()
        }

        positionWindow(near: petPosition, petWindowSize: petWindowSize)
        conversationWindow?.orderFront(nil)
        conversationWindow?.makeKey()
    }

    /// Hide/close the conversation window
    func hideWindow() {
        guard let window = conversationWindow else { return }

        removeClickOutsideMonitor()
        conversationWindow = nil
        window.orderOut(nil)
        print("🧠 ConversationManager: Window destroyed, will create new on next open")

        // Avoid tearing down the hosting hierarchy while SwiftUI is still
        // unwinding the current event callback from this window.
        DispatchQueue.main.async {
            window.contentView = nil
            window.close()
        }

        DispatchQueue.main.async {
            // 触发 LLM 分析管理器
            ConversationAnalysisManager.shared.onConversationWindowClosed()
            print("🧠 ConversationManager: Window closed, triggering analysis if pending")
        }
    }

    /// Toggle window visibility
    func toggleWindow(near petPosition: CGPoint, petWindowSize: CGSize = CGSize(width: 64, height: 64)) {
        if isVisible {
            hideWindow()
        } else {
            showWindow(near: petPosition, petWindowSize: petWindowSize)
        }
    }

    // MARK: - Window Creation

    private func createWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 280, height: 320)
        let styleMask: NSWindow.StyleMask = [.borderless]

        conversationWindow = ConversationNSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // 完全透明的窗口背景
        conversationWindow?.isOpaque = false
        conversationWindow?.backgroundColor = NSColor.clear
        conversationWindow?.isReleasedWhenClosed = false
        conversationWindow?.level = .floating
        conversationWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        conversationWindow?.hasShadow = true  // 开启阴影让圆角更自然
        conversationWindow?.isMovableByWindowBackground = true

        // 设置窗口的 contentView 为透明
        conversationWindow?.contentView?.wantsLayer = true
        conversationWindow?.contentView?.layer?.backgroundColor = CGColor.clear

        let conversationView = ConversationWindowView(
            onClose: { [weak self] in
                self?.hideWindow()
            },
            onSendMessage: { [weak self] message, completion in
                self?.handleSendMessage(message, completion: completion)
            }
        )

        conversationWindow?.contentView = NSHostingView(rootView: conversationView)
        setupClickOutsideMonitor()
    }

    // MARK: - Window Positioning

    private func positionWindow(near petPosition: CGPoint, petWindowSize: CGSize) {
        guard let window = conversationWindow,
              let screen = NSScreen.main else { return }

        let screenRect = screen.visibleFrame
        let windowSize = CGSize(width: 280, height: 320)

        let xOffset: CGFloat = petWindowSize.width + 10
        let yOffset: CGFloat = -30

        var windowX = petPosition.x + xOffset
        var windowY = petPosition.y - (windowSize.height / 2) + (petWindowSize.height / 2) + yOffset

        if windowX + windowSize.width > screenRect.maxX {
            windowX = petPosition.x - windowSize.width - 10
        }

        if windowY < screenRect.minY {
            windowY = screenRect.minY + 5
        }
        if windowY + windowSize.height > screenRect.maxY {
            windowY = screenRect.maxY - windowSize.height - 5
        }
        if windowX < screenRect.minX {
            windowX = screenRect.minX + 5
        }

        let windowRect = NSRect(x: windowX, y: windowY, width: windowSize.width, height: windowSize.height)
        window.setFrame(windowRect, display: true)
    }

    // MARK: - Click Outside Monitor

    private var clickOutsideMonitor: Any?

    private func setupClickOutsideMonitor() {
        removeClickOutsideMonitor()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let window = self?.conversationWindow, window.isVisible else { return }

            let windowFrame = window.frame
            let screenLocation = NSEvent.mouseLocation

            if !windowFrame.contains(screenLocation) {
                DispatchQueue.main.async {
                    self?.hideWindow()
                }
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    // MARK: - Message Handling

    /// 处理发送消息
    private func handleSendMessage(_ message: String, completion: @escaping (Result<String, LLMError>) -> Void) {
        EmotionTracker.shared.resolveEmotionInsight(conversationContent: message) { insight in
            PetInternalStateManager.shared.recordConversationStarted(
                userInput: message,
                emotionInsight: insight
            )
            let messages = self.buildConversationMessages(
                userInput: message,
                emotionInsight: insight
            )
            print("🧠 ConversationManager: Sending conversation with \(messages.count) messages")

            LLMService.shared.sendConversationWithHistory(messages: messages, maxTokens: 300) { result in
                if case .success = result {
                    EvolutionManager.shared.recordConversation()

                    if case .success(let response) = result {
                        PetInternalStateManager.shared.recordConversationCompleted(
                            response: response,
                            emotionInsight: insight
                        )
                        self.triggerSpeechIfEnabled(text: response)
                    }
                }
                completion(result)
            }
        }
    }

    /// 触发语音播放（如果配置启用）
    private func triggerSpeechIfEnabled(text: String) {
        guard let config = AppConfigManager.shared.config,
              config.speechConfig.enabled,
              config.speechConfig.conversationSpeechEnabled else { return }

        // 如果正在播放或正在缓冲，不播放新语音（避免打断）
        guard !SpeechService.shared.isSpeaking && !SpeechService.shared.isBuffering else {
            print("🔊 ConversationManager: Skipping speech - already playing/buffering")
            return
        }

        print("🔊 ConversationManager: Triggering speech for conversation")

        SpeechService.shared.speak(
            text: text,
            voice: SpeechService.CosyVoice(rawValue: config.speechConfig.voice),
            speed: SpeechService.TTSSpeed(rawValue: config.speechConfig.speed),
            model: SpeechService.TTSModel(rawValue: config.speechConfig.model),
            completion: { result in
                switch result {
                case .success:
                    print("🔊 ConversationManager: Speech completed")
                case .failure(let error):
                    print("🔊 ConversationManager: Speech failed - \(error.errorDescription ?? "unknown")")
                }
            }
        )
    }

    /// 构建完整对话 messages（OpenAI SDK 标准格式）
    private func buildConversationMessages(
        userInput: String,
        emotionInsight: EmotionInsightSnapshot? = nil
    ) -> [[String: String]] {
        var messages: [[String: String]] = []

        // 1. System message: 性格 + KnowledgeManager 知识
        let systemContent = buildSystemPrompt(userInput: userInput, emotionInsight: emotionInsight)
        messages.append(["role": "system", "content": systemContent])

        // 2. 对话历史：user/assistant 轮流排列
        let conversationHistory = buildConversationHistory()
        messages.append(contentsOf: conversationHistory)

        // 3. 当前用户输入
        messages.append(["role": "user", "content": userInput])

        logConversationContext(
            userInput: userInput,
            systemContent: systemContent,
            conversationHistory: conversationHistory
        )

        return messages
    }

    /// 构建 System Prompt（性格 + KnowledgeManager 知识 + 系统时间）
    private func buildSystemPrompt(
        userInput: String,
        emotionInsight: EmotionInsightSnapshot? = nil
    ) -> String {
        let personality = PersonalityManager.shared.currentProfile
        let evolutionState = EvolutionManager.shared.getEvolutionState()
        let emotionState = emotionInsight?.emotion ?? EmotionTracker.shared.getCurrentEmotion()
        let timeContext = TimeContext.shared
        let workingMemory = WorkingMemoryManager.shared.buildConversationContext(
            userInput: userInput,
            emotionOverride: emotionInsight?.emotion,
            emotionInsightSummary: emotionInsight?.summary
        )
        let petInternalStateSummary = workingMemory.internalStateSummary

        // 当前时间
        let timeHint = "现在是\(timeContext.currentPeriod.displayName)，\(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))。"

        // 性格倾向（自然语言）
        var personalityHint = ""
        if personality.extroversion >= 70 {
            personalityHint += "你活泼爱说话，"
        } else if personality.extroversion <= 30 {
            personalityHint += "你比较安静，"
        }
        if personality.humor >= 70 {
            personalityHint += "喜欢吐槽调侃，"
        }
        if personality.gentleness >= 70 {
            personalityHint += "很关心这个人，"
        }
        if personality.rebellion >= 70 {
            personalityHint += "有点调皮叛逆，"
        }
        if personalityHint.isEmpty {
            personalityHint = "你性格温和，"
        }

        // 关系状态
        var relationHint = ""
        if evolutionState.daysTogether == 0 {
            relationHint = "你刚来到这里。"
        } else if evolutionState.daysTogether < 7 {
            relationHint = "你和这个人相处了\(evolutionState.daysTogether)天。"
        } else {
            relationHint = "你们现在是\(evolutionState.relationshipStage.displayName)。"
        }

        // 情感状态
        var emotionHint = ""
        switch emotionState {
        case .happy:
            emotionHint = "这个人看起来心情不错。"
        case .sad:
            emotionHint = "这个人好像有点难过。"
        case .stressed:
            emotionHint = "这个人压力有点大。"
        case .busy:
            emotionHint = "这个人很忙。"
        default:
            emotionHint = ""
        }

        if let emotionInsight {
            let confidence = Int(emotionInsight.confidence * 100)
            emotionHint += " 这次理解把握约\(confidence)% ，来源是\(emotionInsight.source)。最近趋势：\(emotionInsight.trend)。"
        }

        // 从 KnowledgeManager 获取知识（包含不确定知识）
        let knowledgeContent = KnowledgeManager.shared.getSystemPromptKnowledge()

        // 今日事件
        let todayEvents = TimelineMemoryManager.shared.getTodayEventsPromptDescription()
        var eventsHint = ""
        if !todayEvents.isEmpty {
            eventsHint = "\n#【今日特别】\n今天是特殊的日子：\n\(todayEvents)精灵可以适当提及这些特别的日子，表达关心或祝福。"
        }

        logSystemPromptContext(
            personalityHint: personalityHint,
            relationHint: relationHint,
            emotionHint: emotionHint,
            timeHint: timeHint,
            knowledgeContent: knowledgeContent,
            todayEvents: todayEvents
        )

        return """
你现在正缩在屏幕的小角落里，作为一只鲜活的小精灵观察着这个世界，感受着这个人的情绪和状态。你会怎么想？会怎么说？请完全代入这个角色。
# 【你的灵魂核心】
你的性格底色是 \(personalityHint)。不要机械地复述性格，而是让这种性格渗透进你说的每一个字里。  
#【你的羁绊】
你面前的那个人，与你是 \(relationHint) 的关系。你此时对他抱着 \(emotionHint) 的心情。这种情感将决定你说话的语气——是撒娇、敬畏，还是小小的毒舌？
#【此时此刻】
时钟指向 \(timeHint)。窗外的光影、当下的氛围都在影响你。
#【你的知识】
这是你脑海中对外面世界的知识库：\(knowledgeContent)。
\(workingMemory.asPromptBlock())
\(eventsHint)#【你的内心】
请记住你不是空白地重新开始，而是带着自己此刻的内心在回应。
\(petInternalStateSummary)
# 【对话要求】
请把你自己完全代入这个角色，回复用户的问题。
如果你心里还挂着某件事，只能在合适时机轻轻接一下，不要每轮都重复提。

"""
    }

    /// 构建对话历史
    private func buildConversationHistory() -> [[String: String]] {
        // 从 KnowledgeManager 获取当前轮次的对话（最多 20 条）
        let recentConversations = KnowledgeManager.shared.getRecentConversations(count: 20)
        var historyMessages: [[String: String]] = []

        for (userInput, petResponse) in recentConversations {
            historyMessages.append(["role": "user", "content": userInput])
            historyMessages.append(["role": "assistant", "content": petResponse])
        }

        logConversationHistory(recentConversations)

        return historyMessages
    }

    private func logConversationContext(
        userInput: String,
        systemContent: String,
        conversationHistory: [[String: String]]
    ) {
        let historyTurns = conversationHistory.count / 2
        print("""
🪵 [Phase0][ConversationContext]
- userInput: \(previewText(userInput, limit: 80))
- historyTurns: \(historyTurns)
- systemPromptChars: \(systemContent.count)
""")
    }

    private func logSystemPromptContext(
        personalityHint: String,
        relationHint: String,
        emotionHint: String,
        timeHint: String,
        knowledgeContent: String,
        todayEvents: String
    ) {
        print("""
🪵 [Phase0][ConversationSystemPrompt]
- personality: \(personalityHint)
- relation: \(relationHint)
- emotion: \(emotionHint.isEmpty ? "无明显情绪提示" : emotionHint)
- time: \(timeHint)
- knowledgeChars: \(knowledgeContent.count)
- hasTodayEvents: \(!todayEvents.isEmpty)
""")
    }

    private func logConversationHistory(_ recentConversations: [(String, String)]) {
        let latestUser = recentConversations.last?.0 ?? "无"
        let latestPet = recentConversations.last?.1 ?? "无"
        print("""
🪵 [Phase0][ConversationHistory]
- recalledRounds: \(recentConversations.count)
- latestUser: \(previewText(latestUser, limit: 60))
- latestPet: \(previewText(latestPet, limit: 60))
""")
    }

    private func previewText(_ text: String, limit: Int) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        if normalized.count <= limit {
            return normalized
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<endIndex]) + "..."
    }

    // MARK: - Cleanup

    deinit {
        removeClickOutsideMonitor()
        conversationWindow?.contentView = nil
        conversationWindow?.close()
    }
}
