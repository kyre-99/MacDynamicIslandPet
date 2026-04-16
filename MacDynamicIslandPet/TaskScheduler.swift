import Foundation
import Combine

/// Types of autonomous tasks the pet can perform
enum PetTask: String, CaseIterable {
    case idle         // Rest in place
    case explore      // Move around screen actively
    case sleep        // Rest to recover energy
    case eat          // Simulate finding and eating food
    case seekAttention // Move towards user/mouse to get attention

    /// Duration range for this task type in seconds
    var durationRange: ClosedRange<TimeInterval> {
        switch self {
        case .idle:
            return 3.0...5.0
        case .explore:
            return 5.0...10.0
        case .sleep:
            return 10.0...15.0
        case .eat:
            return 3.0...5.0
        case .seekAttention:
            return 3.0...5.0
        }
    }

    /// Whether this task requires movement (running animation)
    var requiresMovement: Bool {
        switch self {
        case .idle, .sleep, .eat:
            return false  // These tasks stay stationary
        case .explore, .seekAttention:
            return true   // Only these trigger running animation
        }
    }

    /// Energy cost per second during this task
    var energyCost: Int {
        switch self {
        case .idle:
            return 0
        case .sleep:
            return -3  // Negative = energy recovery
        case .explore:
            return 2
        case .eat:
            return 1
        case .seekAttention:
            return 2
        }
    }

    /// Happiness change when completing this task
    var happinessChange: Int {
        switch self {
        case .idle:
            return 1   // Idle 也恢复少量 happiness，避免持续衰减
        case .sleep:
            return 5
        case .explore:
            return 3
        case .eat:
            return 10
        case .seekAttention:
            return 5
        }
    }
}

/// Manages autonomous task scheduling for the pet
class TaskScheduler: ObservableObject {
    static let shared = TaskScheduler()

    // MARK: - Published Properties

    @Published var currentTask: PetTask = .idle
    @Published var taskStartTime: Date = Date()
    @Published var taskDuration: TimeInterval = 3.0
    @Published var isTaskActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var config: BehaviorConfig = BehaviorConfig.defaultConfig

    // MARK: - Private Properties

    private var taskTimer: Timer?
    private var evaluationTimer: Timer?
    private var petViewModel: PetViewModel?
    private var cancellables = Set<AnyCancellable>()

    // Callbacks for task actions
    var onTaskStart: ((PetTask) -> Void)?
    var onTaskComplete: ((PetTask) -> Void)?
    var onTaskChange: ((PetTask) -> Void)?

    // MARK: - Initialization

    private init() {
        setupEvaluationTimer()
    }

    deinit {
        taskTimer?.invalidate()
        evaluationTimer?.invalidate()
    }

    // MARK: - Configuration

    /// Update behavior configuration
    func updateConfig(_ newConfig: BehaviorConfig) {
        config = newConfig
        // Restart evaluation timer with new interval
        evaluationTimer?.invalidate()
        setupEvaluationTimer()
    }

    func setViewModel(_ viewModel: PetViewModel) {
        self.petViewModel = viewModel

        // Subscribe to happiness and energy changes
        viewModel.$happinessLevel
            .sink { [weak self] _ in
                self?.considerTaskChange()
            }
            .store(in: &cancellables)

        viewModel.$energyLevel
            .sink { [weak self] _ in
                self?.considerTaskChange()
            }
            .store(in: &cancellables)
    }

    // MARK: - Timer Setup

    private func setupEvaluationTimer() {
        // Evaluate task state at configured interval
        evaluationTimer = Timer.scheduledTimer(
            withTimeInterval: config.taskInterval,
            repeats: true
        ) { [weak self] _ in
            self?.evaluateCurrentTask()
        }

        // Add to common run loop mode to work during UI interaction
        RunLoop.current.add(evaluationTimer!, forMode: .common)
    }

    // MARK: - Task Management

    /// Start a new task
    func startTask(_ task: PetTask) {
        stopCurrentTask()

        currentTask = task
        taskStartTime = Date()
        taskDuration = randomDuration(for: task)
        isTaskActive = true

        print("🚀 TaskScheduler.startTask: \(task.rawValue), duration: \(taskDuration)s, happiness: \(petViewModel?.happinessLevel ?? 0), energy: \(petViewModel?.energyLevel ?? 0)")

        // 触发任务吐槽
        ActionCommentManager.shared.onTaskStarted(task)

        // Set up timer for task completion
        taskTimer = Timer.scheduledTimer(
            withTimeInterval: taskDuration,
            repeats: false
        ) { [weak self] _ in
            self?.completeCurrentTask()
        }
        RunLoop.current.add(taskTimer!, forMode: .common)

        onTaskStart?(task)
    }

    /// Stop the current task
    func stopCurrentTask() {
        taskTimer?.invalidate()
        taskTimer = nil
        isTaskActive = false
    }

    /// Complete current task and select next
    private func completeCurrentTask() {
        let completedTask = currentTask
        onTaskComplete?(completedTask)

        // Apply task effects to pet state
        applyTaskEffects(completedTask)

        // Select next task
        selectNextTask()
    }

    /// Pause task execution (e.g., during user interaction)
    func pause() {
        isPaused = true
        stopCurrentTask()
        print("Task scheduler paused")
    }

