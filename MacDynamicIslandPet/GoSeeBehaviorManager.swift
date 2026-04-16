import Foundation
import AppKit
import Combine

/// Manages the "go see" behavior when user switches windows
/// US-008: Pet moves to window location to observe and comment
class GoSeeBehaviorManager: ObservableObject {
    static let shared = GoSeeBehaviorManager()

    // MARK: - Published Properties

    /// Whether a go-see action is currently in progress
    @Published var isGoSeeInProgress: Bool = false

    /// Target window position for current go-see
    @Published var targetWindowPosition: CGPoint?

    // MARK: - Private Properties

    private let windowObserver = WindowObserver.shared
    private let petMover = PetMover.shared
    private let screenCapture = ScreenCaptureService.shared
    private let llmService = LLMService.shared
    private let commentGenerator = CommentGenerator.shared
    private let selfTalkManager = SelfTalkManager.shared
    private let perceptionMemory = PerceptionMemoryManager.shared

    private var cancellables = Set<AnyCancellable>()

    /// Cooldown between go-see actions (seconds)
    private let goSeeCooldown: TimeInterval = 10.0  // Reduced for testing, originally 30.0

    /// Last go-see time
    private var lastGoSeeTime: Date = Date.distantPast

    /// Whether go-see is enabled
    private var goSeeEnabled: Bool = true  // 默认禁用GoSee功能，避免辅助功能权限弹窗

    // MARK: - Initialization

    private init() {
        print("🟣 GoSeeBehaviorManager: initializing...")
        // 只有在启用时才订阅窗口切换事件
        if goSeeEnabled {
            setupWindowSwitchObserver()
            print("🟣 GoSeeBehaviorManager: window observer setup complete")
        } else {
            print("🟣 GoSeeBehaviorManager: go-see disabled, skipping window observer setup")
        }
    }

    // MARK: - Setup

    /// Subscribe to window switch events from WindowObserver
    private func setupWindowSwitchObserver() {
        // Subscribe to app changes via WindowObserver's published property
        windowObserver.$currentActiveApp
            .dropFirst()  // Skip initial value
            .sink { [weak self] appName in
                self?.handleWindowSwitch(appName: appName)
            }
            .store(in: &cancellables)
    }

    // MARK: - Window Switch Handler

    /// Handle window switch - trigger go-see behavior
    private func handleWindowSwitch(appName: String) {
        print("🟣 GoSeeBehaviorManager: handleWindowSwitch called, appName=\(appName)")

        // Check cooldown
        let cooldownRemaining = goSeeCooldown - Date().timeIntervalSince(lastGoSeeTime)
        print("🟣 GoSeeBehaviorManager: cooldown remaining=\(cooldownRemaining)s, goSeeEnabled=\(goSeeEnabled), isGoSeeInProgress=\(isGoSeeInProgress)")

        guard Date().timeIntervalSince(lastGoSeeTime) >= goSeeCooldown else {
            print("GoSeeBehavior: Cooldown active, skipping")
            return
        }

        // Check if go-see is enabled and not already in progress
        guard goSeeEnabled && !isGoSeeInProgress else {
            print("🟣 GoSeeBehaviorManager: go-see disabled or in progress")
            return
        }

        // Don't trigger if pet is currently being dragged or in conversation
        let bubbleShowing = selfTalkManager.shouldShowBubble
        print("🟣 GoSeeBehaviorManager: selfTalkManager.shouldShowBubble=\(bubbleShowing)")
        guard !bubbleShowing else {
            return
        }

        print("GoSeeBehavior: Window switched to '\(appName)', triggering go-see")

        // Start go-see sequence
        startGoSeeSequence(appName: appName)
    }

    // MARK: - Go-See Sequence

    /// Start the go-see sequence: move → capture → analyze → comment
    private func startGoSeeSequence(appName: String) {
        print("🟣 GoSeeBehaviorManager: startGoSeeSequence for '\(appName)'")
        isGoSeeInProgress = true
        lastGoSeeTime = Date()

        // Step 1: Get window position
        guard let windowPosition = getActiveWindowPosition() else {
            print("🟣 GoSeeBehaviorManager: No window position, using fallback")
            // Fallback: move to random position near screen edge
            let fallbackPosition = generateFallbackPosition()
            executeGoSeeMovement(to: fallbackPosition, appName: appName)
            return
        }

        print("🟣 GoSeeBehaviorManager: Window position: \(windowPosition)")
        targetWindowPosition = windowPosition

        // Step 2: Move pet to window location
        executeGoSeeMovement(to: windowPosition, appName: appName)
    }

