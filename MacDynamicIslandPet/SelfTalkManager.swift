import Foundation
import Combine
import AppKit

/// Manages self-talk triggers and timing for the pet
/// Triggers occur based on:
/// - Screen edge arrival
/// - Stationary for >5 minutes
/// - Random interval (10-15 min) with 30% probability
class SelfTalkManager: ObservableObject {
    static let shared = SelfTalkManager()

    // MARK: - Published Properties

    @Published var shouldShowBubble: Bool = false
    @Published var bubbleText: String = ""
    @Published var isGenerating: Bool = false

    // MARK: - Configuration

    /// Stationary threshold in seconds before triggering
    let stationaryThreshold: TimeInterval = 300.0  // 5 minutes

    /// Random trigger interval range
    var randomIntervalRange: ClosedRange<TimeInterval> = 600.0...900.0  // 10-15 minutes

    /// Probability of random trigger (0.0 to 1.0)
    var randomTriggerProbability: Double = 0.3  // 30% (可调整，US-007)

    /// Minimum cooldown between self-talks (to avoid spam)
    /// 增加冷却时间到90秒，防止气泡频繁出现
    var cooldownPeriod: TimeInterval = 90.0  // 1.5 minutes (可调整，US-007)

    /// 当前气泡显示开始时间（用于防止重复触发）
    private var bubbleDisplayStartTime: Date?

    /// 气泡最小显示时间（防止新气泡覆盖正在显示的气泡）
    /// 增加到15秒，确保气泡流式动画完成（最长12秒）+ 缓冲时间
    private let minBubbleDisplayTime: TimeInterval = 15.0

    /// 是否有气泡正在延迟等待显示（防止队列堆积）
    private var hasPendingBubble: Bool = false
    private var pendingBubbleText: String?

    // MARK: - Private Properties

    private var stationaryTimer: Timer?
    private var randomTriggerTimer: Timer?
    private var lastSelfTalkTime: Date = Date.distantPast
    private var currentPosition: CGPoint = .zero
    private var lastPosition: CGPoint = .zero
    private var lastPositionChangeTime: Date = Date()
    private var isNearEdge: Bool = false

    // Callbacks
    var onPositionUpdate: ((CGPoint) -> Void)?
    var onEdgeArrival: (() -> Void)?

    private init() {
        setupRandomTriggerTimer()
    }

    deinit {
        stationaryTimer?.invalidate()
        randomTriggerTimer?.invalidate()
    }

    // MARK: - Timer Setup

    /// Setup random trigger timer with random interval
    private func setupRandomTriggerTimer() {
        // Cancel existing timer
        randomTriggerTimer?.invalidate()

        // Set next trigger at random interval
        let nextInterval = TimeInterval.random(in: randomIntervalRange)

        randomTriggerTimer = Timer.scheduledTimer(
            withTimeInterval: nextInterval,
            repeats: false
        ) { [weak self] _ in
            self?.checkRandomTrigger()
            self?.setupRandomTriggerTimer()  // Schedule next
        }
        RunLoop.current.add(randomTriggerTimer!, forMode: .common)
    }

    /// Check if random trigger should fire
    private func checkRandomTrigger() {
        // Check cooldown
        if !isCooldownExpired() { return }

        // 30% chance to trigger
        if Double.random(in: 0...1) < randomTriggerProbability {
            triggerSelfTalk(reason: "random")
        }
    }

    // MARK: - Position Tracking

    /// Update current position and check triggers
    func updatePosition(_ position: CGPoint) {
        currentPosition = position

        // Check if position changed
        let distance = sqrt(pow(position.x - lastPosition.x, 2) +
                           pow(position.y - lastPosition.y, 2))

        if distance > 5.0 {  // More than 5 pixels movement
            lastPosition = position
            lastPositionChangeTime = Date()
            resetStationaryTimer()
        }

        // Check edge arrival
        checkEdgeArrival(position)
    }

