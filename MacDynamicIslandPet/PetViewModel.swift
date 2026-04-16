import Foundation
import Combine
import AppKit  // US-011: Required for NSColor in bubbleColor property

// MARK: - Supporting Types

enum MouthStyle {
    case neutral
    case smile
    case frown
}

enum PetState: String {
    case idle
    case alert
    case happy

    /// Returns the duration this state should last before transitioning
    var duration: TimeInterval {
        switch self {
        case .idle:
            return 5.0
        case .alert:
            return 2.0
        case .happy:
            return 3.0
        }
    }
}

/// Emotion system for the pet
/// Emotions affect visual appearance and behavior
/// US-011: Enhanced with more emotions and bubble colors
enum PetEmotion: String, CaseIterable {
    case content      // Default positive state - 满足
    case bored        // Needs interaction - 无聊
    case excited      // High energy, happy - 激动
    case curious      // US-011: 好奇 - interested in something
    case worried      // US-011: 担心 - concerned about user
    case playful      // US-011: 调皮 - mischievous, teasing
    case tired        // US-011: 疲惫 - sleepy, worn out

    var color: String {
        switch self {
        case .content: return "blue"
        case .bored: return "gray"
        case .excited: return "green"
        case .curious: return "yellow"      // US-011: 好奇黄色
        case .worried: return "purple"      // US-011: 担心紫色
        case .playful: return "pink"        // US-011: 调皮粉色
        case .tired: return "brown"
        }
    }

    /// US-011: Bubble color for self-talk bubbles
    var bubbleColor: NSColor {
        switch self {
        case .content: return NSColor.systemBlue.withAlphaComponent(0.9)
        case .bored: return NSColor.gray.withAlphaComponent(0.9)
        case .excited: return NSColor.systemGreen.withAlphaComponent(0.9)
        case .curious: return NSColor.systemYellow.withAlphaComponent(0.9)
        case .worried: return NSColor.systemPurple.withAlphaComponent(0.9)
        case .playful: return NSColor.systemPink.withAlphaComponent(0.9)
        case .tired: return NSColor.brown.withAlphaComponent(0.9)
        }
    }

    var intensity: Int {
        switch self {
        case .content: return 1
        case .bored: return 0
        case .excited: return 2
        case .curious: return 1
        case .worried: return 1
        case .playful: return 1
        case .tired: return 0
        }
    }

    /// US-011: Preferred comment style identifier (raw string to avoid dependency)
    var preferredCommentStyleRaw: String {
        switch self {
        case .content: return "gentleTease"
        case .bored: return "playfulRoast"    // bored时倾向搞怪
        case .excited: return "playfulRoast"
        case .curious: return "gentleTease"
        case .worried: return "caringAdvice"  // worried时倾向关心
        case .playful: return "playfulRoast"  // playful时倾向搞怪
        case .tired: return "caringAdvice"
        }
    }

    /// US-011: Chinese display name
    var displayName: String {
        switch self {
        case .content: return "满足"
        case .bored: return "无聊"
        case .excited: return "激动"
        case .curious: return "好奇"
        case .worried: return "担心"
        case .playful: return "调皮"
        case .tired: return "疲惫"
        }
    }
}

enum StateTransition {
    case stay
    case transition(to: PetState)
}

/// Task type for pet behavior - matches TaskScheduler's PetTask
/// Used to sync animation state with scheduled tasks
enum PetBehaviorTask: String {
    case idle
    case explore
    case sleep
    case eat
    case seekAttention
}

class PetViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentState: PetState = .idle
    @Published var currentEmotion: PetEmotion = .content
    @Published var position: CGPoint = .zero
    @Published var scale: CGFloat = 1.0
    @Published var isAnimating: Bool = false

    // US-005: Current task for animation state synchronization
    @Published var currentTask: PetBehaviorTask = .idle

    // Emotion metrics
    @Published var happinessLevel: Int = 50  // 0-100
    @Published var energyLevel: Int = 50     // 0-100
    @Published var interactionCount: Int = 0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var stateTimer: Timer?
    private var emotionTimer: Timer?
    private var happinessDecayTimer: Timer?  // Store for cleanup
    private var transitionQueue: [PetState] = []

    // Emotion thresholds
    private let boredThreshold: Int = 30
    private let excitedThreshold: Int = 70

    // MARK: - Initialization

    init() {
        setupStateTransitions()
        setupEmotionSystem()
    }

    deinit {
        stateTimer?.invalidate()
        emotionTimer?.invalidate()
        happinessDecayTimer?.invalidate()
    }

    // MARK: - Setup

    func setupStateTransitions() {
        startStateMachine()
    }

    func setupEmotionSystem() {
        // Update emotion every 2 seconds based on interaction history
        emotionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateEmotion()
        }

        // Decay happiness over time if no interaction
        startHappinessDecay()
    }

    // MARK: - State Machine

    private func startStateMachine() {
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateState()
        }
    }

    private func updateState() {
        if let nextState = transitionQueue.first {
            transitionQueue.removeFirst()
            performTransition(to: nextState)
            return
        }

        let transition = evaluateTransition(from: currentState)
        switch transition {
        case .stay: break
        case .transition(let newState):
            performTransition(to: newState)
        }
    }

    private func evaluateTransition(from state: PetState) -> StateTransition {
        switch state {
        case .idle: return .stay
        case .alert: return .transition(to: .idle)
        case .happy: return .transition(to: .idle)
        }
    }

    private func performTransition(to newState: PetState) {
        guard currentState != newState else { return }
        // Note: Animation is handled by SwiftUI View, not here
        currentState = newState
        print("Pet state: \(currentState.rawValue)")
    }

    // MARK: - Emotion System

    /// US-011: Enhanced emotion update with new emotions and bored-triggered comments
    private func updateEmotion() {
        // Time-based emotion factors
        let hour = Calendar.current.component(.hour, from: Date())

        // Calculate new emotion based on multiple factors
        var newEmotion: PetEmotion

        // US-011: 长时间无互动时情绪变为bored，触发主动吐槽
        if happinessLevel <= boredThreshold {
            newEmotion = .bored

            // US-011: Trigger proactive comment when bored
            let lastInteraction = Date().timeIntervalSince(lastInteractionTime)
            if lastInteraction > 60.0 {  // More than 1 minute since last interaction
                triggerBoredComment()
            }
        } else if happinessLevel >= excitedThreshold {
            newEmotion = .excited
        } else if energyLevel <= 30 {
            // US-011: 疲惫 - when energy is low
            newEmotion = .tired
        } else if hour >= 23 || hour < 6 {
            // US-011: 深夜时担心用户
            newEmotion = .worried
        } else if interactionCount > 5 {
            // High interaction count → playful
            newEmotion = .playful
        } else {
            newEmotion = .content
        }

        if currentEmotion != newEmotion {
            currentEmotion = newEmotion
            print("Pet emotion: \(currentEmotion.displayName) (happiness: \(happinessLevel), energy: \(energyLevel))")
        }
    }

    /// US-011: Track last interaction time
    private var lastInteractionTime: Date = Date()

    /// US-011: Track last bored comment time (to prevent spam)
    private var lastBoredCommentTime: Date = Date.distantPast

    /// US-011: Cooldown between bored comments (seconds)
    private let boredCommentCooldown: TimeInterval = 120.0  // 2 minutes

    /// US-011: Trigger comment when bored (主动吐槽) - uses simple comment generation
    private func triggerBoredComment() {
        // 检查冷却时间，避免连续触发
        let timeSinceLastBoredComment = Date().timeIntervalSince(lastBoredCommentTime)
        guard timeSinceLastBoredComment >= boredCommentCooldown else {
            print("PetViewModel: Bored comment cooldown active (\(Int(timeSinceLastBoredComment))s remaining)")
            return
        }

        // 检查是否已经在显示气泡，避免重复
        guard !SelfTalkManager.shared.shouldShowBubble else {
            print("PetViewModel: Bubble already showing, skip bored comment")
            return
        }

        lastBoredCommentTime = Date()

        // Simple bored-triggered comments (doesn't use CommentGenerator to avoid circular dependency)
        let boredComments = [
            "好无聊呀~",
            "没人陪我玩~",
            "主人在干嘛呢~",
            "好无聊好无聊~",
            "想找人聊聊~"
        ]

        let comment = boredComments.randomElement() ?? "好无聊呀~"

        // 使用统一接口显示气泡，不设置自定义隐藏时间
        SelfTalkManager.shared.showExternalBubble(text: comment)

        // 记录到感知记忆
        PerceptionMemoryManager.shared.savePerception(
            appName: "小精灵情绪",
            activityDescription: "无聊触发(happiness≤\(boredThreshold))",
            screenshotSummary: nil,
            petReaction: comment
        )

        print("PetViewModel: Bored-triggered comment: '\(comment)'")
    }

    private func startHappinessDecay() {
        // Decay happiness slowly when no interaction (延长到10秒，减少衰减速度)
        happinessDecayTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.decayHappiness()
        }
    }

    private func decayHappiness() {
        guard happinessLevel > 0 else { return }
        happinessLevel = max(0, happinessLevel - 1)  // 减少每次衰减量（从2改为1）
    }

    // MARK: - Public State Methods

    func setState(_ state: PetState) {
        if state == .alert {
            transitionQueue.removeAll()
            performTransition(to: .alert)
        } else {
            transitionQueue.append(state)
        }
    }

    func triggerAlert() {
        setState(.alert)
    }

    func triggerHappy() {
        setState(.happy)
        increaseHappiness()
    }

    func returnToIdle() {
        setState(.idle)
    }

    // MARK: - Emotion Methods

    /// Called when user interacts with pet (click, drag)
    /// US-011: Track last interaction time for bored-triggered comments
    func onUserInteraction() {
        interactionCount += 1
        lastInteractionTime = Date()  // US-011: Track interaction time
        increaseHappiness(amount: 10)
        increaseEnergy(amount: 5)
    }

    private func increaseHappiness(amount: Int = 10) {
        happinessLevel = min(100, happinessLevel + amount)
    }

    private func increaseEnergy(amount: Int = 5) {
        energyLevel = min(100, energyLevel + amount)
    }

    func getEmotionColor() -> String {
        return currentEmotion.color
    }

    // MARK: - Task Management (US-005)

    /// Update current task - used by TaskScheduler to sync animation state
    func setCurrentTask(_ task: PetBehaviorTask) {
        currentTask = task
    }

    // MARK: - Position & Scale

    func setPosition(_ position: CGPoint) {
        self.position = position
    }

    func setScale(_ scale: CGFloat) {
        self.scale = max(0.5, min(2.0, scale))
    }
}
