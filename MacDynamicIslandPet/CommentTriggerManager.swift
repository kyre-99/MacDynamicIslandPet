import Foundation
import Combine

/// Manages multiple trigger conditions for generating comments
/// US-010: Multi-scene comment trigger mechanism
///
/// 合并后职责：
/// - 窗口切换触发（go-see 行为）
/// - 长时间使用触发（关心类气泡）
/// - 连续拍拍触发（回应气泡）
///
/// 已移除（由 SelfTalkManager 负责）：
/// - 边缘到达触发
/// - 静止超时触发
class CommentTriggerManager: ObservableObject {
    static let shared = CommentTriggerManager()

    // MARK: - Trigger Types

    enum TriggerType: String, CaseIterable {
        case windowSwitch      // 用户切换应用
        case longAppUsage      // 长时间在同一应用 (>15 分钟)
        case petPat            // 连续拍拍小精灵 (3 次)
    }

    // MARK: - Published Properties

    /// Current active trigger type
    @Published var currentTrigger: TriggerType?

    /// Whether any trigger is active
    @Published var isTriggerActive: Bool = false

    // MARK: - Private Properties

    private let windowObserver = WindowObserver.shared
    private let commentGenerator = CommentGenerator.shared
    private let selfTalkManager = SelfTalkManager.shared
    private let goSeeManager = GoSeeBehaviorManager.shared
    private let timeContext = TimeContext.shared
    private let perceptionMemory = PerceptionMemoryManager.shared

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cooldown Configuration

    /// Cooldown per trigger type (seconds)
    private var cooldowns: [TriggerType: TimeInterval] = [
        .windowSwitch: 30.0,
        .longAppUsage: 600.0,       // 10 minutes
        .petPat: 10.0
    ]

    /// Last trigger time per type
    private var lastTriggerTimes: [TriggerType: Date] = [:]

    /// Long app usage check timer
    private var longAppUsageTimer: Timer?

    /// Pet pat tracking
    private var petPatCount: Int = 0
    private var lastPetPatTime: Date = Date.distantPast

    /// Thresholds
    private let longAppUsageThreshold: TimeInterval = 900.0  // 15 minutes in same app
    private let petPatThreshold: Int = 3  // 3 pats to trigger
    private let petPatWindow: TimeInterval = 2.0  // pats must be within 2 seconds

    // MARK: - Initialization

    private init() {
        setupAllObservers()
    }

    deinit {
        longAppUsageTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupAllObservers() {
        // Window switch observer (triggers go-see)
        windowObserver.$currentActiveApp
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleWindowSwitchTrigger()
            }
            .store(in: &cancellables)

        // App duration observer for long usage
        windowObserver.$activeAppDuration
            .sink { [weak self] duration in
                self?.checkLongAppUsage(duration)
            }
            .store(in: &cancellables)
    }

    // MARK: - Trigger Handlers

    /// Check if cooldown has expired for a trigger type
    private func canTrigger(_ type: TriggerType) -> Bool {
        guard let lastTime = lastTriggerTimes[type] else { return true }
        let cooldown = cooldowns[type] ?? 60.0
        return Date().timeIntervalSince(lastTime) >= cooldown
    }

    /// Record trigger time
    private func recordTrigger(_ type: TriggerType) {
        lastTriggerTimes[type] = Date()
        currentTrigger = type
        isTriggerActive = true
    }

    /// Handle window switch trigger (go-see behavior)
    /// US-010: 用户切换应用时触发跑去看看行为
    private func handleWindowSwitchTrigger() {
        // This is primarily handled by GoSeeBehaviorManager
        // We just track it for cooldown purposes
        if canTrigger(.windowSwitch) {
            recordTrigger(.windowSwitch)
            print("CommentTrigger: Window switch detected (go-see handled separately)")
        }
    }

    /// Check long app usage
    /// US-010: 长时间（>15 分钟）在同一应用时触发关心类吐槽
    private func checkLongAppUsage(_ duration: TimeInterval) {
        guard duration >= longAppUsageThreshold else { return }
        guard canTrigger(.longAppUsage) else { return }
        guard !selfTalkManager.shouldShowBubble else { return }
        guard !goSeeManager.isGoSeeInProgress else { return }

        recordTrigger(.longAppUsage)

        // 使用拟人化气泡生成（包含性格、记忆、进化等级）
        commentGenerator.generateHumanoidBubble(
            triggerScene: .longAppUsage,
            bubbleType: .caring
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let bubbleResult):
                // 保存到感知记忆
                let appName = self.windowObserver.currentActiveApp
                self.perceptionMemory.savePerception(
                    appName: appName,
                    activityDescription: "连续使用\(appName)\(Int(duration / 60))分钟",
                    screenshotSummary: nil,
                    petReaction: bubbleResult.content
                )

                self.showTriggeredComment(bubbleResult.content, trigger: .longAppUsage)
                print("CommentTrigger: Long app usage (\(Int(duration / 60))min) - '\(bubbleResult.content)'")

            case .failure:
                print("CommentTrigger: Long app usage generation failed")
            }
        }
    }

    /// Handle pet pat trigger
    /// US-010: 连续拍拍小精灵时触发回应吐槽
    func handlePetPat() {
        let now = Date()
        let timeSinceLastPat = now.timeIntervalSince(lastPetPatTime)

        // Reset pat count if outside window
        if timeSinceLastPat > petPatWindow {
            petPatCount = 0
        }

        petPatCount += 1
        lastPetPatTime = now

        print("👋 CommentTrigger: Pet pat count = \(petPatCount)")

        // Check if threshold reached (3 pats within 2 seconds)
        if petPatCount >= petPatThreshold && canTrigger(.petPat) {
            recordTrigger(.petPat)

            // 使用拟人化气泡生成
            commentGenerator.generateHumanoidBubble(
                triggerScene: .random,  // 没有特定场景，用 random
                bubbleType: .teasing
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let bubbleResult):
                    // 保存到感知记忆
                    self.perceptionMemory.savePerception(
                        appName: "小精灵自身",
                        activityDescription: "被连续拍拍\(self.petPatCount)次",
                        screenshotSummary: nil,
                        petReaction: bubbleResult.content
                    )

                    self.showTriggeredComment(bubbleResult.content, trigger: .petPat)
                    print("CommentTrigger: Pet pat (\(self.petPatCount) pats) - '\(bubbleResult.content)'")

                case .failure:
                    // Fallback 到简单回应
                    let fallbackComments = [
                        "拍拍好舒服~",
                        "好痒好痒~",
                        "别拍了别拍了~",
                        "我又不是玩具~",
                        "拍上瘾了~"
                    ]
                    let fallback = fallbackComments.randomElement() ?? "别拍啦~"
                    self.showTriggeredComment(fallback, trigger: .petPat)
                }
            }

            // Reset pat count after trigger
            petPatCount = 0
        }
    }

    // MARK: - Comment Display

    private func showTriggeredComment(_ comment: String, trigger: TriggerType) {
        // 使用统一接口显示气泡，不设置自定义隐藏时间
        // 让气泡视图的流式动画自己控制消失
        selfTalkManager.showExternalBubble(text: comment)

        isTriggerActive = true
        currentTrigger = trigger

        // 不再使用外部计时器隐藏气泡，让气泡视图自己控制
    }

    // MARK: - Configuration

    /// Update cooldown for a specific trigger type
    func setCooldown(_ type: TriggerType, cooldown: TimeInterval) {
        cooldowns[type] = cooldown
    }

    /// Get cooldown for a specific trigger type
    func getCooldown(_ type: TriggerType) -> TimeInterval {
        return cooldowns[type] ?? 60.0
    }
}