    /// Check if pet has arrived at screen edge
    private func checkEdgeArrival(_ position: CGPoint) {
        guard let screen = NSScreen.main else { return }

        let frame = screen.frame
        let petSize: CGFloat = 64
        let edgeThreshold: CGFloat = 60.0  // Consider "at edge" if within 60px

        let nearLeftEdge = position.x < frame.minX + edgeThreshold
        let nearRightEdge = position.x > frame.maxX - petSize - edgeThreshold
        let nearBottomEdge = position.y < frame.minY + edgeThreshold
        let nearTopEdge = position.y > frame.maxY - petSize - edgeThreshold

        let currentlyNearEdge = nearLeftEdge || nearRightEdge || nearBottomEdge || nearTopEdge

        // Trigger if just arrived at edge (was not near, now is near)
        if currentlyNearEdge && !isNearEdge {
            if isCooldownExpired() {
                triggerSelfTalk(reason: "edge")
            }
        }

        isNearEdge = currentlyNearEdge
    }

    // MARK: - Stationary Timer

    /// Setup stationary timer
    func startStationaryMonitoring() {
        resetStationaryTimer()
    }

    /// Reset stationary timer (called when position changes)
    private func resetStationaryTimer() {
        stationaryTimer?.invalidate()

        stationaryTimer = Timer.scheduledTimer(
            withTimeInterval: stationaryThreshold,
            repeats: false
        ) { [weak self] _ in
            self?.checkStationaryTrigger()
        }
        RunLoop.current.add(stationaryTimer!, forMode: .common)
    }

    /// Check if stationary trigger should fire
    private func checkStationaryTrigger() {
        // Check cooldown
        if !isCooldownExpired() { return }

        // Verify pet is still stationary
        let stationaryTime = Date().timeIntervalSince(lastPositionChangeTime)
        if stationaryTime >= stationaryThreshold {
            triggerSelfTalk(reason: "stationary")
        }
    }

    // MARK: - Self-Talk Trigger

    /// Trigger self-talk generation
    /// 修复：使用 CommentGenerator.generateHumanoidBubble() 包含记忆、性格、进化等级
    private func triggerSelfTalk(reason: String) {
        // Don't trigger if already generating
        guard !isGenerating else { return }

        // Don't trigger if bubble is currently showing AND hasn't been shown for minimum time
        // This prevents new bubbles from cutting off current bubble too early
        if shouldShowBubble {
            if let startTime = bubbleDisplayStartTime {
                let displayTime = Date().timeIntervalSince(startTime)
                if displayTime < minBubbleDisplayTime {
                    print("🧠 SelfTalkManager: Bubble still showing (\(Int(displayTime))s), skipping trigger")
                    return
                }
            }
        }

        print("🧠 SelfTalkManager.triggerSelfTalk - reason: \(reason)")
        lastSelfTalkTime = Date()
        isGenerating = true
        PetInternalStateManager.shared.recordSelfTalkTriggered(reason: reason)

        // 确定触发场景
        let triggerScene: BubbleTriggerScene
        switch reason {
        case "edge":
            triggerScene = .edgeArrival
        case "stationary":
            triggerScene = .stationaryTimeout
        case "random":
            triggerScene = .random
        default:
            triggerScene = .random
        }

        logTriggerContext(reason: reason, triggerScene: triggerScene)
        print("🧠 SelfTalkManager: Using CommentGenerator with triggerScene: \(triggerScene.rawValue)")

        // 使用 CommentGenerator 生成气泡（包含记忆、性格、进化等级）
        CommentGenerator.shared.generateHumanoidBubble(triggerScene: triggerScene) { [weak self] result in
            DispatchQueue.main.async {
                self?.isGenerating = false

                switch result {
                case .success(let bubbleResult):
                    self?.showBubble(text: bubbleResult.content)

                    // 记录到感知记忆
                    let appName = WindowObserver.shared.currentActiveApp
                    PerceptionMemoryManager.shared.savePerception(
                        appName: appName,
                        activityDescription: "自言自语触发(\(reason))",
                        screenshotSummary: nil,
                        petReaction: bubbleResult.content
                    )

                    print("🧠 SelfTalkManager: Bubble generated with type: \(bubbleResult.type.displayName)")

                case .failure(let error):
                    print("🧠 SelfTalkManager: CommentGenerator failed - \(error.errorDescription ?? "unknown")")
                    // Use fallback text - 不播放语音，只显示气泡
                    let fallback = self?.fallbackText() ?? "..."
                    self?.showBubble(text: fallback, playSpeech: false)

                    // 记录fallback到记忆
                    let appName = WindowObserver.shared.currentActiveApp
                    PerceptionMemoryManager.shared.savePerception(
                        appName: appName,
                        activityDescription: "自言自语(fallback)",
                        screenshotSummary: nil,
                        petReaction: fallback
                    )
                }
            }
        }
    }

