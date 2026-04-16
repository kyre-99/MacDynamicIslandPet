import AppKit
import Combine
import SwiftUI

/// Custom NSView that tracks mouse hover events and changes cursor
class HoverTrackingView: NSView {
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove old tracking area
        if let oldTracking = trackingArea {
            removeTrackingArea(oldTracking)
        }

        // Create new tracking area for the entire view bounds
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect,
            .assumeInside
        ]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        HoverInteractionManager.shared.showHandCursor()
    }

    override func mouseExited(with event: NSEvent) {
        HoverInteractionManager.shared.resetCursor()
    }
}

/// SwiftUI wrapper for HoverTrackingView
struct HoverTrackingViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> HoverTrackingView {
        let view = HoverTrackingView()
        return view
    }

    func updateNSView(_ nsView: HoverTrackingView, context: Context) {
        // No update needed
    }
}

/// Manages hover interactions with the pet - cursor changes and pat detection
class HoverInteractionManager {
    static let shared = HoverInteractionManager()

    // Detection radius around pet for "near" detection (pixels)
    var nearDetectionRadius: CGFloat = 80

    // Detection for "on pet" (for actual click)
    var onPetRadius: CGFloat = 32

    private var petViewModel: PetViewModel?
    private var lastPatTime: Date = Date.distantPast

    // Pat cooldown to prevent spam (seconds)
    private let patCooldown: TimeInterval = 0.5

    private init() {}

    func setViewModel(_ viewModel: PetViewModel) {
        self.petViewModel = viewModel
    }

    // MARK: - Cursor Management

    /// Change cursor to hand when hovering near pet
    func showHandCursor() {
        NSCursor.pointingHand.set()
    }

    /// Reset cursor to default
    func resetCursor() {
        NSCursor.arrow.set()
    }

    // MARK: - Pat Interaction

    /// Handle pat interaction (click when cursor is hand)
    func handlePat() {
        guard let viewModel = petViewModel else { return }

        // Check cooldown
        let now = Date()
        if now.timeIntervalSince(lastPatTime) < patCooldown {
            return
        }
        lastPatTime = now

        // Pat effect: increase happiness and energy
        viewModel.onUserInteraction()
        viewModel.setState(.happy)

        // 触发拍拍计数（用于连续拍拍触发吐槽）
        CommentTriggerManager.shared.handlePetPat()

        // 触发拍拍评论（动作吐槽）
        ActionCommentManager.shared.onPetPatted()

        print("👋 精灵被拍拍了！")

        // Reset to idle after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            viewModel.setState(.idle)
        }
    }

    /// Check if mouse position is near pet
    func isMouseNearPet(mouseLocation: CGPoint, petPosition: CGPoint) -> Bool {
        let petCenterX = petPosition.x + 32
        let petCenterY = petPosition.y + 32
        let distance = sqrt(
            pow(mouseLocation.x - petCenterX, 2) +
            pow(mouseLocation.y - petCenterY, 2)
        )
        return distance <= nearDetectionRadius
    }
}