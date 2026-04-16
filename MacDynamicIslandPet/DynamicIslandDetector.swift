import Foundation
import AppKit
import Combine

class DynamicIslandDetector: ObservableObject {
    static let shared = DynamicIslandDetector()

    // Trigger area configuration
    struct TriggerConfig {
        var triggerRadius: CGFloat = 200
        var screenTopMargin: CGFloat = 100
        var debounceDelay: TimeInterval = 2.0
    }

    @Published var isMouseInTriggerArea: Bool = false
    @Published var config: TriggerConfig = TriggerConfig()

    private var mouseInAreaTimer: Timer?
    private var hideDelayTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Callbacks
    var onEnterTriggerArea: (() -> Void)?
    var onExitTriggerArea: (() -> Void)?

    private var locationCancellable: AnyCancellable?

    private init() {}

    func startDetection(mouseMonitor: MouseMonitor) {
        // Subscribe to mouse location updates using Combine
        locationCancellable = mouseMonitor.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.checkMouseLocation(location)
            }
    }

    private func checkMouseLocation(_ location: CGPoint) {
        guard let screen = NSScreen.main else { return }

        // Calculate Dynamic Island area (screen top center)
        let screenRect = screen.frame
        let centerX = screenRect.midX
        let triggerLeft = centerX - config.triggerRadius
        let triggerRight = centerX + config.triggerRadius
        let triggerBottom = screenRect.maxY - config.screenTopMargin

        // Check if mouse is in trigger area
        // Note: macOS screen coordinates have origin at bottom-left
        let isInArea = location.x >= triggerLeft &&
                       location.x <= triggerRight &&
                       location.y >= triggerBottom

        DispatchQueue.main.async {
            if isInArea && !self.isMouseInTriggerArea {
                // Just entered trigger area
                self.isMouseInTriggerArea = true
                self.handleEnterTriggerArea()
            } else if !isInArea && self.isMouseInTriggerArea {
                // Just exited trigger area
                self.scheduleHidePet()
            }
        }
    }

    private func handleEnterTriggerArea() {
        // Cancel any pending hide timer
        hideDelayTimer?.invalidate()
        hideDelayTimer = nil

        print("🏝️ Mouse entered Dynamic Island trigger area - showing pet")
        // Trigger pet show
        onEnterTriggerArea?()
    }

    private func scheduleHidePet() {
        // Delay hide by 2 seconds to avoid flickering
        hideDelayTimer?.invalidate()
        hideDelayTimer = Timer.scheduledTimer(withTimeInterval: config.debounceDelay, repeats: false) { [weak self] _ in
            self?.handleExitTriggerArea()
        }
    }

    private func handleExitTriggerArea() {
        isMouseInTriggerArea = false
        print("🏝️ Mouse exited Dynamic Island trigger area - hiding pet after delay")
        onExitTriggerArea?()
    }

    func updateConfig(triggerRadius: CGFloat? = nil, screenTopMargin: CGFloat? = nil) {
        if let radius = triggerRadius {
            config.triggerRadius = radius
        }
        if let margin = screenTopMargin {
            config.screenTopMargin = margin
        }
    }

    func getTriggerAreaRect() -> NSRect? {
        guard let screen = NSScreen.main else { return nil }

        let screenRect = screen.frame
        let centerX = screenRect.midX
        let triggerLeft = centerX - config.triggerRadius
        let triggerBottom = screenRect.maxY - config.screenTopMargin

        return NSRect(
            x: triggerLeft,
            y: triggerBottom,
            width: config.triggerRadius * 2,
            height: config.screenTopMargin
        )
    }
}