    private func logTriggerContext(reason: String, triggerScene: BubbleTriggerScene) {
        let activeApp = WindowObserver.shared.currentActiveApp
        let activeDuration = Int(WindowObserver.shared.activeAppDuration)
        let stationarySeconds = Int(Date().timeIntervalSince(lastPositionChangeTime))
        let cooldownRemaining = max(0, Int(cooldownPeriod - Date().timeIntervalSince(lastSelfTalkTime)))

        print("""
🪵 [Phase0][SelfTalkTrigger]
- reason: \(reason)
- triggerScene: \(triggerScene.rawValue)
- activeApp: \(activeApp)
- activeDurationSec: \(activeDuration)
- stationarySec: \(stationarySeconds)
- bubbleShowing: \(shouldShowBubble)
- cooldownRemainingSec: \(cooldownRemaining)
""")
    }

    /// Show bubble with generated text
    /// 修复：不再设置外部自动隐藏时间，让气泡视图自己控制消失
    /// - Parameters:
    ///   - text: 气泡文本
    ///   - playSpeech: 是否播放语音（默认 true，fallback 时设为 false）
    private func showBubble(text: String, playSpeech: Bool = true) {
        // 如果当前有气泡显示，先检查显示时间是否足够
        if shouldShowBubble {
            if let startTime = bubbleDisplayStartTime {
                let displayTime = Date().timeIntervalSince(startTime)
                if displayTime < minBubbleDisplayTime {
                    print("🧠 SelfTalkManager: Current bubble not shown long enough (\(Int(displayTime))s/\(Int(minBubbleDisplayTime))s), delaying new bubble")

                    // 如果已有待显示气泡，更新内容而不是新增
                    if hasPendingBubble {
                        print("🧠 SelfTalkManager: Updating pending bubble content")
                        pendingBubbleText = text
                        pendingPlaySpeech = playSpeech
                    } else {
                        hasPendingBubble = true
                        pendingBubbleText = text
                        pendingPlaySpeech = playSpeech
                        // 延迟显示新气泡
                        let delay = minBubbleDisplayTime - displayTime
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.showPendingBubble()
                        }
                    }
                    return
                }
            }
        }

        // 清除任何待显示的气泡（因为我们要立即显示新的）
        hasPendingBubble = false
        pendingBubbleText = nil
        pendingPlaySpeech = nil

