import Foundation
import Combine

/// Animation states for the pet character
/// Each state represents a specific animation behavior
enum AnimationState: String, CaseIterable {
    case idle       // Standing/sitting still (using static frame or slow idle animation)
    case running    // Active movement animation
    case wakeup     // Transition animation from sleep to active state
    case sleeping   // Sleep animation (looping)
    case eating     // Eating/drinking animation
    case fighting   // Action animation (kick, punch, etc.)

    /// Animation asset name for each state and direction
    /// Returns nil if no animation is available for that combination
    func animationName(for direction: MovementDirection) -> String? {
        switch self {
        case .idle:
            // idle 基础动画名称，由 updateAnimationAsset 决定最终使用哪个
            switch direction {
            case .south:
                return "wake_up_south"
            case .east:
                return "wake_up_east"
            case .west:
                return "wake_up_west"
            case .north:
                return "wake_up_north"
            }

        case .running:
            switch direction {
            case .south:
                return "running_south"
            case .east:
                return "running_east"
            case .west:
                return "running_west"
            case .north:
                return "running_north"
            }

        case .wakeup:
            // Wakeup animation - supports all 4 directions
            switch direction {
            case .south:
                return "wake_up_south"
            case .east:
                return "wake_up_east"
            case .west:
                return "wake_up_west"
            case .north:
                return "wake_up_north"
            }

        case .sleeping:
            // Sleep animation - supports south and west directions
            // North and east use south as fallback
            switch direction {
            case .south, .north, .east:
                return "sleep_south"
            case .west:
                return "sleep_west"
            }

        case .eating:
            // Eating animation - currently only south direction available
            // All other directions use south as fallback
            return "eating_south"

        case .fighting:
            // US-007: Fighting animation (flying-kick)
            switch direction {
            case .south:
                return "fight_south"
            case .east:
                return "fight_east"
            case .west:
                return "fight_west"
            case .north:
                return "fight_north"
            }
        }
    }

    /// Animation playback mode for this state
    var playbackMode: AnimationPlaybackMode {
        switch self {
        case .idle:
            // 根据 idleUsesAnimation 决定播放模式
            // true: 播放 idle_south 动画（循环）
            // false: 显示静态帧
            return .loop
        case .running:
            return .loop
        case .wakeup:
            return .once  // Play once then transition
        case .sleeping:
            return .loop
        case .eating:
            return .loop
        case .fighting:
            return .once  // Play once then return to idle
        }
    }

    /// Default duration for this state when playing once
    var defaultDuration: TimeInterval {
        switch self {
        case .idle:
            return TimeInterval.infinity  // Continuous until state change
        case .running:
            return TimeInterval.infinity  // Continuous while moving
        case .wakeup:
            return 1.5  // ~1.5 seconds for wake transition
        case .sleeping:
            return TimeInterval.infinity  // Continuous while sleeping
        case .eating:
            return 3.0  // ~3 seconds per eating cycle
        case .fighting:
            return 1.0  // ~1 second for action animation
        }
    }
}

/// Animation playback mode
enum AnimationPlaybackMode {
    case loop               // Loop animation continuously
    case once               // Play animation once and stop
    case staticFrame(frameIndex: Int)  // Show specific frame as static image
}

/// Valid state transitions between animation states
/// Defines which states can transition to which other states
struct StateTransitionRule {
    let fromState: AnimationState
    let toState: AnimationState
    let requiresTransitionAnimation: Bool  // Whether a transition animation is needed
    let transitionAnimation: AnimationState?  // Optional intermediate animation
}

/// Manages animation state and transitions for the pet character
/// Coordinates between movement detection, task scheduling, and animation display
class AnimationStateMachine: ObservableObject {

    // MARK: - Shared Instance

    /// Shared instance for cross-component access
    static let shared = AnimationStateMachine()

    // MARK: - Published Properties

    /// Current animation state
    @Published var currentState: AnimationState = .idle

    /// Current movement direction (for directional animations)
    @Published var currentDirection: MovementDirection = .south

    /// Whether an animation is currently active
    @Published var isAnimating: Bool = false

    /// Current animation asset name (nil if no animation available)
    @Published var currentAnimationName: String?

    /// Current playback mode
    @Published var currentPlaybackMode: AnimationPlaybackMode = .loop

