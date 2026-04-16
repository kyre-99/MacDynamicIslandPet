import SwiftUI
import ImageIO
import CoreGraphics

/// GIF animation playback mode
enum GIFAnimationMode {
    case loop       // Play animation repeatedly
    case once       // Play animation once and stop
}

/// A class that parses and plays GIF animations
/// Uses ImageIO framework to extract frames and Timer for playback
class GIFAnimator: ObservableObject {
    // MARK: - Published Properties

    /// Current frame as NSImage for SwiftUI display
    @Published var currentFrame: NSImage?

    /// Whether animation is currently playing
    @Published var isPlaying: Bool = false

    /// Current frame index (for debugging/info)
    @Published var currentFrameIndex: Int = 0

    // MARK: - Configuration

    /// Animation playback mode
    var mode: GIFAnimationMode = .loop

    /// Custom frame rate (frames per second)
    /// If nil, uses GIF's intrinsic timing
    var customFrameRate: Double? = nil

    /// Callback triggered when once-mode animation completes (US-009)
    var onAnimationComplete: (() -> Void)?

    // MARK: - Private Properties

    /// Pre-loaded frame images
    private var frames: [NSImage] = []

    /// Frame durations from GIF (in seconds)
    private var frameDurations: [TimeInterval] = []

    /// Animation timer
    private var animationTimer: Timer?

    /// Total number of frames
    private var totalFrames: Int = 0

    // MARK: - Initialization

    init() {}

    deinit {
        stopAnimation()
    }

    // MARK: - GIF Loading

    /// Load GIF from NSDataAsset (Asset Catalog data asset)
    /// - Parameter assetName: Name of the data asset in Asset Catalog
    /// - Returns: True if loading succeeded
    @discardableResult
    func loadFromAsset(named assetName: String) -> Bool {
        guard let dataAsset = NSDataAsset(name: assetName) else {
            print("GIFAnimator: Failed to load data asset named '\(assetName)'")
            return false
        }

        return loadFromData(dataAsset.data)
    }

    /// Load GIF from raw data
    /// - Parameter data: Raw GIF data
    /// - Returns: True if loading succeeded
    @discardableResult
    func loadFromData(_ data: Data) -> Bool {
        // Create image source from data
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("GIFAnimator: Failed to create CGImageSource from data")
            return false
        }

        return loadFromImageSource(imageSource)
    }

    /// Load GIF from URL
    /// - Parameter url: URL pointing to GIF file
    /// - Returns: True if loading succeeded
    @discardableResult
    func loadFromURL(_ url: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("GIFAnimator: Failed to create CGImageSource from URL: \(url)")
            return false
        }

        return loadFromImageSource(imageSource)
    }

    /// Parse GIF from CGImageSource and preload all frames
    /// - Parameter imageSource: CGImageSource created from GIF data
    /// - Returns: True if parsing succeeded
    private func loadFromImageSource(_ imageSource: CGImageSource) -> Bool {
        // Stop any existing animation
        stopAnimation()

        // Get frame count
        let frameCount = CGImageSourceGetCount(imageSource)
        guard frameCount > 0 else {
            print("GIFAnimator: GIF has no frames")
            return false
        }

        totalFrames = frameCount

        // Pre-load all frames and durations
        // Keep old frames in case loading fails (to prevent disappearing)
        let oldFrames = frames
        let oldFrame = currentFrame
        frames = []
        frameDurations = []

        for index in 0..<frameCount {
            // Extract frame image
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else {
                print("GIFAnimator: Failed to extract frame at index \(index)")
                continue
            }

            // Convert to NSImage
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            frames.append(nsImage)

            // Get frame duration from GIF properties
            let duration = getFrameDuration(imageSource: imageSource, index: index)
            frameDurations.append(duration)
        }

        guard frames.count > 0 else {
            print("GIFAnimator: No frames were successfully loaded - keeping old frame")
            // Restore old frames to prevent disappearing
            frames = oldFrames
            currentFrame = oldFrame
            return false
        }

        // Set initial frame
        currentFrame = frames[0]
        currentFrameIndex = 0

        print("GIFAnimator: Loaded \(frames.count) frames from GIF")
        return true
    }

    /// Get duration for a specific frame from GIF properties
    /// - Parameters:
    ///   - imageSource: CGImageSource
    ///   - index: Frame index
    /// - Returns: Duration in seconds (defaults to 0.1 if not specified)
    private func getFrameDuration(imageSource: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [String: Any] else {
            return 0.1  // Default duration
        }

        // Check for GIF-specific frame duration
        guard let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return 0.1
        }

        // Get delay time (in seconds)
        // Note: Some GIFs use UnclampedDelayTime which needs conversion
        if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
            return max(0.01, delayTime)  // Ensure minimum duration
        }

        // Some GIFs store delay in centiseconds
        if let unclampedDelayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double {
            return max(0.01, unclampedDelayTime)
        }

        return 0.1  // Default fallback
    }

    // MARK: - Animation Control

    /// Start playing the animation
    func startAnimation() {
        guard frames.count > 0 else {
            print("GIFAnimator: No frames to animate")
            return
        }

        // Don't restart if already playing
        guard !isPlaying else { return }

        isPlaying = true

        // Determine frame interval based on custom frame rate or first frame duration
        let interval: TimeInterval
        if let customRate = customFrameRate {
            interval = 1.0 / customRate
        } else {
            interval = frameDurations.count > 0 ? frameDurations[0] : 0.1
        }

        // Create timer for frame switching
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }

        // Ensure timer runs in common mode (not just default mode)
        RunLoop.current.add(animationTimer!, forMode: .common)
    }

    /// Stop the animation
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isPlaying = false
    }

    /// Reset to first frame
    func reset() {
        stopAnimation()
        if frames.count > 0 {
            currentFrame = frames[0]
            currentFrameIndex = 0
        }
    }

    /// Advance to next frame
    private func advanceFrame() {
        guard frames.count > 0 else { return }

        let nextIndex = currentFrameIndex + 1

        if nextIndex >= frames.count {
            // End of animation
            switch mode {
            case .loop:
                // Loop back to start
                currentFrameIndex = 0
            case .once:
                // Stop at last frame
                stopAnimation()
                print("🎬 GIFAnimator: Animation completed (once mode), calling onAnimationComplete")
                // US-009: Notify animation completion
                onAnimationComplete?()
                return
            }
        } else {
            currentFrameIndex = nextIndex
        }

        // Update current frame
        currentFrame = frames[currentFrameIndex]

        // Adjust timer interval for next frame if using GIF timing
        if customFrameRate == nil && animationTimer != nil {
            let nextDuration = frameDurations.count > currentFrameIndex ? frameDurations[currentFrameIndex] : 0.1
            animationTimer?.invalidate()
            animationTimer = Timer.scheduledTimer(withTimeInterval: nextDuration, repeats: true) { [weak self] _ in
                self?.advanceFrame()
            }
            RunLoop.current.add(animationTimer!, forMode: .common)
        }
    }

    // MARK: - Utility

    /// Get total frame count
    var frameCount: Int {
        return frames.count
    }

    /// Check if GIF is loaded
    var hasFrames: Bool {
        return frames.count > 0
    }

    /// Get frame at specific index (for manual frame control)
    func getFrame(at index: Int) -> NSImage? {
        guard index >= 0 && index < frames.count else { return nil }
        return frames[index]
    }

    /// Set specific frame (for manual frame control)
    func setFrame(at index: Int) {
        guard index >= 0 && index < frames.count else { return }
        currentFrame = frames[index]
        currentFrameIndex = index
    }
}