        showBubbleInternal(text: text, playSpeech: playSpeech)
    }

    /// 待显示气泡是否播放语音
    private var pendingPlaySpeech: Bool?

    /// 显示待显示的气泡
    private func showPendingBubble() {
        guard hasPendingBubble, let text = pendingBubbleText, let playSpeech = pendingPlaySpeech else {
            hasPendingBubble = false
            pendingBubbleText = nil
            pendingPlaySpeech = nil
            return
        }

        hasPendingBubble = false
        pendingBubbleText = nil
        pendingPlaySpeech = nil

        // 再次检查当前气泡是否已经消失
        if shouldShowBubble {
            if let startTime = bubbleDisplayStartTime {
                let displayTime = Date().timeIntervalSince(startTime)
                if displayTime < minBubbleDisplayTime {
                    // 还没消失，继续等待
                    let remainingDelay = minBubbleDisplayTime - displayTime
                    print("🧠 SelfTalkManager: Still waiting for current bubble, remaining: \(Int(remainingDelay))s")
                    hasPendingBubble = true
                    pendingBubbleText = text
                    pendingPlaySpeech = playSpeech
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) {
                        self.showPendingBubble()
                    }
                    return
                }
            }
        }

        showBubbleInternal(text: text, playSpeech: playSpeech)
    }

    /// Internal method to show bubble (no delay checks)
    /// - Parameters:
    ///   - text: 气泡文本
    ///   - playSpeech: 是否播放语音（LLM生成时为true，fallback时为false）
    private func showBubbleInternal(text: String, playSpeech: Bool = true) {
        NSLog("🔴🔴🔴 showBubbleInternal - text: '\(text)', playSpeech: \(playSpeech)")
        bubbleText = text
        shouldShowBubble = true
        bubbleDisplayStartTime = Date()  // 记录显示开始时间

        // 触发语音播放（如果启用且是LLM生成的内容）
        if playSpeech {
            triggerSpeechIfEnabled(text: text)
        } else {
            print("🧠 SelfTalkManager: Skipping speech - fallback/preset text")
        }

        // US-007: 记录气泡显示
        let bubbleType = CommentGenerator.shared.currentComment.isEmpty ? "gentleTease" : "general"
        recordBubbleDisplay(bubbleType: bubbleType, content: text)

        print("🧠 SelfTalkManager: Bubble shown - '\(text)'")
        // 不再设置外部自动隐藏时间，让气泡视图的流式动画自己控制消失
    }

    /// 触发语音播放（如果配置启用）
    private func triggerSpeechIfEnabled(text: String) {
        let config = AppConfigManager.shared.config
        NSLog("🔴🔴🔴 triggerSpeechIfEnabled called - text: '\(text)'")
        NSLog("🔴🔴🔴 config exists: \(config != nil)")
        if let config = config {
            NSLog("🔴🔴🔴 speechConfig.enabled: \(config.speechConfig.enabled)")
            NSLog("🔴🔴🔴 speechConfig.bubbleSpeechEnabled: \(config.speechConfig.bubbleSpeechEnabled)")
            NSLog("🔴🔴🔴 speechConfig.voice: \(config.speechConfig.voice)")
            NSLog("🔴🔴🔴 speechConfig.ttsApiKey: \(config.speechConfig.ttsApiKey.isEmpty ? "empty" : "has value")")
        }

        guard let config = config,
              config.speechConfig.enabled,
              config.speechConfig.bubbleSpeechEnabled else {
            NSLog("🔴🔴🔴 Speech NOT triggered - config check failed")
            return
        }

        // 如果正在播放或正在缓冲，不播放新语音（避免打断）
        guard !SpeechService.shared.isSpeaking && !SpeechService.shared.isBuffering else {
            print("🔊 SelfTalkManager: Skipping speech - already playing/buffering")
            return
        }

        print("🔊 SelfTalkManager: Triggering speech for bubble")

        SpeechService.shared.speak(
            text: text,
            voice: SpeechService.CosyVoice(rawValue: config.speechConfig.voice),
            speed: SpeechService.TTSSpeed(rawValue: config.speechConfig.speed),
            model: SpeechService.TTSModel(rawValue: config.speechConfig.model),
            completion: { result in
                switch result {
                case .success:
                    print("🔊 SelfTalkManager: Speech completed")
                case .failure(let error):
                    print("🔊 SelfTalkManager: Speech failed - \(error.errorDescription ?? "unknown")")
                }
            }
        )
    }

    /// Hide bubble
    /// - Parameter stopSpeech: 是否停止语音播放（默认true，气泡自然消失时设为false）
    func hideBubble(stopSpeech: Bool = true) {
        print("🟣 SelfTalkManager.hideBubble() called - hiding bubble, stopSpeech: \(stopSpeech)")
        shouldShowBubble = false
        bubbleText = ""
        bubbleDisplayStartTime = nil  // 清除显示开始时间

        // 停止语音播放（只有用户主动关闭时才停止，气泡自然消失时让语音播放完成）
        if stopSpeech {
            SpeechService.shared.stopSpeaking()
            print("🟣 SelfTalkManager: Speech stopped")
        } else {
            print("🟣 SelfTalkManager: Letting speech continue playing")
        }

        // 清除待显示的气泡（当前气泡消失时，取消等待中的气泡）
        hasPendingBubble = false
        pendingBubbleText = nil

        // US-007: 记录气泡消失
        recordBubbleDismiss()
    }

    /// Check if cooldown period has expired
    private func isCooldownExpired() -> Bool {
        return Date().timeIntervalSince(lastSelfTalkTime) >= cooldownPeriod
    }

    /// Fallback text when LLM fails
    private func fallbackText() -> String {
        let fallbacks = [
            "好无聊呀~",
            "想吃零食...",
            "主人在哪里？",
            "有点困了~",
            "这里好安静",
            "走走走~"
        ]
        return fallbacks.randomElement() ?? "..."
    }

    // MARK: - Manual Trigger (for testing)

    /// Manually trigger self-talk (ignores cooldown)
    func forceTrigger() {
        triggerSelfTalk(reason: "manual")
    }

    // MARK: - Event Reminder (US-005)

    /// 显示事件提醒气泡
    /// - Parameters:
    ///   - content: 提醒内容
    ///   - eventType: 事件类型
    func showEventReminder(_ content: String, eventType: EventType) {
        // 设置气泡内容（不设置外部自动隐藏时间）
        DispatchQueue.main.async {
            self.bubbleText = content
            self.shouldShowBubble = true
            self.bubbleDisplayStartTime = Date()
            print("📅 Event reminder bubble set: \(content) (type: \(eventType.rawValue))")
        }
    }

    // MARK: - US-007: Interaction Pattern Integration

    /// 更新触发参数（由InteractionPatternManager调用）
    /// - Parameters:
    ///   - probability: 新的触发概率
    ///   - cooldown: 新的冷却时间
    func updateTriggerParameters(probability: Double, cooldown: TimeInterval) {
        randomTriggerProbability = probability
        cooldownPeriod = cooldown
        print("📊 SelfTalkManager: Updated trigger parameters - probability: \(probability), cooldown: \(cooldown)")
    }

    /// 记录气泡显示（US-007）
    /// - Parameters:
    ///   - bubbleType: 气泡类型
    ///   - content: 气泡内容
    func recordBubbleDisplay(bubbleType: String, content: String) {
        InteractionPatternManager.shared.recordBubbleShow(bubbleType: bubbleType, bubbleContent: content)
    }

    /// 记录气泡消失（US-007）
    func recordBubbleDismiss() {
        InteractionPatternManager.shared.recordBubbleDismiss()
    }

    /// 获取推荐的气泡类型（US-007）
    /// - Returns: 基于用户偏好的推荐气泡类型
    func getRecommendedBubbleType() -> String {
        return InteractionPatternManager.shared.getRecommendedBubbleType()
    }

    /// 检查当前是否是最佳互动时段（US-007）
    /// - Returns: 是否应该增加触发概率
    func isBestInteractionTime() -> Bool {
        return InteractionPatternManager.shared.isBestInteractionTime()
    }

    // MARK: - External Bubble Show API

    /// 外部模块显示气泡的统一接口
    /// 不设置自动隐藏时间，让气泡视图自己控制
    /// - Parameters:
    ///   - text: 气泡内容
    ///   - playSpeech: 是否播放语音（默认 true）
    func showExternalBubble(text: String, playSpeech: Bool = true) {
        // 检查当前气泡是否显示足够时间
        if shouldShowBubble {
            if let startTime = bubbleDisplayStartTime {
                let displayTime = Date().timeIntervalSince(startTime)
                if displayTime < minBubbleDisplayTime {
                    print("🧠 SelfTalkManager: Delaying external bubble, current showing for \(Int(displayTime))s")

                    // 如果已有待显示气泡，更新内容而不是新增
                    if hasPendingBubble {
                        print("🧠 SelfTalkManager: Updating pending external bubble content")
                        pendingBubbleText = text
                        pendingPlaySpeech = playSpeech
                    } else {
                        hasPendingBubble = true
                        pendingBubbleText = text
                        pendingPlaySpeech = playSpeech
                        // 延迟显示
                        let delay = minBubbleDisplayTime - displayTime
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.showPendingBubble()
                        }
                    }
                    return
                }
            }
        }

        // 清除任何待显示的气泡
        hasPendingBubble = false
        pendingBubbleText = nil
        pendingPlaySpeech = nil

        showBubbleInternal(text: text, playSpeech: playSpeech)
    }
}
