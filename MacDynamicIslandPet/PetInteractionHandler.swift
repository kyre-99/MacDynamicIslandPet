import Foundation
import AppKit
import Combine

/// Handles pet interaction including click and drag operations
class PetInteractionHandler: ObservableObject {
    static let shared = PetInteractionHandler()

    @Published var isDragging: Bool = false
    @Published var lastDragPosition: CGPoint = .zero

    private var dragOffset: CGSize = .zero
    private var petViewModel: PetViewModel?
    private var taskScheduler: TaskScheduler?
    private var petMover: PetMover?

    // Callbacks
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onPositionUpdate: ((CGPoint) -> Void)?

    private init() {}

    func setViewModel(_ viewModel: PetViewModel) {
        self.petViewModel = viewModel
    }

    func setTaskScheduler(_ scheduler: TaskScheduler) {
        self.taskScheduler = scheduler
    }

    func setPetMover(_ mover: PetMover) {
        self.petMover = mover
    }

    // MARK: - Drag Handling

    /// Calculate offset when drag starts (where in the pet was clicked)
    func startDrag(at clickPosition: CGPoint, petPosition: CGPoint) {
        isDragging = true
        dragOffset = CGSize(
            width: clickPosition.x - petPosition.x,
            height: clickPosition.y - petPosition.y
        )
        lastDragPosition = petPosition

        // Pause autonomous behavior during drag
        taskScheduler?.pause()
        petMover?.cancelMovement()

        onDragStart?()
    }

    /// Update pet position during drag
    func updateDrag(to newClickPosition: CGPoint) {
        guard isDragging else { return }

        let newPetPosition = CGPoint(
            x: newClickPosition.x - dragOffset.width,
            y: newClickPosition.y - dragOffset.height
        )

        lastDragPosition = newPetPosition
        onPositionUpdate?(newPetPosition)
    }

    /// End drag operation
    func endDrag() {
        guard isDragging else { return }

        isDragging = false

        // Update mover position
        petMover?.setCurrentPosition(lastDragPosition)

        onDragEnd?()

        // Resume autonomous behavior after 2 second delay
        taskScheduler?.resume(after: 2.0)

        // Trigger happy state after successful drag
        petViewModel?.onUserInteraction()
    }

    // MARK: - Click Handling

    /// Handle single click on pet - interrupts current task
    func handleClick() {
        // Interrupt current task and cancel movement
        taskScheduler?.interrupt()
        petMover?.cancelMovement()

        petViewModel?.onUserInteraction()
        petViewModel?.triggerHappy()
    }

    /// Handle double click on pet - interrupts current task with extra effect
    func handleDoubleClick() {
        // Interrupt current task and cancel movement
        taskScheduler?.interrupt()
        petMover?.cancelMovement()

        // Special effect for double click - extra happiness boost
        petViewModel?.onUserInteraction()
        petViewModel?.onUserInteraction()  // Double happiness
        petViewModel?.setState(.happy)
    }

    // MARK: - Spring Animation Effect

    /// Get spring animation response for drag release
    var springAnimationDuration: TimeInterval {
        return 0.5
    }

    var springDamping: CGFloat {
        return 0.6
    }
}