    /// US-009: Whether waiting for animation completion before next transition
    @Published var isWaitingForCompletion: Bool = false

    // MARK: - Private Properties

    /// Previous state for transition tracking
    private var previousState: AnimationState = .idle

    /// Time when current state started
    private var stateStartTime: Date = Date()

    /// Idle time tracking (for auto-sleep)
    private var idleStartTime: Date = Date()

    /// Threshold for idle-to-sleep transition (延长到120秒=2分钟，只有真正长时间idle才睡眠)
    /// 这个功能是备用机制，主要睡眠由 TaskScheduler 控制
    private let idleToSleepThreshold: TimeInterval = 120.0

    /// Speed threshold for running animation (pixels per frame)
    private let runningSpeedThreshold: CGFloat = 2.0

    /// Delay before transitioning from running to idle (to avoid flicker)
    private let runningToIdleDelay: TimeInterval = 0.5

    /// Timer for delayed state transitions
    private var transitionTimer: Timer?

    /// US-009: Queue of pending state transitions
    private var transitionQueue: [AnimationState] = []

    /// US-009: Target state after current transition animation completes
    private var pendingTargetState: AnimationState?

    // US-007: Random fight animation during idle
    /// Timer for random fight animation triggering
    private var randomFightTimer: Timer?

    /// Minimum interval between random fight checks (seconds)
    private let randomFightMinInterval: TimeInterval = 3.0

    /// Maximum interval between random fight checks (seconds)
    private let randomFightMaxInterval: TimeInterval = 10.0

    /// Probability of triggering fight animation on each check (10%)
    private let randomFightProbability: Double = 0.1

    /// Whether random fight animations are enabled
    private var randomFightEnabled: Bool = true

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// idle 状态是否使用动画（呼吸），还是使用静态帧（躺着）
    /// 每次进入 idle 状态时随机决定
    private var idleUsesAnimation: Bool = true

    // MARK: - Transition Rules

    /// Valid state transitions
    /// Format: (from, to) -> (requiresTransition, transitionAnimation)
    private let transitionRules: [StateTransitionRule] = [
        // Idle transitions
        // US-004: Play wakeup before running when coming from idle (resting state)
        StateTransitionRule(fromState: .idle, toState: .running, requiresTransitionAnimation: true, transitionAnimation: .wakeup),
        StateTransitionRule(fromState: .idle, toState: .sleeping, requiresTransitionAnimation: false, transitionAnimation: nil),
        StateTransitionRule(fromState: .idle, toState: .eating, requiresTransitionAnimation: false, transitionAnimation: nil),
        StateTransitionRule(fromState: .idle, toState: .fighting, requiresTransitionAnimation: false, transitionAnimation: nil),

        // Running transitions
        StateTransitionRule(fromState: .running, toState: .idle, requiresTransitionAnimation: false, transitionAnimation: nil),
        StateTransitionRule(fromState: .running, toState: .sleeping, requiresTransitionAnimation: true, transitionAnimation: nil),  // Stop first

        // Sleeping transitions
        // US-004: Play wakeup before running when coming from sleep
        StateTransitionRule(fromState: .sleeping, toState: .wakeup, requiresTransitionAnimation: false, transitionAnimation: nil),
        StateTransitionRule(fromState: .sleeping, toState: .running, requiresTransitionAnimation: true, transitionAnimation: .wakeup),
        StateTransitionRule(fromState: .sleeping, toState: .idle, requiresTransitionAnimation: true, transitionAnimation: .wakeup),

        // Wakeup transitions (always goes to idle or running after completion)
        StateTransitionRule(fromState: .wakeup, toState: .idle, requiresTransitionAnimation: false, transitionAnimation: nil),
        StateTransitionRule(fromState: .wakeup, toState: .running, requiresTransitionAnimation: false, transitionAnimation: nil),

        // Eating transitions
        StateTransitionRule(fromState: .eating, toState: .idle, requiresTransitionAnimation: false, transitionAnimation: nil),

        // Fighting transitions
        StateTransitionRule(fromState: .fighting, toState: .idle, requiresTransitionAnimation: false, transitionAnimation: nil)
    ]

    // MARK: - Initialization

    init() {
        setupInitialState()
    }

