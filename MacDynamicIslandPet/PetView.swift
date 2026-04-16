import SwiftUI
import Combine

/// A GIF-based pet rendering component
/// Displays pixel-art sprite animations from GIF files
struct PetView: View {
    @ObservedObject var viewModel: PetViewModel
    @StateObject private var gifAnimator = GIFAnimator()
    @ObservedObject private var animationStateMachine = AnimationStateMachine.shared

    // Animation state
    @State private var lastPosition: CGPoint = .zero
    @State private var lastPositionUpdateTime: Date = Date()

    // Drag gesture state
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var lastClickTime: Date = Date.distantPast

    // Hover state for cursor change
    @State private var isHovering: Bool = false

    // Speed threshold for movement detection (pixels per frame)
    // US-002: Use 2 pixels threshold for idle detection
    private let idleThreshold: CGFloat = 2.0

    // Callbacks
    var onDragPositionUpdate: ((CGPoint) -> Void)?
    var onPetClick: (() -> Void)?

    // Conversation UI callback
    var onShowConversation: (() -> Void)?

    // Evolution tooltip callbacks (US-009)
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?

    // Interaction coordination callbacks (for TaskScheduler integration)
    var onInteractionStart: (() -> Void)?  // Called when click/drag starts
    var onDragStart: (() -> Void)?         // Called when drag begins
    var onDragEnd: (() -> Void)?           // Called when drag finishes

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hover tracking view (invisible, but tracks mouse enter/exit)
                HoverTrackingViewRepresentable()