    /// Resume task execution after pause
    func resume(after delay: TimeInterval = 0) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.resumeNow()
            }
        } else {
            resumeNow()
        }
    }

    private func resumeNow() {
        isPaused = false
        // Always start a new task on resume, even if no task was active before
        if !isTaskActive {
            selectNextTask()
            print("Task scheduler resumed - starting new task: \(currentTask.rawValue)")
        } else {
            print("Task scheduler resumed - task already active: \(currentTask.rawValue)")
        }
    }

    /// Interrupt current task immediately (e.g., on user click)
    func interrupt() {
        stopCurrentTask()
        isTaskActive = false
        print("Task interrupted")
    }

    // MARK: - Task Selection Logic

    /// Select next task based on pet state
    private func selectNextTask() {
        guard !isPaused else { return }

        let nextTask = chooseTaskBasedOnState()
        startTask(nextTask)
        onTaskChange?(nextTask)
    }

    /// Choose task considering happiness and energy levels
    private func chooseTaskBasedOnState() -> PetTask {
        guard let viewModel = petViewModel else {
            return randomTask()
        }

        let happiness = viewModel.happinessLevel
        let energy = viewModel.energyLevel

        // Priority-based selection

        // Low happiness triggers seeking attention more frequently
        if happiness <= 30 {
            let tasks: [PetTask] = [.seekAttention, .seekAttention, .seekAttention, .explore]
            return tasks.randomElement() ?? .seekAttention
        }

        // Low energy triggers sleep or idle
        if energy <= 30 {
            let tasks: [PetTask] = [.sleep, .sleep, .sleep, .idle]
            return tasks.randomElement() ?? .sleep
        }

        // High energy - more active, 加入少量 seekAttention 和 eat
        if energy >= 70 {
            // explore 40%, seekAttention 20%, eat 20%, idle 20%
            let tasks: [PetTask] = [.explore, .explore, .explore, .explore,
                                    .seekAttention, .seekAttention,
                                    .eat, .eat,
                                    .idle, .idle]
            return tasks.randomElement() ?? .explore
        }

        // Normal state - 加入 seekAttention 和 eat（各约20%概率）
        // explore 30%, seekAttention 20%, eat 20%, idle 30%
        let tasks: [PetTask] = [.explore, .explore, .explore,
                                .seekAttention, .seekAttention,
                                .eat, .eat,
                                .idle, .idle, .idle]
        return tasks.randomElement() ?? .explore
    }

    /// Get random task when no state is available
    private func randomTask() -> PetTask {
        PetTask.allCases.randomElement() ?? .idle
    }

    /// Random duration within task's configured range
    private func randomDuration(for task: PetTask) -> TimeInterval {
        let range = config.durationForTask(task)
        return TimeInterval.random(in: range)
    }

    // MARK: - Task Evaluation

    /// Evaluate if current task should change based on state
    private func evaluateCurrentTask() {
        guard isTaskActive, !isPaused else { return }

        // Check if task should be interrupted due to state change
        considerTaskChange()

        // Apply ongoing effects (like energy recovery during sleep)
        applyOngoingEffects()
    }

    /// Consider changing task based on pet state
    private func considerTaskChange() {
        guard isTaskActive, let viewModel = petViewModel else { return }

        // Only change if state has shifted significantly
        let energy = viewModel.energyLevel
        let _ = viewModel.happinessLevel  // Used for potential future state checks

        // Interrupt sleep if energy recovered enough
        if currentTask == .sleep && energy >= 70 {
            print("Sleep interrupted - energy recovered")
            completeCurrentTask()
        }

        // Interrupt active task if suddenly low energy
        if currentTask.requiresMovement && energy <= 10 {
            print("Task interrupted - low energy")
            completeCurrentTask()
        }
    }

    // MARK: - Effects

    /// Apply completion effects to pet state
    private func applyTaskEffects(_ task: PetTask) {
        guard let viewModel = petViewModel else { return }

        // Apply happiness change
        let happinessChange = task.happinessChange
        viewModel.happinessLevel = min(100, max(0, viewModel.happinessLevel + happinessChange))

        // Apply energy change (total over duration)
        let energyChange = Int(Double(task.energyCost) * taskDuration)
        viewModel.energyLevel = min(100, max(0, viewModel.energyLevel + energyChange))

        print("Task \(task.rawValue) completed: happiness +\(happinessChange), energy +\(energyChange)")
    }

    /// Apply ongoing effects during task execution
    private func applyOngoingEffects() {
        guard let viewModel = petViewModel else { return }

        // Sleep recovers energy continuously
        if currentTask == .sleep {
            let recovery = config.energyRecoveryRate
            viewModel.energyLevel = min(100, viewModel.energyLevel + recovery)
        }

        // Active tasks drain energy
        if currentTask.requiresMovement {
            let drain = config.energyDrainRate
            viewModel.energyLevel = max(0, viewModel.energyLevel - drain)
        }
    }

    // MARK: - Public Helpers

    /// Get remaining time in current task
    var remainingTime: TimeInterval {
        guard isTaskActive else { return 0 }
        let elapsed = Date().timeIntervalSince(taskStartTime)
        return max(0, taskDuration - elapsed)
    }

    /// Get progress percentage of current task (0-1)
    var taskProgress: Double {
        guard isTaskActive, taskDuration > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(taskStartTime)
        return min(1.0, elapsed / taskDuration)
    }
}