    /// Execute movement to window position
    private func executeGoSeeMovement(to position: CGPoint, appName: String) {
        print("🟣 GoSeeBehaviorManager: executeGoSeeMovement to \(position)")
        // Constrain position to screen bounds
        let constrainedPosition = constrainToScreen(position)

        // Set movement target
        petMover.moveTo(constrainedPosition)

        // Wait for movement completion (approximate)
        // Movement speed is per-frame, assume 30fps for time calculation
        // moveSpeed = 2.0 pixels/frame, so ~60 pixels/second
        let currentPos = petMover.position
        let pixelsPerSecond = petMover.config.moveSpeed * 30.0
        let distance = sqrt(pow(constrainedPosition.x - currentPos.x, 2) +
                           pow(constrainedPosition.y - currentPos.y, 2))
        let estimatedMoveTime = max(1.0, distance / pixelsPerSecond + 1.0)  // Minimum 1 second

        print("🟣 GoSeeBehaviorManager: Estimated move time: \(estimatedMoveTime)s (distance: \(distance), speed: \(pixelsPerSecond)px/s)")

        // Schedule capture and analysis after movement
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedMoveTime) { [weak self] in
            print("🟣 GoSeeBehaviorManager: Movement complete, performing capture")
            self?.performCaptureAndAnalysis(appName: appName, targetPosition: constrainedPosition)
        }
    }

    /// Perform screen capture and analysis after movement
    private func performCaptureAndAnalysis(appName: String, targetPosition: CGPoint) {
        print("🟣 GoSeeBehaviorManager: performCaptureAndAnalysis")
        // Capture screen
        screenCapture.captureScreenAsync { [weak self] base64Result in
            print("🟣 GoSeeBehaviorManager: Screen capture result: \(base64Result != nil ? "success" : "nil")")
            guard let self = self, let base64 = base64Result else {
                // Fallback: generate comment without vision
                self?.generateAndShowComment(appName: appName, visualResult: nil)
                return
            }

            // Analyze with vision
            print("🟣 GoSeeBehaviorManager: Calling LLMService.analyzeScreenWithVision")
            self.llmService.analyzeScreenWithVision(
                imageBase64: base64,
                appName: appName,
                completion: { [weak self] result in
                    print("🟣 GoSeeBehaviorManager: LLM result received - \(result)")
                    guard let self = self else { return }

                    switch result {
                    case .success(let visualResult):
                        print("🟣 GoSeeBehaviorManager: Visual analysis success - \(visualResult.briefDescription)")
                        self.generateAndShowComment(appName: appName, visualResult: visualResult)
                    case .failure(let error):
                        print("🟣 GoSeeBehaviorManager: LLM failed with error: \(error)")
                        // Fallback: generate comment without vision
                        self.generateAndShowComment(appName: appName, visualResult: nil)
                    }
                }
            )
        }
    }

    /// Generate comment and show bubble
    private func generateAndShowComment(appName: String, visualResult: VisualAnalysisResult?) {
        if let result = visualResult {
            // 有视觉分析结果时，使用视觉分析生成评论
            commentGenerator.generateCommentWithVision(
                visualResult: result,
                appName: appName
            ) { [weak self] commentResult in
                guard let self = self else { return }

                switch commentResult {
                case .success(let comment):
                    self.showCommentBubble(comment: comment, appName: appName, visualResult: result)
                case .failure:
                    self.showFallbackBubble(appName: appName)
                }
            }
        } else {
            // 无视觉分析结果时，使用拟人化气泡生成（包含记忆、性格、进化等级）
            commentGenerator.generateHumanoidBubble(
                triggerScene: .windowSwitch
            ) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let bubbleResult):
                    // 创建 fallback visual result 用于记忆保存
                    let fallbackResult = VisualAnalysisResult(
                        activityType: self.windowObserver.currentAppCategory.displayName,
                        mainWindow: nil,
                        visibleText: nil,
                        uiElements: nil,
                        briefDescription: "使用\(appName)",
                        userBehavior: nil,
                        confidence: 0.5
                    )
                    self.showCommentBubble(comment: bubbleResult.content, appName: appName, visualResult: fallbackResult)
                case .failure:
                    self.showFallbackBubble(appName: appName)
                }
            }
        }
    }

    /// Show comment bubble
    private func showCommentBubble(comment: String, appName: String, visualResult: VisualAnalysisResult?) {
        print("🟣 GoSeeBehaviorManager: showCommentBubble called with comment='\(comment)'")

        // Save to perception memory
        perceptionMemory.savePerception(
            appName: appName,
            activityDescription: visualResult?.detailedDescription ?? "使用\(appName)",
            screenshotSummary: visualResult != nil ? buildScreenshotSummary(visualResult!) : nil,
            petReaction: comment
        )

        // Show bubble via SelfTalkManager (emotion will be set by AppDelegate)
        DispatchQueue.main.async { [weak self] in
            print("🟣 GoSeeBehaviorManager: Setting bubbleText='\(comment)', shouldShowBubble=true")
            self?.selfTalkManager.bubbleText = comment
            self?.selfTalkManager.shouldShowBubble = true
        }

        // 备用清理：15秒后清理状态（气泡视图自己控制消失，这里是备用）
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            print("🟣 GoSeeBehaviorManager: Cleanup after go-see")
            self?.selfTalkManager.hideBubble()
            self?.isGoSeeInProgress = false
            self?.targetWindowPosition = nil
            self?.lastGoSeeTime = Date()
        }
    }

    /// 构建详细的截图摘要（用于保存记忆）
    private func buildScreenshotSummary(_ result: VisualAnalysisResult) -> String {
        var summary = "活动：\(result.activityType)"

        if let mainWindow = result.mainWindow, !mainWindow.isEmpty {
            summary += " | 窗口：\(mainWindow)"
        }
        if let visibleText = result.visibleText, !visibleText.isEmpty {
            summary += " | 文本：\(visibleText)"
        }
        if let uiElements = result.uiElements, !uiElements.isEmpty {
            summary += " | 界面：\(uiElements)"
        }
        if let userBehavior = result.userBehavior, !userBehavior.isEmpty {
            summary += " | 行为：\(userBehavior)"
        }

        return summary
    }

    /// Show fallback bubble when all else fails
    private func showFallbackBubble(appName: String) {
        let fallbackComment = getFallbackComment(appName: appName)

        perceptionMemory.savePerception(
            appName: appName,
            activityDescription: "切换到\(appName)",
            petReaction: fallbackComment
        )

        selfTalkManager.bubbleText = fallbackComment
        selfTalkManager.shouldShowBubble = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.selfTalkManager.hideBubble()
            self?.isGoSeeInProgress = false
            self?.targetWindowPosition = nil
        }
    }

    /// Get fallback comment for a specific app
    private func getFallbackComment(appName: String) -> String {
        let appCategory = windowObserver.getAppCategory(appName)
        switch appCategory {
        case .development:
            return "代码写得怎么样啦~"
        case .communication:
            return "聊得开心吗~"
        case .browser:
            return "又在看网页啦~"
        case .entertainment:
            return "视频好看吗~"
        case .productivity:
            return "文档写到哪了~"
        case .other:
            return "跑去看看了~"
        }
    }

    // MARK: - Window Position Detection (AXUIElement API)

    /// Get the position of the active window using Accessibility API
    /// US-008: Uses AXUIElement to get window bounds
    private func getActiveWindowPosition() -> CGPoint? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        // Get focused window
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let window = focusedWindow else {
            print("GoSeeBehavior: Could not get focused window for app: \(app.localizedName ?? "Unknown")")
            return nil
        }

        // Get window position and size
        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        let posResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, &sizeValue)

        guard posResult == .success, sizeResult == .success,
              let positionAX = positionValue,
              let sizeAX = sizeValue else {
            return nil
        }

        // Convert AXValue to CGPoint and CGSize
        var windowPos: CGPoint = .zero
        var windowSize: CGSize = .zero

        AXValueGetValue(positionAX as! AXValue, AXValueType.cgPoint, &windowPos)
        AXValueGetValue(sizeAX as! AXValue, AXValueType.cgSize, &windowSize)

        // Target position: top edge of window, slightly offset
        let targetX = windowPos.x + windowSize.width / 2  // Center of window
        let targetY = windowPos.y + windowSize.height + 20  // Just above window top

        print("GoSeeBehavior: Window position: (\(windowPos.x), \(windowPos.y)), size: (\(windowSize.width), \(windowSize.height))")
        print("GoSeeBehavior: Target pet position: (\(targetX), \(targetY))")

        return CGPoint(x: targetX, y: targetY)
    }

    /// Generate fallback position when window detection fails
    private func generateFallbackPosition() -> CGPoint {
        // Move to screen edge near current position
        guard let screen = NSScreen.main else { return petMover.position }

        let frame = screen.frame

        // Default: move to center-top of screen
        return CGPoint(
            x: frame.midX,
            y: frame.maxY - 100
        )
    }

    /// Constrain position to screen bounds
    private func constrainToScreen(_ point: CGPoint) -> CGPoint {
        guard let screen = NSScreen.main else { return point }

        let frame = screen.frame
        let petSize: CGFloat = 64
        let margin: CGFloat = 20

        let constrainedX = max(
            frame.minX + margin,
            min(frame.maxX - petSize - margin, point.x)
        )
        let constrainedY = max(
            frame.minY + margin,
            min(frame.maxY - petSize - margin, point.y)
        )

        return CGPoint(x: constrainedX, y: constrainedY)
    }

    // MARK: - Public Control

    /// Enable/disable go-see behavior
    func setGoSeeEnabled(_ enabled: Bool) {
        goSeeEnabled = enabled
        print("GoSeeBehavior: \(enabled ? "Enabled" : "Disabled")")

        if enabled {
            // 启用时订阅窗口切换事件
            setupWindowSwitchObserver()
            print("🟣 GoSeeBehaviorManager: window observer setup")
        } else {
            // 禁用时取消订阅
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
            print("🟣 GoSeeBehaviorManager: window observer cancelled")
        }
    }

    /// Manually trigger go-see (for testing)
    func triggerGoSee() {
        let appName = windowObserver.currentActiveApp
        startGoSeeSequence(appName: appName)
    }
}