import Foundation
import AppKit
import CoreGraphics
import Combine

/// Service for capturing screen screenshots
/// US-003: Provides screen capture capability for visual perception
class ScreenCaptureService: ObservableObject {
    static let shared = ScreenCaptureService()

    // MARK: - Published Properties

    /// Latest captured screenshot as base64 string
    @Published var latestScreenshotBase64: String?

    /// Time of last capture
    @Published var lastCaptureTime: Date?

    /// Whether a capture is currently in progress
    @Published var isCapturing: Bool = false

    // MARK: - Configuration

    /// Default capture interval in seconds (5 minutes)
    let defaultCaptureInterval: TimeInterval = 300.0

    /// Whether automatic periodic capture is enabled
    @Published var periodicCaptureEnabled: Bool = false

    /// Custom capture interval (if different from default)
    var captureInterval: TimeInterval = 300.0

    // MARK: - Private Properties

    private var periodicTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Optionally start periodic capture
        // Can be enabled later via startPeriodicCapture()
    }

    deinit {
        stopPeriodicCapture()
    }

    // MARK: - Screen Capture

    /// Capture the main screen and return as base64 string
    /// - Parameters:
    ///   - excludeMenuBar: Whether to exclude menu bar area (default: true)
    ///   - quality: JPEG compression quality (0.0-1.0, default: 0.8)
    /// - Returns: Base64 encoded string of the screenshot
    func captureScreen(excludeMenuBar: Bool = true, quality: Float = 0.8) -> String? {
        if Thread.isMainThread {
            return captureScreenOnMain(excludeMenuBar: excludeMenuBar, quality: quality)
        }

        return DispatchQueue.main.sync {
            captureScreenOnMain(excludeMenuBar: excludeMenuBar, quality: quality)
        }
    }

    private func captureScreenOnMain(excludeMenuBar: Bool, quality: Float) -> String? {
        isCapturing = true

        guard let screen = NSScreen.main else {
            isCapturing = false
            print("ScreenCaptureService: No main screen available")
            return nil
        }

        // Get screen frame, optionally excluding menu bar
        var captureRect = screen.frame
        if excludeMenuBar {
            // Exclude top ~25 pixels (menu bar height)
            let menuBarHeight: CGFloat = 25
            captureRect = CGRect(
                x: screen.frame.minX,
                y: screen.frame.minY,
                width: screen.frame.width,
                height: screen.frame.height - menuBarHeight
            )
        }

        // Create screenshot using CGWindowListCreateImage
        let screenshot = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )

        guard let image = screenshot else {
            isCapturing = false
            print("ScreenCaptureService: Failed to create screenshot")
            return nil
        }

        // Convert to NSImage and then to base64
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            isCapturing = false
            print("ScreenCaptureService: Failed to convert image to JPEG")
            return nil
        }

        // Convert to base64
        let base64String = jpegData.base64EncodedString()

        // Update published properties
        latestScreenshotBase64 = base64String
        lastCaptureTime = Date()
        isCapturing = false

        print("ScreenCaptureService: Captured screenshot (\(jpegData.count) bytes, base64: \(base64String.count) chars)")
        return base64String
    }

    /// Capture screen asynchronously (for non-blocking use)
    func captureScreenAsync(excludeMenuBar: Bool = true, quality: Float = 0.8, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            let result = self?.captureScreenOnMain(excludeMenuBar: excludeMenuBar, quality: quality)
            completion(result)
        }
    }

    // MARK: - Periodic Capture

    /// Start periodic screen capture at configured interval
    func startPeriodicCapture(interval: TimeInterval? = nil) {
        if let customInterval = interval {
            captureInterval = customInterval
        }

        stopPeriodicCapture()  // Stop any existing timer

        periodicCaptureEnabled = true
        periodicTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            // Capture screen synchronously for periodic mode
            _ = self?.captureScreen()
        }
        RunLoop.current.add(periodicTimer!, forMode: .common)

        print("ScreenCaptureService: Started periodic capture (interval: \(captureInterval)s)")
    }

    /// Stop periodic screen capture
    func stopPeriodicCapture() {
        periodicTimer?.invalidate()
        periodicTimer = nil
        periodicCaptureEnabled = false
        print("ScreenCaptureService: Stopped periodic capture")
    }

    // MARK: - Utility Methods

    /// Get screen dimensions
    func getScreenDimensions() -> CGSize? {
        guard let screen = NSScreen.main else { return nil }
        return screen.frame.size
    }

    /// Check if enough time has passed since last capture
    func shouldCapture(minInterval: TimeInterval = 60.0) -> Bool {
        guard let lastTime = lastCaptureTime else { return true }
        return Date().timeIntervalSince(lastTime) >= minInterval
    }

    /// Clear stored screenshot data
    func clearScreenshot() {
        latestScreenshotBase64 = nil
        lastCaptureTime = nil
    }

    // MARK: - Combine Publisher

    /// Publisher for screenshot captures (for reactive integration)
    var screenshotPublisher: AnyPublisher<String, Never> {
        $latestScreenshotBase64
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
