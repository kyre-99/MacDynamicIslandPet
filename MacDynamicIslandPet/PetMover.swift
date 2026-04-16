import Foundation
import AppKit
import Combine

/// Movement direction for animation selection
enum MovementDirection: CaseIterable {
    case south  // Moving down
    case east   // Moving right
    case west   // Moving left
    case north  // Moving up
}

class PetMover: ObservableObject {
    static let shared = PetMover()

    @Published var isMoving: Bool = false
    @Published var targetPosition: CGPoint?
    @Published var config: BehaviorConfig = BehaviorConfig.defaultConfig
    @Published var currentDirection: MovementDirection = .south

    // Autonomous movement mode
    @Published var isAutonomousMode: Bool = false

    /// Whether movement is currently in cooldown (waiting before next movement)
    @Published var isMovementCooldown: Bool = false

    private var moveTimer: Timer?
    private var currentPosition: CGPoint = .zero
    private var cancellables = Set<AnyCancellable>()

    // Movement cooldown timer
    private var cooldownTimer: Timer?

    // Callback for position updates
    var onPositionUpdate: ((CGPoint) -> Void)?

    // Callback for direction changes (for animation switching)
    var onDirectionChange: ((MovementDirection) -> Void)?

    // Store location subscription
    private var locationCancellable: AnyCancellable?

    private init() {}

    // MARK: - Configuration

    /// Update behavior configuration
    func updateConfig(_ newConfig: BehaviorConfig) {
        config = newConfig
    }

    func startMoving(mouseMonitor: MouseMonitor) {
        guard moveTimer == nil else { return }

        // Subscribe to mouse location for following behavior using Combine
        locationCancellable = mouseMonitor.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.updateTargetPosition(location)
            }