    deinit {
        transitionTimer?.invalidate()
        randomFightTimer?.invalidate()
    }

    private func setupInitialState() {
        currentState = .idle
        currentDirection = .south
        updateAnimationAsset()
        stateStartTime = Date()
        idleStartTime = Date()
    }

    // MARK: - State Transition Methods

    /// Request transition to a new state
    /// - Parameters:
    ///   - newState: Target state to transition to
    ///   - force: Whether to force transition without checking rules
    /// - Returns: True if transition was accepted
    @discardableResult
    func transitionTo(_ newState: AnimationState, force: Bool = false) -> Bool {
        // Check if transition is valid
        guard canTransition(from: currentState, to: newState) || force else {
            print("AnimationStateMachine: Invalid transition from \(currentState.rawValue) to \(newState.rawValue)")
            return false
        }

        // 触发动作吐槽（如果状态变化）
        if currentState != newState {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ActionCommentManager.shared.onAnimationStateChanged(newState)
            }
        }

        // Find transition rule
        let rule = findTransitionRule(from: currentState, to: newState)

        // Cancel any pending transition
        transitionTimer?.invalidate()
        transitionTimer = nil

        // Handle transition animation if needed
        // 特殊处理：idle → running 时，只有躺着才需要 wakeup
        let needsTransitionAnim: Bool
        let actualTransitionAnim: AnimationState?

        if currentState == .idle && newState == .running {
            // 只有当 idle 是静态帧（躺着）时才需要 wakeup 动画
            // 如果 idle 已经是站立动画，直接转到 running
            if idleUsesAnimation {
                needsTransitionAnim = false
                actualTransitionAnim = nil
                print("AnimationStateMachine: Idle was standing animation, skip wakeup transition")
            } else {
                needsTransitionAnim = true
                actualTransitionAnim = .wakeup
                print("AnimationStateMachine: Idle was lying static, need wakeup transition")
            }
        } else {
            needsTransitionAnim = rule?.requiresTransitionAnimation ?? false
            actualTransitionAnim = rule?.transitionAnimation
        }

        if needsTransitionAnim, let transitionAnim = actualTransitionAnim {
            performTransitionAnimation(transitionAnim, thenTransitionTo: newState)
        } else {
            performDirectTransition(newState)
        }

