import Foundation

/// Configuration parameters for autonomous pet behavior
struct BehaviorConfig {
    // MARK: - Task Evaluation

    /// Interval between task evaluations in seconds
    var taskInterval: TimeInterval = 5.0  // 5秒评估一次，更快切换任务

    // MARK: - Movement

    /// Movement speed in pixels per frame
    var moveSpeed: CGFloat = 2.0

    /// Movement update interval (frames per second)
    var moveUpdateInterval: TimeInterval = 1.0 / 30.0  // 30fps

    /// Screen boundary margin for autonomous movement
    var boundaryMargin: CGFloat = 50

    /// Range for wander/idle movement (±px from current position)
    var wanderRange: CGFloat = 50

    /// Minimum movement distance for explore task (pixels)
    /// 修复：增大距离让精灵走更长时间，避免太快到达目标后静止
    var exploreMinDistance: CGFloat = 200

    /// Maximum movement distance for explore task (pixels)
    var exploreMaxDistance: CGFloat = 500

    /// Minimum cooldown after movement before next movement (seconds)
    var movementCooldownMin: TimeInterval = 3.0

    /// Maximum cooldown after movement before next movement (seconds)
    var movementCooldownMax: TimeInterval = 8.0

    // MARK: - Energy

    /// Energy recovery rate per second during sleep
    var energyRecoveryRate: Int = 3

    /// Energy drain rate per second during movement
    var energyDrainRate: Int = 1

    // MARK: - Happiness

    /// Happiness decay rate per second (if applicable)
    var happinessDecayRate: Int = 0

    // MARK: - Task Durations

    /// Duration range for idle task (seconds)
    var idleDuration: ClosedRange<TimeInterval> = 3.0...8.0  // 缩短idle时间，让精灵更活跃

    /// Duration range for explore task (seconds)
    var exploreDuration: ClosedRange<TimeInterval> = 15.0...25.0  // 增加探索时间，让精灵有时间走过去

    /// Duration range for sleep task (seconds)
    var sleepDuration: ClosedRange<TimeInterval> = 15.0...25.0

    /// Duration range for eat task (seconds)
    var eatDuration: ClosedRange<TimeInterval> = 5.0...8.0

    /// Duration range for seekAttention task (seconds)
    var seekAttentionDuration: ClosedRange<TimeInterval> = 3.0...5.0

    // MARK: - Default Instance

    /// Default configuration with standard values
    static let defaultConfig = BehaviorConfig()

    // MARK: - Helper Methods

    /// Get duration range for a specific task
    func durationForTask(_ task: PetTask) -> ClosedRange<TimeInterval> {
        switch task {
        case .idle:
            return idleDuration
        case .explore:
            return exploreDuration
        case .sleep:
            return sleepDuration
        case .eat:
            return eatDuration
        case .seekAttention:
            return seekAttentionDuration
        }
    }

    /// Get energy effect rate for a specific task (per second)
    func energyEffectForTask(_ task: PetTask) -> Int {
        switch task {
        case .idle:
            return 0
        case .sleep:
            return energyRecoveryRate  // Recovery (positive)
        case .explore:
            return energyDrainRate     // Drain
        case .eat:
            return 1                   // Minimal drain
        case .seekAttention:
            return energyDrainRate     // Drain
        }
    }
}