                // Display GIF frame or fallback
                if let frame = gifAnimator.currentFrame {
                    Image(nsImage: frame)
                        .resizable()
                        .interpolation(.none)  // Preserve pixel art look
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: 64 * viewModel.scale,
                            height: 64 * viewModel.scale
                        )
                        .offset(dragOffset)
                } else {
                    // Fallback: simple placeholder while loading
                    Rectangle()
                        .fill(Color.clear)
                        .frame(
                            width: 64 * viewModel.scale,
                            height: 64 * viewModel.scale
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                // US-009: Notify AppDelegate to show/hide tooltip window
                isHovering = hovering
                if hovering {
                    onHoverEnter?()
                } else {
                    onHoverExit?()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        let distance = sqrt(value.translation.width * value.translation.width +
                                           value.translation.height * value.translation.height)
                        if distance < 5 {
                            return
                        }
                        isDragging = true
                        gifAnimator.stopAnimation()
                        onDragStart?()
                        print("Started dragging")
                    }
                    handleDragChanged(value)
                }
                .onEnded { value in
                    if isDragging {
                        print("Drag ended")
                        handleDragEnded(value)
                        isDragging = false
                        dragOffset = .zero
                        onDragEnd?()
                        // Resume animation after brief pause
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            updateAnimationFromStateMachine()
                        }
                    } else {
                        let now = Date()
                        let timeDiff = now.timeIntervalSince(lastClickTime)
                        if timeDiff < 0.3 {
                            print("Double tap detected")
                            handleDoubleClick()
                        } else {
                            print("Single tap detected")
                            handleTap()
                        }
                        lastClickTime = now
                    }
                }
        )
        .onChange(of: viewModel.position) { newPosition in
            handlePositionChange(newPosition)
        }
        .onChange(of: viewModel.currentState) { newState in
            handleStateChange(newState)
        }
        .onChange(of: viewModel.currentTask) { newTask in
            // US-005: Update animation state based on task
            handleTaskChange(newTask)
        }
        .onChange(of: animationStateMachine.currentState) { newState in
            // React to state machine state changes
            updateAnimationFromStateMachine()
        }
        .onChange(of: animationStateMachine.currentDirection) { newDirection in
            // React to direction changes from state machine
            // BUT: Don't interrupt once-mode animations (wakeup, fighting)
            // These need to complete to trigger state transitions
            let currentAnimState = animationStateMachine.currentState
            if currentAnimState == .wakeup || currentAnimState == .fighting {
                // Don't reload animation during once-mode animations
                // Just update direction info (animation will update after completion)
                print("PetView: Direction changed during once-mode animation (\(currentAnimState.rawValue)), not reloading")
                return
            }
            updateAnimationFromStateMachine()
        }
        .onAppear {
            loadDefaultAnimation()
            // US-009: Connect GIFAnimator completion callback to state machine
            gifAnimator.onAnimationComplete = {
                animationStateMachine.onAnimationComplete()
            }
        }
    }

    // MARK: - Animation Management

    private func loadDefaultAnimation() {
        // Initialize with idle state using wake_up_south as base
        animationStateMachine.transitionTo(.idle, force: true)
        updateAnimationFromStateMachine()
        lastPosition = viewModel.position
        lastPositionUpdateTime = Date()
    }

    private func handlePositionChange(_ newPosition: CGPoint) {
        guard !isDragging else { return }

        // Calculate movement speed (pixels per frame)
        let dx = newPosition.x - lastPosition.x
        let dy = newPosition.y - lastPosition.y

        // Calculate time elapsed since last position update
        let now = Date()
        let timeElapsed = now.timeIntervalSince(lastPositionUpdateTime)

        // Calculate speed in pixels per second
        let distance = sqrt(dx * dx + dy * dy)
        let speed = timeElapsed > 0 ? distance / timeElapsed : 0

        // Convert to pixels per frame (assuming ~30fps)
        let speedPerFrame = speed * (1.0 / 30.0)

        // Determine movement direction based on position delta
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

        // Update state machine based on movement speed
        animationStateMachine.updateBasedOnMovement(speed: speedPerFrame)
        animationStateMachine.updateDirection(newDirection)

        lastPosition = newPosition
        lastPositionUpdateTime = now
    }

    /// Update GIF animation based on state machine's current state
    private func updateAnimationFromStateMachine() {
        guard let animationName = animationStateMachine.currentAnimationName else {
            // No animation available - keep current frame visible, don't clear it
            // This prevents the pet from disappearing during animation transitions
            print("PetView: No animation name available, keeping current frame")
            gifAnimator.stopAnimation()
            return
        }

        // Check if we need to show static frame for idle state
        if animationStateMachine.shouldShowStaticFrame() {
            // Load animation and set to static frame
            let loadSuccess = gifAnimator.loadFromAsset(named: animationName)
            if loadSuccess {
                let frameIndex = animationStateMachine.getStaticFrameIndex()
                gifAnimator.stopAnimation()
                gifAnimator.setFrame(at: frameIndex)
            } else {
                // Load failed - keep current frame to prevent disappearing
                print("PetView: Failed to load animation \(animationName), keeping current frame")
            }
        } else {
            // Load animation with appropriate playback mode
            let loadSuccess = gifAnimator.loadFromAsset(named: animationName)
            if loadSuccess {
                // Set playback mode based on state
                switch animationStateMachine.currentPlaybackMode {
                case .loop:
                    gifAnimator.mode = .loop
                    gifAnimator.startAnimation()
                case .once:
                    gifAnimator.mode = .once
                    gifAnimator.startAnimation()
                case .staticFrame(let index):
                    gifAnimator.stopAnimation()
                    gifAnimator.setFrame(at: index)
                }
            } else {
                // Load failed - keep current frame to prevent disappearing
                print("PetView: Failed to load animation \(animationName), keeping current frame")
            }
        }
    }

    private func handleStateChange(_ state: PetState) {
        switch state {
        case .idle:
            // Normal animation behavior - handled by AnimationStateMachine
            updateAnimationFromStateMachine()
        case .alert:
            // Could use wake_up animation here in future
            // For now, pause on current frame
            gifAnimator.stopAnimation()
        case .happy:
            // Speed up animation for happy state
            gifAnimator.customFrameRate = 15  // Faster playback
            gifAnimator.startAnimation()
            // Reset to normal speed after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + viewModel.currentState.duration) {
                gifAnimator.customFrameRate = nil
                updateAnimationFromStateMachine()
            }
        }
    }

    // US-005: Handle task changes from TaskScheduler
    private func handleTaskChange(_ task: PetBehaviorTask) {
        // Convert PetBehaviorTask to PetTask for AnimationStateMachine
        // Note: We need to import or reference PetTask from TaskScheduler
        // Using a simple conversion here
        switch task {
        case .idle:
            // Reset to idle animation (stationary)
            animationStateMachine.transitionTo(.idle, force: true)
        case .sleep:
            // Trigger sleep animation (stationary)
            animationStateMachine.transitionTo(.sleeping, force: true)
        case .eat:
            // Trigger eating animation (stationary)
            animationStateMachine.transitionTo(.eating, force: true)
        case .explore:
            // Explore task: start running animation and movement
            // Must force to running state so PetMover allows movement
            animationStateMachine.transitionTo(.running, force: true)
        case .seekAttention:
            // Seek attention: running animation and movement
            animationStateMachine.transitionTo(.running, force: true)
        }
    }

    // MARK: - Interaction Handlers

    private func handleTap() {
        onInteractionStart?()

        // Show interaction options menu (pat or chat)
        let position = viewModel.position
        InteractionOptionsManager.shared.showWindow(
            near: position,
            onPat: {
                HoverInteractionManager.shared.handlePat()
            },
            onChat: {
                viewModel.onUserInteraction()
                viewModel.setState(.happy)
                onShowConversation?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak viewModel] in
                    viewModel?.setState(.idle)
                }
            }
        )

        onPetClick?()
    }

    private func handleDoubleClick() {
        onInteractionStart?()
        viewModel.onUserInteraction()
        viewModel.onUserInteraction()
        viewModel.setState(.happy)

        // Extra animation effect for double click
        gifAnimator.customFrameRate = 20  // Very fast for excitement

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak viewModel] in
            viewModel?.setState(.idle)
            gifAnimator.customFrameRate = nil
        }

        onPetClick?()
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        dragOffset = value.translation

        // Find the pet window specifically by checking contentView type
        // Don't use first floating window as it might be the bubble window
        if let petWindow = NSApplication.shared.windows.first(where: {
            $0.level == .screenSaver && $0.contentView is NSHostingView<PetView>
        }) {
            let currentFrame = petWindow.frame
            let newOrigin = CGPoint(
                x: currentFrame.origin.x + value.translation.width,
                y: currentFrame.origin.y - value.translation.height
            )
            onDragPositionUpdate?(newOrigin)
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            dragOffset = .zero
        }

        // Find the pet window specifically by checking contentView type
        if let petWindow = NSApplication.shared.windows.first(where: {
            $0.level == .screenSaver && $0.contentView is NSHostingView<PetView>
        }) {
            let currentFrame = petWindow.frame
            let finalOrigin = CGPoint(
                x: currentFrame.origin.x + value.translation.width,
                y: currentFrame.origin.y - value.translation.height
            )
            viewModel.setPosition(finalOrigin)
            onDragPositionUpdate?(finalOrigin)
        }

        viewModel.onUserInteraction()
    }
}

// MARK: - Preview

#if DEBUG
struct PetView_Previews: PreviewProvider {
    static var previews: some View {
        PetView(viewModel: PetViewModel())
            .frame(width: 100, height: 100)
    }
}
#endif