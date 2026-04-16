import Foundation
import AppKit
import Combine

class MouseMonitor: ObservableObject {
    static let shared = MouseMonitor()

    private var monitoringTimer: Timer?
    private var eventMonitor: Any?

    @Published var currentMouseLocation: CGPoint = .zero
    @Published var isMonitoring: Bool = false

    // Use PassthroughSubject for multiple subscribers
    private let locationSubject = PassthroughSubject<CGPoint, Never>()

    /// Public publisher for mouse location updates
    public var locationPublisher: AnyPublisher<CGPoint, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    // Legacy callback for backwards compatibility (only one subscriber)
    var onLocationUpdate: ((CGPoint) -> Void)? {
        didSet {
            if onLocationUpdate != nil {
                _ = locationSubject
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] location in
                        self?.onLocationUpdate?(location)
                    }
            }
        }
    }

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        // 使用 NSEvent.mouseLocation 获取鼠标位置不需要辅助功能权限
        // 直接开始监听即可

        // Use timer-based polling for global mouse position (more reliable)
        // Limit to 60fps as per requirements
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateMouseLocation()
        }
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
    }

    private func updateMouseLocation() {
        // Get mouse location in screen coordinates
        // NSEvent.mouseLocation returns location in screen coordinates (bottom-left origin)
        let location = NSEvent.mouseLocation
        currentMouseLocation = location

        // Send to all subscribers
        locationSubject.send(location)
        onLocationUpdate?(location)
    }

    func getCurrentLocation() -> CGPoint {
        return NSEvent.mouseLocation
    }

    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            print("Accessibility permissions not granted. Please grant permissions in System Preferences > Security & Privacy > Privacy > Accessibility")
        }
    }
}