        return true
    }

    /// Check if transition from current state to new state is valid
    func canTransition(from: AnimationState, to: AnimationState) -> Bool {
        // Same state is always valid (no transition needed)
        if from == to { return false }

        // Check transition rules
        return transitionRules.contains { rule in
            rule.fromState == from && rule.toState == to
        }
    }

    /// Find the transition rule for a specific state pair
    private func findTransitionRule(from: AnimationState, to: AnimationState) -> StateTransitionRule? {
        return transitionRules.first { rule in
            rule.fromState == from && rule.toState == to
        }
    }

    /// Perform a direct state transition without intermediate animation
    private func performDirectTransition(_ newState: AnimationState) {
        previousState = currentState
        currentState = newState
        stateStartTime = Date()

        // Update idle tracking
        if newState == .idle {
            idleStartTime = Date()
            // 随机决定 idle 使用动画还是静态帧
            idleUsesAnimation = Bool.random()
            print("AnimationStateMachine: Idle mode - \(idleUsesAnimation ? "animation (呼吸)" : "static frame (躺着)")")
            // US-007: Start random fight timer when entering idle
            startRandomFightTimer()
        } else {
            // US-007: Stop random fight timer when leaving idle
            stopRandomFightTimer()
        }

        // Update animation asset
        updateAnimationAsset()

        print("AnimationStateMachine: Transitioned from \(previousState.rawValue) to \(currentState.rawValue)")
    }

    /// Perform transition animation before final state
    private func performTransitionAnimation(_ transitionAnim: AnimationState, thenTransitionTo finalState: AnimationState) {
        // US-009: Set waiting state and queue the final transition
        isWaitingForCompletion = true
        pendingTargetState = finalState

        // Set to transition animation state
        previousState = currentState
        currentState = transitionAnim
        stateStartTime = Date()
        updateAnimationAsset()

        print("AnimationStateMachine: Playing transition animation \(transitionAnim.rawValue), will transition to \(finalState.rawValue) on completion")

        // US-009: Immediately start the transition animation
        // This is needed because updateAnimationFromStateMachine might skip due to isWaitingForCompletion
        // We need to force the animation to start here
        DispatchQueue.main.async {
            // Notify that animation should start - PetView will handle the actual loading
            self.objectWillChange.send()
        }
    }

    // MARK: - Movement-Based State Updates

    /// Update state based on movement speed
    /// Called by PetView when position changes
    /// - Parameter speed: Movement speed in pixels per frame
    func updateBasedOnMovement(speed: CGFloat) {
        let isMoving = speed >= runningSpeedThreshold

        switch currentState {
        case .idle:
            if isMoving {
                // Start running animation
                transitionTo(.running)
            }

        case .running:
            if !isMoving {
                // Schedule delayed transition to idle
                scheduleDelayedIdleTransition()
            }

        case .sleeping, .wakeup, .eating, .fighting:
            // Don't change state during these animations
            break
        }

        // Check for auto-sleep if idle for too long
        checkAutoSleep()
    }

    /// Update direction based on movement direction
    func updateDirection(_ direction: MovementDirection) {
        if currentDirection != direction {
            currentDirection = direction
            updateAnimationAsset()
        }
    }

    /// Schedule delayed transition to idle (to avoid flickering)
    private func scheduleDelayedIdleTransition() {
        // Cancel any existing timer
        transitionTimer?.invalidate()

        transitionTimer = Timer.scheduledTimer(withTimeInterval: runningToIdleDelay, repeats: false) { [weak self] _ in
            guard let self = self, self.currentState == .running else { return }
            self.transitionTo(.idle)
            self.transitionTimer = nil
        }
        RunLoop.current.add(transitionTimer!, forMode: .common)
    }

    /// Check if pet should auto-transition to sleep
    private func checkAutoSleep() {
        guard currentState == .idle else { return }

        let idleTime = Date().timeIntervalSince(idleStartTime)
        if idleTime >= idleToSleepThreshold {
            transitionTo(.sleeping)
            print("AnimationStateMachine: Auto-sleep triggered after \(idleTime)s idle")
        }
    }

    // MARK: - Task-Based State Updates

    /// Set animation state based on task type
    /// Called by TaskScheduler when task changes
    func setStateForTask(_ task: PetTask) {
        let newState: AnimationState
        switch task {
        case .idle:
            newState = .idle
        case .explore:
            newState = .running
        case .sleep:
            newState = .sleeping
        case .eat:
            newState = .eating
        case .seekAttention:
            newState = .running
        }

        transitionTo(newState, force: true)
    }

    /// Handle animation completion callback
    /// Called by GIFAnimator when once-mode animation completes (US-009)
    func onAnimationComplete() {
        print("🎬 AnimationStateMachine.onAnimationComplete - currentState: \(currentState.rawValue), isWaitingForCompletion: \(isWaitingForCompletion), pendingTargetState: \(pendingTargetState?.rawValue ?? "nil")")

        // US-009: Handle completion of transition animation
        if isWaitingForCompletion, let targetState = pendingTargetState {
            isWaitingForCompletion = false
            pendingTargetState = nil

            // Perform the queued transition
            performDirectTransition(targetState)
            print("AnimationStateMachine: Transition animation completed, transitioning to \(targetState.rawValue)")
            return
        }

        // Handle other completion scenarios
        switch currentState {
        case .wakeup:
            // Wakeup complete -> go to idle if no pending target
            if !isWaitingForCompletion {
                print("⚠️ AnimationStateMachine: Wakeup completed without pending target, going to idle")
                transitionTo(.idle)
            }
        case .fighting:
            // Fighting complete -> return to idle
            transitionTo(.idle)
        case .eating, .sleeping, .running, .idle:
            // These states don't auto-transition on completion
            break
        }
    }

    /// US-009: Queue a transition to be performed after current animation completes
    func queueTransition(to state: AnimationState) {
        transitionQueue.append(state)
        print("AnimationStateMachine: Queued transition to \(state.rawValue)")
    }

    /// US-009: Process the next queued transition
    private func processNextQueuedTransition() {
        guard !transitionQueue.isEmpty else { return }

        let nextState = transitionQueue.removeFirst()
        transitionTo(nextState)
    }

    // MARK: - Animation Asset Management

    /// Update current animation asset name based on state and direction
    private func updateAnimationAsset() {
        // idle 状态根据 idleUsesAnimation 决定使用哪个动画
        if currentState == .idle {
            if idleUsesAnimation {
                // 使用 idle_south 动画（呼吸）
                currentAnimationName = "idle_south"
                currentPlaybackMode = .loop
            } else {
                // 使用 wake_up 第一帧（躺着静态）
                currentAnimationName = currentState.animationName(for: currentDirection)
                currentPlaybackMode = .staticFrame(frameIndex: 0)
            }
        } else {
            currentAnimationName = currentState.animationName(for: currentDirection)
            currentPlaybackMode = currentState.playbackMode
        }

        // Check if animation is available
        if currentAnimationName == nil {
            print("AnimationStateMachine: No animation asset for \(currentState.rawValue) \(currentDirection)")
            // Fall back to idle animation
            currentAnimationName = "idle_south"
            currentPlaybackMode = .loop
        }

        isAnimating = currentAnimationName != nil
    }

    // MARK: - Public State Query Methods

    /// Check if currently in a state that should show static frame
    func shouldShowStaticFrame() -> Bool {
        switch currentPlaybackMode {
        case .staticFrame:
            return true
        case .loop, .once:
            return false
        }
    }

    /// Get frame index for static frame display
    func getStaticFrameIndex() -> Int {
        switch currentPlaybackMode {
        case .staticFrame(let index):
            return index
        case .loop, .once:
            return 0
        }
    }

    /// Check if current state blocks movement
    func blocksMovement() -> Bool {
        switch currentState {
        case .sleeping, .eating, .fighting:
            return true
        case .idle, .running, .wakeup:
            return false
        }
    }

    /// Get time elapsed in current state
    func timeInCurrentState() -> TimeInterval {
        return Date().timeIntervalSince(stateStartTime)
    }

    /// Get idle time (how long pet has been stationary)
    func getIdleTime() -> TimeInterval {
        if currentState == .idle {
            return Date().timeIntervalSince(idleStartTime)
        }
        return 0
    }

    // MARK: - US-007: Random Fight Animation

    /// Start the timer for random fight animation checks
    private func startRandomFightTimer() {
        guard randomFightEnabled else { return }

        // Cancel any existing timer
        randomFightTimer?.invalidate()

        // Schedule next random check with random interval
        let interval = randomFightMinInterval + Double.random(in: 0...(randomFightMaxInterval - randomFightMinInterval))
        randomFightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performRandomFightCheck()
            self?.randomFightTimer = nil
        }
        RunLoop.current.add(randomFightTimer!, forMode: .common)
    }

    /// Stop the random fight timer
    private func stopRandomFightTimer() {
        randomFightTimer?.invalidate()
        randomFightTimer = nil
    }

    /// Perform a random fight animation check
    /// Called by the random fight timer at random intervals
    private func performRandomFightCheck() {
        // Only trigger fight if still in idle state
        guard currentState == .idle else { return }

        // Check probability (10% chance)
        if Double.random(in: 0...1) < randomFightProbability {
            // Trigger fight animation
            triggerRandomFightAnimation()
        } else {
            // Schedule next check
            startRandomFightTimer()
        }
    }

    /// Trigger a random fight animation during idle state
    /// Fight animation plays once then returns to idle (US-009: uses completion callback)
    private func triggerRandomFightAnimation() {
        print("AnimationStateMachine: Triggering random fight animation")

        // US-009: Queue return to idle after fight animation
        // The onAnimationComplete callback will handle the transition
        isWaitingForCompletion = true
        pendingTargetState = .idle

        // Transition to fighting state (fighting uses .once playback mode)
        previousState = currentState
        currentState = .fighting
        stateStartTime = Date()
        updateAnimationAsset()

        // US-009: No timer needed - onAnimationComplete handles return to idle
    }

    /// Enable or disable random fight animations
    func setRandomFightEnabled(_ enabled: Bool) {
        randomFightEnabled = enabled
        if !enabled {
            stopRandomFightTimer()
        } else if currentState == .idle {
            startRandomFightTimer()
        }
    }
}