        // Start movement loop at configured fps
        moveTimer = Timer.scheduledTimer(withTimeInterval: config.moveUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateMovement()
        }
    }

    func stopMoving() {
        moveTimer?.invalidate()
        moveTimer = nil
        isMoving = false
    }

    private func updateTargetPosition(_ mouseLocation: CGPoint) {
        // Set target to follow mouse with offset
        // Pet follows slightly below and to the right of mouse
        let offset: CGFloat = 80
        targetPosition = CGPoint(
            x: mouseLocation.x + offset,
            y: mouseLocation.y - offset
        )
    }

    private func updateMovement() {
        // If in cooldown mode, don't process movement
        if isMovementCooldown {
            return
        }

        // Allow movement during running and wakeup states
        // (wakeup is transition animation before running, but we should still move)
        let currentAnimState = AnimationStateMachine.shared.currentState
        guard currentAnimState == .running || currentAnimState == .wakeup else {
            // Not in a movement-allowed state - stop any movement
            if isMoving {
                isMoving = false
                targetPosition = nil
            }
            return
        }

        guard let target = targetPosition else { return }

        let current = currentPosition
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = sqrt(dx * dx + dy * dy)

        // Check if we've reached the target
        if distance < config.moveSpeed {
            currentPosition = target
            isMoving = false
            targetPosition = nil  // Clear target when reached
            onPositionUpdate?(currentPosition)

            // US-008: Start movement cooldown after reaching target
            startMovementCooldown()
            return
        }

        // Move towards target
        isMoving = true

        // Update direction based on movement
        updateDirection(dx: dx, dy: dy)

        let ratio = config.moveSpeed / distance
        let newX = current.x + dx * ratio
        let newY = current.y + dy * ratio

        currentPosition = constrainToScreen(CGPoint(x: newX, y: newY))
        onPositionUpdate?(currentPosition)
    }

    // MARK: - Movement Cooldown

    /// Start cooldown timer after movement completes (US-008)
    private func startMovementCooldown() {
        isMovementCooldown = true

        // Random cooldown duration between configured min and max
        let cooldownDuration = TimeInterval.random(
            in: config.movementCooldownMin...config.movementCooldownMax
        )

        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(
            withTimeInterval: cooldownDuration,
            repeats: false
        ) { [weak self] _ in
            self?.endMovementCooldown()
        }
        RunLoop.current.add(cooldownTimer!, forMode: .common)

        print("Movement cooldown started: \(cooldownDuration)s")
    }

    /// End cooldown and allow next movement
    private func endMovementCooldown() {
        isMovementCooldown = false
        cooldownTimer = nil
        print("Movement cooldown ended, ready for next movement")
    }

    /// Cancel cooldown timer
    func cancelCooldown() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        isMovementCooldown = false
    }

    private func constrainToScreen(_ point: CGPoint) -> CGPoint {
        guard let screen = NSScreen.main else { return point }

        let frame = screen.frame
        let petSize: CGFloat = 64 * 1.0  // Base size

        let constrainedX = max(
            frame.minX + config.boundaryMargin,
            min(frame.maxX - petSize - config.boundaryMargin, point.x)
        )
        let constrainedY = max(
            frame.minY + config.boundaryMargin,
            min(frame.maxY - petSize - config.boundaryMargin, point.y)
        )

        return CGPoint(x: constrainedX, y: constrainedY)
    }

    func setCurrentPosition(_ position: CGPoint) {
        currentPosition = position
        targetPosition = nil  // Clear target when manually positioned
    }

    func jumpToPosition(_ position: CGPoint) {
        let constrained = constrainToScreen(position)
        currentPosition = constrained
        targetPosition = nil
        onPositionUpdate?(constrained)
    }

    func setMoveSpeed(_ speed: CGFloat) {
        config.moveSpeed = max(1.0, min(10.0, speed))  // Clamp 1-10
    }

    // MARK: - Autonomous Movement

    /// Start autonomous movement mode (task-driven movement)
    func startAutonomousMovement() {
        guard moveTimer == nil else { return }
        isAutonomousMode = true

        // Start movement loop at configured fps
        moveTimer = Timer.scheduledTimer(withTimeInterval: config.moveUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateMovement()
        }
        RunLoop.current.add(moveTimer!, forMode: .common)
    }

    /// Stop autonomous movement mode
    func stopAutonomousMovement() {
        moveTimer?.invalidate()
        moveTimer = nil
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        isAutonomousMode = false
        isMoving = false
        isMovementCooldown = false
        targetPosition = nil
    }

    /// Set target position for autonomous movement
    func moveTo(_ target: CGPoint) {
        let constrainedTarget = constrainToScreen(target)
        targetPosition = constrainedTarget
    }

    /// Cancel current movement target
    func cancelMovement() {
        targetPosition = nil
        isMoving = false
        cancelCooldown()
    }

    // MARK: - Task-Specific Position Generators

    /// Generate random position for explore task (short distance: 100-300px from current)
    func explorePosition() -> CGPoint {
        // US-008: Use short distance movement instead of full screen wander
        return shortDistancePosition()
    }

    /// Generate short distance position (100-300 pixels from current position)
    /// Movement direction is aligned with animation: purely horizontal or vertical
    func shortDistancePosition() -> CGPoint {
        let minDistance = config.exploreMinDistance
        let maxDistance = config.exploreMaxDistance

        // Random distance within range
        let distance = CGFloat.random(in: minDistance...maxDistance)

        // Choose one of 4 directions (aligned with animation directions)
        let direction = MovementDirection.allCases.randomElement() ?? .south

        // Pure horizontal or vertical movement
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        switch direction {
        case .east:
            offsetX = distance  // Move right
        case .west:
            offsetX = -distance  // Move left
        case .south:
            offsetY = -distance  // Move down (screen coords: y decreases going down)
        case .north:
            offsetY = distance  // Move up (screen coords: y increases going up)
        }

        let newPosition = CGPoint(
            x: currentPosition.x + offsetX,
            y: currentPosition.y + offsetY
        )

        return constrainToScreen(newPosition)
    }

    /// Generate position near current location for wander/idle task (±50px)
    func wanderNearCurrent() -> CGPoint {
        let range = config.wanderRange
        let offsetX = CGFloat.random(in: -range...range)
        let offsetY = CGFloat.random(in: -range...range)

        let newPosition = CGPoint(
            x: currentPosition.x + offsetX,
            y: currentPosition.y + offsetY
        )

        return constrainToScreen(newPosition)
    }

    /// Generate corner position for foraging/eat task
    func foragingCorner() -> CGPoint {
        guard let screen = NSScreen.main else { return currentPosition }

        let frame = screen.frame
        let petSize: CGFloat = 64
        let margin = config.boundaryMargin

        // Choose a random corner (0: bottom-left, 1: bottom-right, 2: top-left, 3: top-right)
        let corner = Int.random(in: 0...3)

        var x: CGFloat, y: CGFloat
        switch corner {
        case 0:  // Bottom-left
            x = frame.minX + margin
            y = frame.minY + margin
        case 1:  // Bottom-right
            x = frame.maxX - petSize - margin
            y = frame.minY + margin
        case 2:  // Top-left
            x = frame.minX + margin
            y = frame.maxY - petSize - margin
        case 3:  // Top-right
            x = frame.maxX - petSize - margin
            y = frame.maxY - petSize - margin
        default:
            x = frame.minX + margin
            y = frame.minY + margin
        }

        return CGPoint(x: x, y: y)
    }

    /// Generate position near mouse for seekAttention task
    func nearMousePosition() -> CGPoint {
        let mouseLocation = NSEvent.mouseLocation

        // Position near mouse with some offset (not exactly on mouse)
        let offsetRange: ClosedRange<CGFloat> = 30...80
        let offsetX = CGFloat.random(in: offsetRange)
        let offsetY = CGFloat.random(in: offsetRange)

        let nearPosition = CGPoint(
            x: mouseLocation.x + offsetX,
            y: mouseLocation.y - offsetY  // Negative because screen coords are flipped
        )

        return constrainToScreen(nearPosition)
    }

    // MARK: - Movement Direction

    /// Update movement direction based on position delta
    private func updateDirection(dx: CGFloat, dy: CGFloat) {
        // Determine direction: prioritize horizontal movement
        // Pure horizontal or vertical movement (no diagonal)
        let newDirection: MovementDirection
        if abs(dx) > abs(dy) {
            // Primarily horizontal movement
            if dx > 0 {
                newDirection = .east
            } else {
                newDirection = .west
            }
        } else {
            // Primarily vertical movement
            if dy > 0 {
                newDirection = .north  // Screen coords: positive y = up
            } else {
                newDirection = .south  // Screen coords: negative y = down
            }
        }

        // Only notify if direction changed
        if newDirection != currentDirection {
            currentDirection = newDirection
            onDirectionChange?(newDirection)
        }
    }

    // MARK: - Position Access

    /// Get current position
    var position: CGPoint {
        return currentPosition
    }

    /// Check if pet has reached its target
    var hasReachedTarget: Bool {
        guard let target = targetPosition else { return true }
        let distance = sqrt(pow(target.x - currentPosition.x, 2) +
                           pow(target.y - currentPosition.y, 2))
        return distance < config.moveSpeed
    }
}
