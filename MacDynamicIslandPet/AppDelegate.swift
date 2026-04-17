import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var petWindow: NSWindow?
    var petViewModel: PetViewModel?
    var mouseMonitor: MouseMonitor?
    var dynamicIslandDetector: DynamicIslandDetector?
    var petMover: PetMover?
    var petInteractionHandler: PetInteractionHandler?
    var taskScheduler: TaskScheduler?
    var conversationManager: ConversationManager?
    var selfTalkManager: SelfTalkManager?
    var selfTalkBubbleWindow: SelfTalkBubbleWindow?

    // Scene system (house exit animation)
    var sceneWindowManager: SceneWindowManager?

    // Evolution tooltip window (US-009)
    var evolutionTooltipWindow: NSWindow?

    // Personality configuration window (US-002)
    var personalityConfigWindowController: PersonalityConfigWindowController?

    // Event windows (US-005)
    var eventAddWindowController: EventAddWindowController?
    var eventListWindowController: EventListWindowController?

    // Evolution detail window (US-009)
    var evolutionDetailWindowController: EvolutionDetailWindowController?

    // News interest configuration window (US-011)
    var newsInterestConfigWindowController: NewsInterestConfigWindowController?

    // Personality verification window (US-014)
    var personalityVerificationWindowController: PersonalityVerificationWindowController?

    // Memory convergence test window (US-015)
    var memoryConvergenceTestWindowController: MemoryConvergenceTestWindowController?

    // Settings window (API配置窗口)
    var settingsWindowController: SettingsWindowController?

    // About window
    var aboutWindowController: AboutWindowController?

    // Hotkey support
    var hideShowHotKey: Any?

    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    // US-001: Store last pet position to prevent position reset
    private var lastPetPosition: CGPoint?

    /// Whether pet was shown via Dynamic Island trigger (vs user manual toggle)
    /// This controls whether pet should be hidden when mouse exits Dynamic Island area
    private var wasShownViaDynamicIsland: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🔵 Application did finish launching")

        // 单例检查：如果已经有实例运行，退出当前实例
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.wangzehua.MacDynamicIslandPet")
        if runningApps.count > 1 {
            print("⚠️ Another instance is already running, exiting")
            NSApplication.shared.terminate(nil)
            return
        }

        // Check configuration status and show alert if needed
        checkConfigurationStatus()

        // Setup status bar item
        setupStatusBarItem()

        // Setup pet window
        setupPetWindow()

        // Setup self-talk bubble window
        setupSelfTalkBubbleWindow()

        // Setup scene system for house exit animation
        setupSceneSystem()

        // Start mouse monitoring
        startMouseMonitoring()

        // Setup self-talk triggers
        setupSelfTalkManager()

        // Setup anthropomorphic enhancement modules (US-002 to US-010)
        setupAnthropomorphicModules()

        // Register global hotkey (Cmd+Shift+P)
        registerHotKey()

        print("🔵 Application setup complete")
    }

    func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            print("🔵 Status bar button created: \(button)")

            // Try system symbol first, fallback to text
            if let image = NSImage(systemSymbolName: "paw.fill", accessibilityDescription: "Mac Dynamic Island Pet") {
                image.isTemplate = true  // Make it look good in menu bar
                button.image = image
            } else {
                // Fallback to text
                button.title = "🐾"
            }
        }

        // Setup menu - 简洁的菜单结构
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "显示/隐藏宠物 (⌘⇧P)", action: #selector(togglePet), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "添加事件...", action: #selector(showEventAdd), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "事件时间线...", action: #selector(showEventList), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "精灵兴趣...", action: #selector(showNewsInterestConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于 MacDynamicIslandPet", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        print("🔵 Status bar item setup complete, menu: \(menu)")
    }

    func setupPetWindow() {
        // Create a borderless, transparent window for the pet
        let contentRect = NSRect(x: 0, y: 0, width: 64, height: 64)
        let styleMask: NSWindow.StyleMask = [.borderless]

        petWindow = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // Window properties for transparent background and floating above all
        petWindow?.isOpaque = false
        petWindow?.backgroundColor = NSColor.clear
        petWindow?.level = .screenSaver  // Use higher level to stay above all floating windows
        petWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        petWindow?.ignoresMouseEvents = false  // Must accept mouse events for interaction
        petWindow?.hasShadow = false
        petWindow?.isMovable = false  // Don't let system move the window
        petWindow?.canBecomeVisibleWithoutLogin = true

        // Important: Make sure the window can receive mouse events
        petWindow?.acceptsMouseMovedEvents = true

        print("🔵 Pet window created: \(petWindow), level: \(petWindow?.level ?? .normal)")

        // Set initial position (hidden)
        petWindow?.orderOut(nil)

        // Setup view model
        petViewModel = PetViewModel()
        var petView = PetView(viewModel: petViewModel!)
        petView.onDragPositionUpdate = { [weak self] position in
            self?.updatePetPosition(position)
        }

        // Setup interaction coordination callbacks
        petView.onInteractionStart = { [weak self] in
            // Click: interrupt current task, cancel movement target
            self?.taskScheduler?.interrupt()
            self?.petMover?.cancelMovement()
            print("Interaction started - task interrupted, movement cancelled")
        }

        petView.onDragStart = { [weak self] in
            // Drag start: pause task execution, cancel movement
            self?.taskScheduler?.pause()
            self?.petMover?.cancelMovement()
            print("Drag started - scheduler paused, movement cancelled")
        }

        petView.onDragEnd = { [weak self] in
            // Drag end: resume after 2 second delay
            self?.petMover?.setCurrentPosition(self?.petViewModel?.position ?? .zero)
            self?.taskScheduler?.resume(after: 2.0)
            print("Drag ended - will resume autonomous behavior in 2 seconds")
        }

        // Conversation UI callback
        petView.onShowConversation = { [weak self] in
            guard let self = self, let petPosition = self.petViewModel?.position else { return }
            self.conversationManager?.showWindow(near: petPosition, petWindowSize: CGSize(width: 64, height: 64))
            print("Showing conversation window near pet")
        }

        // US-009: Evolution tooltip hover callbacks
        petView.onHoverEnter = { [weak self] in
            self?.showEvolutionTooltip()
        }
        petView.onHoverExit = { [weak self] in
            self?.hideEvolutionTooltip()
        }

        petWindow?.contentView = NSHostingView(rootView: petView)
        print("🔵 Pet view setup complete, window: \(petWindow != nil)")
    }

    @objc func statusBarButtonClicked() {
        statusItem?.button?.performClick(nil)
    }

    @objc func togglePet() {
        if petWindow?.isVisible == true {
            petWindow?.orderOut(nil)
            // Hide scene objects when pet is hidden
            sceneWindowManager?.hideAll()
            // Reset Dynamic Island trigger flag when manually hiding
            wasShownViaDynamicIsland = false
        } else {
            showPet()
            // Reset Dynamic Island trigger flag when manually showing
            // This prevents pet from being auto-hidden when mouse exits Dynamic Island area
            wasShownViaDynamicIsland = false
        }
    }

    /// 手动触发吐槽（测试用）
    /// 修复：改用SelfTalkManager.forceTrigger触发CommentGenerator（含记忆、性格、进化等级）
    @objc func triggerTestComment() {
        print("🔵 Manual test comment triggered - calling SelfTalkManager.forceTrigger()")
        SelfTalkManager.shared.forceTrigger()
    }

    /// 手动触发自主思考（测试用）
    /// 让精灵从RSS获取新闻并生成观点气泡
    @objc func triggerAutonomousThinking() {
        print("🧠 Manual autonomous thinking triggered")

        // 先确保精灵显示
        showPet()

        // 等待精灵位置确定后触发思考（避免气泡位置错误）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AutonomousThinkingManager.shared.triggerManually()
        }
    }

    /// 手动触发视觉分析测试（测试截屏 + 视觉分析）
    @objc func triggerVisionTest() {
        print("🔵 Vision test triggered - capturing screen and analyzing...")

        ScreenCaptureService.shared.captureScreenAsync { base64 in
            guard let imageBase64 = base64 else {
                print("❌ 截屏失败")
                return
            }

            print("✅ 截屏成功：\(imageBase64.count) 字节")

            let appName = WindowObserver.shared.currentActiveApp
            print("🔵 当前应用：\(appName)")

            LLMService.shared.analyzeScreenWithVision(
                imageBase64: imageBase64,
                appName: appName
            ) { result in
                switch result {
                case .success(let analysis):
                    print("✅ 视觉分析成功:")
                    print("   活动类型：\(analysis.activityType)")
                    print("   主要窗口：\(analysis.mainWindow ?? "未知")")
                    print("   可见文本：\(analysis.visibleText ?? "无")")
                    print("   界面元素：\(analysis.uiElements ?? "无")")
                    print("   用户行为：\(analysis.userBehavior ?? "未知")")
                    print("   简述：\(analysis.briefDescription)")
                    print("   详细描述：\(analysis.detailedDescription)")

                    // 显示气泡
                    DispatchQueue.main.async {
                        SelfTalkManager.shared.bubbleText = analysis.briefDescription
                        SelfTalkManager.shared.shouldShowBubble = true
                    }

                case .failure(let error):
                    print("❌ 视觉分析失败：\(error)")
                }
            }
        }
    }

    /// 重播房子出场动画（测试用）
    @objc func replayHouseExitAnimation() {
        print("🏠 Replaying house exit animation...")
        // Clear last position to trigger house exit
        lastPetPosition = nil
        // Clear existing scene objects
        SceneObjectManager.shared.clearAllObjects()
        // Hide pet if visible
        petWindow?.orderOut(nil)
        // Show pet with house exit animation
        showPetWithHouseExitAnimation()
    }

    func showPet() {
        // Reset Dynamic Island trigger flag when manually showing
        // This prevents pet from being auto-hidden when mouse exits Dynamic Island area
        wasShownViaDynamicIsland = false

        // Check if we should use house exit animation (first time or random)
        let shouldUseHouseExit = lastPetPosition == nil && SceneObjectManager.shared.isEnabled

        if shouldUseHouseExit {
            showPetWithHouseExitAnimation()
        } else {
            showPetDirectly()
        }
    }

    /// Show pet with house exit animation - pet walks out of house
    func showPetWithHouseExitAnimation() {
        print("🏠 开始房子出场动画...")

        // 获取房子位置、精灵起始位置和走出方向
        let sceneManager = SceneObjectManager.shared
        let (housePosition, petStartPosition, exitDirection) = sceneManager.setupHouseExitAnimation()

        // 确保精灵窗口显示在房子中心位置
        petWindow?.setFrame(NSRect(x: petStartPosition.x, y: petStartPosition.y, width: 64, height: 64), display: true)
        petWindow?.orderFront(nil)

        // 设置精灵移动位置
        petMover?.setCurrentPosition(petStartPosition)
        petViewModel?.setPosition(petStartPosition)

        // 保存位置
        lastPetPosition = petStartPosition

        print("🏠 精灵窗口位置设置为: \(petStartPosition)")
        print("🏠 房子窗口应该在: \(housePosition)")

        // 计算走出目标位置 - 从房子中心向外走出足够距离（超过房子尺寸）
        // 房子80x80，精灵需要走出至少80像素才能完全离开房子
        let exitDistance: CGFloat = 100  // 走出100像素
        let exitTarget: CGPoint
        switch exitDirection {
        case .north:
            exitTarget = CGPoint(x: petStartPosition.x, y: petStartPosition.y + exitDistance)
        case .south:
            exitTarget = CGPoint(x: petStartPosition.x, y: petStartPosition.y - exitDistance)
        case .east:
            exitTarget = CGPoint(x: petStartPosition.x + exitDistance, y: petStartPosition.y)
        case .west:
            exitTarget = CGPoint(x: petStartPosition.x - exitDistance, y: petStartPosition.y)
        }

        print("🏠 精灵将从 \(petStartPosition) 走向 \(exitTarget)，方向 \(exitDirection)")

        // 设置精灵为跑步状态（走路动画）
        AnimationStateMachine.shared.transitionTo(.running, force: true)
        AnimationStateMachine.shared.updateDirection(exitDirection)

        // 开始向目标移动
        petMover?.moveTo(exitTarget)

        // 等待移动完成（约2秒），然后进入正常行为模式
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.completeHouseExitAnimation()
        }
    }

    /// Complete house exit animation and start normal behavior
    func completeHouseExitAnimation() {
        print("🏠 房子出场动画完成")

        // 标记动画完成
        SceneObjectManager.shared.completeHouseExitAnimation()

        // 房子消失 - 精灵已经走出房子了
        SceneObjectManager.shared.removeHouse()
        print("🏠 房子已消失")

        // 切换到idle状态
        AnimationStateMachine.shared.transitionTo(.idle, force: true)

        // 开始self-talk监控
        if let position = petViewModel?.position {
            selfTalkManager?.startStationaryMonitoring()
            selfTalkManager?.updatePosition(position)
        }

        // 启动自主行为
        taskScheduler?.resume()
    }

    /// Show pet directly without house exit animation (for subsequent shows)
    func showPetDirectly() {
        // Reset Dynamic Island trigger flag when manually showing
        wasShownViaDynamicIsland = false

        // US-001: Restore last position if available, don't reset to center
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let petWidth: CGFloat = 64
            let petHeight: CGFloat = 64

            // Use last position if available, otherwise center
            let position: CGPoint
            if let lastPos = lastPetPosition {
                position = lastPos
            } else {
                let x = screenRect.midX - petWidth / 2
                let y = screenRect.midY - petHeight / 2
                position = CGPoint(x: x, y: y)
            }

            petWindow?.setFrame(NSRect(x: position.x, y: position.y, width: petWidth, height: petHeight), display: true)
            petWindow?.orderFront(nil)

            // Initialize pet mover position
            petMover?.setCurrentPosition(position)
            petViewModel?.setPosition(position)
            lastPetPosition = position  // US-001: Store position

            // Start self-talk monitoring
            selfTalkManager?.startStationaryMonitoring()
            selfTalkManager?.updatePosition(position)

            // Start autonomous behavior
            taskScheduler?.resume()
        }
    }

    @objc func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示性格配置窗口 (US-002)
    @objc func showPersonalityConfig() {
        if personalityConfigWindowController == nil {
            personalityConfigWindowController = PersonalityConfigWindowController()
        }
        personalityConfigWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示事件添加窗口 (US-005)
    @objc func showEventAdd() {
        if eventAddWindowController == nil {
            eventAddWindowController = EventAddWindowController()
        }
        eventAddWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示事件列表窗口 (US-005)
    @objc func showEventList() {
        if eventListWindowController == nil {
            eventListWindowController = EventListWindowController()
        }
        eventListWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示进化详情窗口 (US-009)
    @objc func showEvolutionDetail() {
        if evolutionDetailWindowController == nil {
            evolutionDetailWindowController = EvolutionDetailWindowController()
        }
        evolutionDetailWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示新闻兴趣配置窗口 (US-011)
    @objc func showNewsInterestConfig() {
        if newsInterestConfigWindowController == nil {
            newsInterestConfigWindowController = NewsInterestConfigWindowController()
        }
        newsInterestConfigWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示性格验证窗口 (US-014)
    @objc func showPersonalityVerification() {
        if personalityVerificationWindowController == nil {
            personalityVerificationWindowController = PersonalityVerificationWindowController()
        }
        personalityVerificationWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示记忆收敛测试窗口 (US-015)
    @objc func showMemoryConvergenceTest() {
        if memoryConvergenceTestWindowController == nil {
            memoryConvergenceTestWindowController = MemoryConvergenceTestWindowController()
        }
        memoryConvergenceTestWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        print("🔵 Application will terminate")
    }

    func startMouseMonitoring() {
        mouseMonitor = MouseMonitor.shared
        mouseMonitor?.startMonitoring()

        // Setup Dynamic Island detector
        dynamicIslandDetector = DynamicIslandDetector.shared
        dynamicIslandDetector?.startDetection(mouseMonitor: mouseMonitor!)

        // Setup task scheduler for autonomous behavior (must be before petInteractionHandler)
        taskScheduler = TaskScheduler.shared
        taskScheduler?.setViewModel(petViewModel!)

        // Setup pet movement - autonomous mode
        petMover = PetMover.shared
        petMover?.onPositionUpdate = { [weak self] position in
            self?.updatePetPosition(position)
            self?.petViewModel?.setPosition(position)
            self?.updateSelfTalkPosition(position)
        }
        petMover?.onDirectionChange = { (direction: MovementDirection) in
            // Direction change is handled by PetView's position observation
            // This callback is for future enhancements
            print("Movement direction changed to: \(direction)")
        }

        // Setup pet interaction handler (after taskScheduler and petMover are initialized)
        petInteractionHandler = PetInteractionHandler.shared
        petInteractionHandler?.setViewModel(petViewModel!)
        petInteractionHandler?.setTaskScheduler(taskScheduler!)
        petInteractionHandler?.setPetMover(petMover!)
        petInteractionHandler?.onPositionUpdate = { [weak self] position in
            self?.updatePetPosition(position)
        }

        // Setup conversation manager
        conversationManager = ConversationManager.shared

        // Connect task callbacks to movement
        taskScheduler?.onTaskStart = { [weak self] task in
            self?.handleTaskStart(task)
        }
        taskScheduler?.onTaskComplete = { [weak self] task in
            self?.handleTaskComplete(task)
        }

        // Connect detector callbacks to pet visibility
        dynamicIslandDetector?.onEnterTriggerArea = { [weak self] in
            self?.showPetNearDynamicIsland()
        }
        dynamicIslandDetector?.onExitTriggerArea = { [weak self] in
            self?.hidePetWithDelay()
        }

        // Start autonomous behavior when pet is shown
        // (will be triggered when pet window becomes visible)
    }

    // MARK: - Task-Based Movement Handlers

    func handleTaskStart(_ task: PetTask) {
        guard let mover = petMover else { return }

        // US-005: Update PetViewModel's currentTask for animation synchronization
        let behaviorTask: PetBehaviorTask
        switch task {
        case .idle: behaviorTask = .idle
        case .explore: behaviorTask = .explore
        case .sleep: behaviorTask = .sleep
        case .eat: behaviorTask = .eat
        case .seekAttention: behaviorTask = .seekAttention
        }
        petViewModel?.setCurrentTask(behaviorTask)

        // Scene System: Create appropriate scene object for task
        handleSceneForTask(task)

        // Start autonomous movement system if not already running
        if !mover.isAutonomousMode {
            mover.startAutonomousMovement()
        }

        // 修复：先确保动画状态正确，延迟一小段时间让 running 动画加载播放
        // 然后再开始移动，避免出现 idle 帧平移的问题
        if task == .explore || task == .seekAttention {
            // 强制转换到 running 状态
            AnimationStateMachine.shared.transitionTo(.running, force: true)
            // 取消移动冷却
            mover.cancelCooldown()
            print("🚶 任务 \(task.rawValue) 开始，设置动画状态为 running")
        }

        // Generate target position based on task type
        // Only explore and seekAttention tasks trigger movement (running animation)
        // Other tasks (idle, sleep, eat) should stay stationary
        let targetPosition: CGPoint?
        switch task {
        case .explore:
            // 探索任务：50%概率生成装饰物去探索，50%概率只是随机移动
            let shouldSpawnDecoration = Bool.random()
            if shouldSpawnDecoration {
                // 生成装饰物并移动到旁边
                let sceneManager = SceneObjectManager.shared
                if let decoration = sceneManager.spawnRandomDecorationForExplore() {
                    let petSize: CGFloat = 64
                    let decoCenterX = decoration.position.x + decoration.size.width / 2
                    let decoCenterY = decoration.position.y + decoration.size.height / 2
                    let directions: [(CGFloat, CGFloat)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                    let dir = directions.randomElement() ?? (1, 0)
                    let distance: CGFloat = 20 + max(decoration.size.width, decoration.size.height) / 2
                    targetPosition = CGPoint(
                        x: decoCenterX + dir.0 * distance - petSize / 2,
                        y: decoCenterY + dir.1 * distance - petSize / 2
                    )
                    print("🚶 精灵将探索装饰物 \(decoration.type.displayName)，目标: \(targetPosition!)")
                } else {
                    targetPosition = mover.explorePosition()
                }
            } else {
                // 只随机移动探索屏幕
                targetPosition = mover.explorePosition()
                print("🚶 精灵自由探索屏幕，目标: \(targetPosition!)")
            }
        case .idle:
            // Idle task stays stationary (no movement)
            mover.cancelMovement()
            targetPosition = nil
        case .sleep:
            // Sleep: stop moving, stay in place
            mover.cancelMovement()
            targetPosition = nil
        case .eat:
            // Eat: stay in place, play eating animation (no movement)
            mover.cancelMovement()
            targetPosition = nil
        case .seekAttention:
            // Seek attention: can move near mouse cursor (running animation)
            targetPosition = mover.nearMousePosition()
        }

        // Set target if movement is needed
        // 延迟 0.3 秒让 running 动画先加载播放，避免 idle 帧平移
        if let target = targetPosition {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                mover.moveTo(target)
                print("🚶 延迟 0.3s 后开始移动到目标: \(target)")
            }
        }

        print("Task \(task.rawValue) started with movement target: \(targetPosition != nil)")
    }

    /// Handle scene creation for specific tasks
    /// 场景元素在精灵停下后才显示，而不是随机出现
    func handleSceneForTask(_ task: PetTask) {
        guard let position = petViewModel?.position else { return }
        let sceneManager = SceneObjectManager.shared

        // 获取精灵当前位置 - 场景元素出现在精灵附近
        let petPos = position

        switch task {
        case .sleep:
            // 精灵睡觉时，在精灵旁边显示床
            // 床放在精灵左侧或右侧
            let bedOffset: CGFloat = 50
            let bedPosition = CGPoint(x: petPos.x - bedOffset, y: petPos.y + 10)
            let bed = sceneManager.createObject(type: .petBed, position: bedPosition, associatedTask: .sleep)
            print("🏠 精灵睡觉，在位置 \(petPos) 旁边显示床 at \(bed.position)")

        case .eat:
            // 精灵吃东西时，在精灵旁边显示随机食物（从多种食物中随机选择）
            let bowlOffset: CGFloat = 40
            let bowlPosition = CGPoint(x: petPos.x + bowlOffset, y: petPos.y)
            // 使用 scenesForTask 获取随机食物类型
            let eatSceneTypes = SceneObjectType.scenesForTask(.eat)
            let randomFoodType = eatSceneTypes.randomElement() ?? .foodBowl
            let bowl = sceneManager.createObject(type: randomFoodType, position: bowlPosition, associatedTask: .eat)
            print("🏠 精灵吃东西，在位置 \(petPos) 旁边显示 \(randomFoodType.displayName) at \(bowl.position)")

        case .explore:
            // 探索任务：装饰物已在前面生成，这里不需要再处理
            // handleSceneForTask 在目标位置生成之前被调用
            print("🏠 精灵探索任务开始，装饰物已生成")

        case .idle, .seekAttention:
            // No specific scene objects for these tasks
            break
        }
    }

    func handleTaskComplete(_ task: PetTask) {
        // Task complete - position updates are handled by TaskScheduler
        print("Task \(task.rawValue) completed")

        // 场景系统逻辑
        let sceneManager = SceneObjectManager.shared

        switch task {
        case .explore:
            // 探索任务完成 - 标记已探索的装饰物，并发表评论
            if let exploredObject = sceneManager.getNearestUnexploredObject() {
                sceneManager.markAsExplored(exploredObject)
                print("🏠 精灵探索完成，发现了 \(exploredObject.type.displayName)")

                // 发表针对装饰物的自言自语
                generateExploreComment(for: exploredObject.type)
            }

        case .sleep, .eat:
            // Sleep/Eat 任务完成后，清理对应的场景元素（床/碗）
            // 3秒后清理，给用户看到的时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                sceneManager.clearTaskObjects(except: nil)
                print("🏠 Sleep/Eat 任务完成，清理场景元素")
            }

        default:
            break
        }
    }

    /// 生成针对装饰物的探索评论
    func generateExploreComment(for objectType: SceneObjectType) {
        let comments: [String] = getExploreComments(for: objectType)
        let comment = comments.randomElement() ?? "发现了有趣的东西~"

        // 通过 SelfTalkManager 显示评论
        DispatchQueue.main.async {
            SelfTalkManager.shared.bubbleText = comment
            SelfTalkManager.shared.shouldShowBubble = true
            print("💬 探索评论: \(comment)")
        }
    }

    /// 获取针对特定装饰物的探索评论列表
    func getExploreComments(for objectType: SceneObjectType) -> [String] {
        switch objectType {
        case .tree:
            return ["这棵树看起来好古老~", "树上好像有鸟巢!", "好想爬上去看看...", "树叶好绿啊!", "树下乘凉不错~"]
        case .rock:
            return ["这块石头好大啊!", "下面会不会藏着宝藏?", "坐上去休息一下~", "石头上有苔藓!", "有点像一张脸..."]
        case .mushroom:
            return ["这个蘑菇好可爱!", "是魔法蘑菇吗?", "不能吃哦...", "红色的点点!", "好像在发光~"]
        case .pond:
            return ["水池里有鱼吗?", "水面好平静~", "想喝一口水...", "有青蛙跳过去了!", "水好清澈~"]
        case .dragon:
            return ["哇，是一只小龙!", "它好像睡着了...", "小心不要吵醒它!", "鳞片好漂亮!", "会喷火吗?", "想摸摸它的尾巴~"]
        case .magicSword:
            return ["传说中的魔法剑!", "谁把它留在这里的?", "好想拔出来试试...", "剑上刻着符文!", "有英雄的传说吗?"]
        case .treasureChest:
            return ["宝箱!里面有金币吗?", "好想打开看看!", "会不会有魔法道具?", "锁住了...", "钥匙在哪里?", "宝箱好古老~"]
        case .spellBook:
            return ["魔法书!上面写的是什么?", "学会魔法就能飞了!", "翻开看看...", "书好厚啊!", "有火球术吗?"]
        case .wizardTower:
            return ["法师塔!好高啊!", "里面有魔法师吗?", "想进去探险!", "塔顶有光!", "魔法气息很浓~"]
        case .fireTorch:
            return ["火炬还在燃烧!", "好温暖的光~", "是地牢入口吗?", "照亮黑暗~", "火焰颜色好奇怪..."]
        case .skull:
            return ["呃...有点吓人", "这是什么留下的?", "小心绕过去...", "眼睛还在发光!", "是勇士的遗骸吗?"]
        case .magicPortal:
            return ["魔法传送门!", "进去会到哪里?", "好神秘的光芒...", "想去另一个世界!", "紫色光圈好漂亮~"]
        case .tavern:
            return ["酒馆!里面有冒险者吗?", "好想进去喝一杯~", "听说有很多故事!", "有人在唱歌!", "美食的味道~"]
        case .castle:
            return ["城堡!好壮观!", "里面有国王吗?", "想去探险!", "城墙好厚!", "旗帜飘扬~"]
        case .dungeonEntrance:
            return ["地牢入口!", "里面有宝藏吗?", "有点可怕但还是想进去...", "黑暗深处...", "有怪物吗?"]
        case .swing:
            return ["秋千!好想玩!", "推我一下~", "童年回忆!", "荡得高一点!", "好开心~"]
        case .magicCrystal:
            return ["魔法水晶!好漂亮!", "它在发光!", "有神奇的力量吗?", "颜色在变化!", "能量涌动~"]
        case .magicPotion:
            return ["魔法药剂!", "喝下去会变身吗?", "紫色液体...", "飘着气泡~"]
        case .fantasyApple:
            return ["奇幻苹果!", "好想咬一口~", "金光闪闪!", "吃了会飞吗?"]
        case .magicCake:
            return ["魔法蛋糕!", "好香啊~", "想吃!", "有草莓装饰~"]
        // 剑与魔法角色
        case .knight:
            return ["骑士大人!", "好帅的盔甲!", "能教我剑术吗?", "是守护者吗?", "盔甲好闪亮!", "骑士精神!"]
        case .wizard:
            return ["法师先生!", "你会什么魔法?", "杖上的水晶好漂亮!", "教我魔法吧!", "袍子好飘逸~", "有魔法帽吗?"]
        case .slime:
            return ["史莱姆!", "好可爱的果冻!", "摸一下...", "软软的~", "蹦蹦跳跳!", "想养一只!"]
        case .goblin:
            return ["哥布林!", "小绿人!", "手里拿着什么?", "有点淘气~", "想去偷东西吗?", "小心点..."]
        case .archer:
            return ["弓箭手!", "箭术好厉害!", "能射很远吗?", "精灵弓!", "想学射箭!", "眼神好专注~"]
        case .villager:
            return ["村民!", "你好!", "这里有什么好玩的?", "本地人~", "可以聊天吗?", "看起来很友善~"]
        case .fairy:
            return ["妖精!", "好小的翅膀!", "会飞吗?", "魔法粒子飘落~", "可爱的小精灵!", "想跟着我吗?"]
        case .ghost:
            return ["幽灵...", "有点可怕", "呜呜的声音...", "是善灵吗?", "透明的身体~", "想回家了..."]
        case .demon:
            return ["小恶魔!", "红红的角!", "会捣乱吗?", "有点淘气~", "尾巴好长!", "小心别被抓到!"]
        case .orc:
            return ["半兽人!", "好强壮!", "绿色肌肉!", "是战士吗?", "斧头好大!", "别惹他生气~"]
        default:
            return ["发现了有趣的东西!", "这是什么?", "好神奇!", "想去看看~", "有秘密吗?"]
        }
    }

    func handleMouseLocationUpdate(_ location: CGPoint) {
        // Mouse location is now handled by DynamicIslandDetector
    }

    func showPetNearDynamicIsland() {
        // 修复：如果精灵已经显示，不要触发位置跳转
        // 只有精灵隐藏时，才通过灵动岛触发显示
        if petWindow?.isVisible == true {
            print("showPetNearDynamicIsland: Pet already visible, not jumping to Dynamic Island")
            return
        }

        // Mark that pet was shown via Dynamic Island trigger
        wasShownViaDynamicIsland = true

        // Check if we should use house exit animation (first time only)
        if lastPetPosition == nil && SceneObjectManager.shared.isEnabled {
            showPetWithHouseExitAnimation()
            return
        }

        // Position pet near the Dynamic Island area
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let petWidth: CGFloat = 64
            let petHeight: CGFloat = 64
            let x = screenRect.midX - petWidth / 2
            let y = screenRect.maxY - petHeight - 10  // Just below the top

            let position = CGPoint(x: x, y: y)
            petWindow?.setFrame(NSRect(x: x, y: y, width: petWidth, height: petHeight), display: true)
            petWindow?.orderFront(nil)

            // US-001: Store position to prevent reset
            lastPetPosition = position

            // Initialize pet mover position
            petMover?.setCurrentPosition(position)
            petViewModel?.setPosition(position)

            // Set pet state to alert when near Dynamic Island
            petViewModel?.setState(.alert)

            // Start autonomous behavior after alert state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.taskScheduler?.resume()
            }
        }
    }

    func hidePetWithDelay() {
        // Only hide if pet was shown via Dynamic Island trigger AND user hasn't manually shown it
        // This prevents pet from disappearing when user manually shows it via toggle/hotkey
        guard wasShownViaDynamicIsland else {
            print("hidePetWithDelay: Pet was shown manually, not hiding")
            return
        }

        // Hide pet when mouse exits trigger area
        // Delay 2 seconds to avoid flickering when mouse just passes through
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            // Only hide if mouse is still outside trigger area AND still was shown via Dynamic Island
            if self?.dynamicIslandDetector?.isMouseInTriggerArea == false &&
               self?.wasShownViaDynamicIsland == true {
                print("hidePetWithDelay: Hiding pet (was shown via Dynamic Island)")
                self?.petWindow?.orderOut(nil)
            }
        }
    }

    func updatePetPosition(_ position: CGPoint) {
        // US-001: Store position to prevent reset on showPet
        lastPetPosition = position

        // Update SelfTalkManager for edge/stationary trigger detection
        selfTalkManager?.updatePosition(position)

        // Update pet window position based on PetMover
        DispatchQueue.main.async { [weak self] in
            self?.petWindow?.setFrameOrigin(NSPoint(x: position.x, y: position.y))
        }
    }

    // MARK: - Hotkey Support

    func registerHotKey() {
        // Register global hotkey event monitor for Cmd+Shift+P
        hideShowHotKey = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalHotkey(event)
        }
    }

    func handleGlobalHotkey(_ event: NSEvent) {
        // Check for Cmd+Shift+P
        if event.modifierFlags.contains(.command) &&
           event.modifierFlags.contains(.shift) &&
           event.keyCode == 35 {  // 'P' key keyCode
            DispatchQueue.main.async { [weak self] in
                self?.togglePet()
            }
        }
    }

    // MARK: - Configuration Check

    func checkConfigurationStatus() {
        // Silent check - don't show alert on first launch
        // User can configure API key through Settings menu
        let configManager = AppConfigManager.shared
        let status = configManager.getConfigStatus()

        // Just log the status, don't interrupt user with alert
        print("🔧 Config status: \(status.message)")

        // If config is missing, AppConfigManager will handle auto-creation
        // User can configure API key via "设置..." menu when ready
    }

    func showConfigAlert(_ status: ConfigStatus) {
        let alert = NSAlert()
        alert.messageText = "Configuration Required"
        alert.informativeText = """
        \(status.message)

        Config file location:
        \(AppConfigManager.configFilePath.path)

        Please copy config.template.json to config.json and fill in your settings.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Show Config Directory")

        let response = alert.runModal()

        if response == NSApplication.ModalResponse.alertSecondButtonReturn {
            // Open config directory in Finder
            NSWorkspace.shared.open(AppConfigManager.appSupportDirectory)
        }
    }

    // MARK: - Self-Talk Setup

    func setupSelfTalkBubbleWindow() {
        selfTalkBubbleWindow = SelfTalkBubbleWindow()
        selfTalkBubbleWindow?.orderOut(nil)  // Start hidden
        print("🔵 Self-talk bubble window setup complete")

        // US-009: Setup evolution tooltip window
        setupEvolutionTooltipWindow()
    }

    // MARK: - Scene System Setup

    func setupSceneSystem() {
        sceneWindowManager = SceneWindowManager.shared
        print("🪟 Scene system setup complete")
    }

    // MARK: - Evolution Tooltip Setup

    func setupEvolutionTooltipWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.hasShadow = false

        evolutionTooltipWindow = window
        evolutionTooltipWindow?.orderOut(nil)  // Start hidden
        print("🔵 Evolution tooltip window setup complete")
    }

    func showEvolutionTooltip() {
        guard let position = petViewModel?.position else { return }

        // Load evolution state
        let state = EvolutionManager.shared.getEvolutionState()

        // Create tooltip view
        let tooltipView = EvolutionTooltipView(state: state)

        // 小窗口尺寸，紧贴精灵头部居中
        let tooltipWidth: CGFloat = 70
        let tooltipHeight: CGFloat = 35
        // 居中在精灵上方，精灵宽度64，位置是精灵左下角
        let tooltipX = position.x + 32 - tooltipWidth / 2  // 精灵中心 - tooltip一半宽度
        let tooltipY = position.y + 64 - 5  // 更靠近精灵顶部（屏幕坐标向上是+）

        let frame = NSRect(x: tooltipX, y: tooltipY, width: tooltipWidth, height: tooltipHeight)

        evolutionTooltipWindow?.contentView = NSHostingView(rootView: tooltipView)
        evolutionTooltipWindow?.setFrame(frame, display: true)
        evolutionTooltipWindow?.orderFront(nil)
        print("🔵 Evolution tooltip shown at \(frame)")
    }

    func hideEvolutionTooltip() {
        evolutionTooltipWindow?.orderOut(nil)
        print("🔵 Evolution tooltip hidden")
    }

    func setupSelfTalkManager() {
        selfTalkManager = SelfTalkManager.shared

        // Subscribe to bubble display changes
        selfTalkManager?.$shouldShowBubble
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldShow in
                print("🔵 SelfTalkManager.shouldShowBubble changed to: \(shouldShow)")
                if shouldShow {
                    print("🔵 Calling showSelfTalkBubble()")
                    self?.showSelfTalkBubble()
                } else {
                    print("🔵 shouldShowBubble is false, hiding bubble window")
                    self?.selfTalkBubbleWindow?.orderOut(nil)
                }
            }
            .store(in: &cancellables)

        // Subscribe to position updates from pet mover to trigger edge/stationary checks
        // Position updates flow: PetMover → SelfTalkManager for trigger detection
    }

    // MARK: - Anthropomorphic Enhancement Integration (US-002 to US-010)

    /// Initialize all anthropomorphic enhancement modules
    /// This activates window observation, screen capture, memory, comment generation, and triggers
    func setupAnthropomorphicModules() {
        print("🟣 Setting up anthropomorphic enhancement modules...")

        // Initialize WindowObserver (US-002) - monitors active app changes
        _ = WindowObserver.shared
        print("🟣 WindowObserver initialized - will monitor app switches")

        // Initialize PerceptionMemoryManager (US-005) - stores perception events
        _ = PerceptionMemoryManager.shared
        print("🟣 PerceptionMemoryManager initialized")

        // Initialize TimeContext (US-006) - provides time-aware context
        _ = TimeContext.shared
        print("🟣 TimeContext initialized")

        // Initialize CommentGenerator (US-007) - generates intelligent comments
        _ = CommentGenerator.shared
        print("🟣 CommentGenerator initialized")

        // Initialize SpeechService - TTS语音服务
        _ = SpeechService.shared
        print("🟣 SpeechService initialized - TTS ready")

        // Initialize GoSeeBehaviorManager (US-008) - handles go-see behavior on app switch
        // 暂时注释掉，避免辅助功能权限弹窗
        // _ = GoSeeBehaviorManager.shared
        // print("🟣 GoSeeBehaviorManager initialized - will trigger go-see on app switch")

        // Initialize CommentTriggerManager (US-010) - handles multiple trigger scenarios
        _ = CommentTriggerManager.shared
        print("🟣 CommentTriggerManager initialized - will handle trigger scenarios")

        // Initialize TimelineMemoryManager (US-005) - manages event timeline memory
        _ = TimelineMemoryManager.shared
        print("🟣 TimelineMemoryManager initialized - will check daily events and trigger reminders")

        // Initialize EmotionTracker (US-006) - tracks user emotion state changes
        _ = EmotionTracker.shared
        print("🟣 EmotionTracker initialized - will infer and track user emotion patterns")

        // Initialize InteractionPatternManager (US-007) - analyzes interaction patterns
        _ = InteractionPatternManager.shared
        print("🟣 InteractionPatternManager initialized - will analyze and adjust interaction patterns")

        // Initialize AutonomousThinkingManager (US-010) - manages autonomous thinking behavior
        _ = AutonomousThinkingManager.shared
        print("🟣 AutonomousThinkingManager initialized - will trigger hourly autonomous thinking")

        // Initialize HoverInteractionManager - handles cursor change and pat interaction
        if let viewModel = petViewModel {
            HoverInteractionManager.shared.setViewModel(viewModel)
        }
        print("🟣 HoverInteractionManager initialized - will handle hover cursor and pat interaction")

        print("🟣 Anthropomorphic enhancement modules setup complete")
    }

    func showSelfTalkBubble() {
        guard let text = selfTalkManager?.bubbleText,
              let position = petViewModel?.position else {
            print("🔵 showSelfTalkBubble: Cannot show - no text or position")
            return
        }

        // Get current emotion from PetViewModel
        let emotion = petViewModel?.currentEmotion ?? .content
        print("🔵 showSelfTalkBubble: Showing bubble '\(text)', emotion: \(emotion.displayName)")

        // Hide any existing bubble
        selfTalkBubbleWindow?.orderOut(nil)

        // 气泡尺寸（使用最小尺寸作为窗口初始大小，让气泡一开始在精灵正中间）
        let minWidth: CGFloat = 100
        let minHeight: CGFloat = 50
        let initialHeight: CGFloat = minHeight + 15  // 窗口高度使用最小值

        // 计算气泡位置和尾巴方向
        // position.x 是精灵窗口左下角的X坐标
        // 精灵宽度64，中心在 position.x + 32
        // 气泡要居中显示，所以气泡左边缘 = 精灵中心 - 气泡宽度/2
        // 使用 minWidth 计算初始位置，这样气泡一开始就在精灵正上方正中间
        let petCenterX = position.x + 32
        var bubbleX = petCenterX - minWidth / 2
        var bubbleY: CGFloat
        var tailDirection: TailDirection = .down

        // 获取屏幕尺寸
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let margin: CGFloat = 20
            let petHeight: CGFloat = 64

            // macOS坐标：y=0是屏幕底部，y=maxY是屏幕顶部
            // position是精灵窗口左下角坐标
            // 精灵顶部坐标 = position.y + petHeight

            // 判断精灵是否在屏幕顶部区域（精灵顶部距离屏幕顶部60px以内）
            let petTop = position.y + petHeight
            let isNearTop = petTop > screenFrame.maxY - 60

            if isNearTop {
                // 精灵在顶部，气泡显示在精灵下方
                bubbleY = position.y - initialHeight - 5
                tailDirection = .up  // 尾巴向上指向精灵
            } else {
                // 精灵不在顶部，气泡显示在精灵上方
                bubbleY = position.y + petHeight + 5
                tailDirection = .down  // 尾巴向下指向精灵
            }

            // 确保X坐标在屏幕范围内（使用预估的最大宽度350进行边界检查）
            let estimatedMaxWidth: CGFloat = 350
            bubbleX = max(margin, min(screenFrame.maxX - estimatedMaxWidth - margin, bubbleX))

            // 确保Y坐标在屏幕范围内（最终边界检查）
            bubbleY = max(screenFrame.minY + margin, min(screenFrame.maxY - initialHeight - margin, bubbleY))
        } else {
            // 无屏幕信息时默认在精灵上方
            let petHeight: CGFloat = 64
            bubbleY = position.y + petHeight + 5
        }

        // 创建气泡视图，传递尾巴方向和尺寸变化回调
        let bubbleView = SelfTalkBubbleView(
            text: text,
            position: position,
            petSize: CGSize(width: 64, height: 64),
            emotion: emotion,
            tailDirection: tailDirection,
            onSizeChange: { [weak self] newSize in
                // 更新窗口位置和大小以保持气泡居中在精灵上方
                // 精灵中心 = petCenterX
                // 气泡左边缘 = 精灵中心 - 气泡宽度/2
                let newBubbleX = petCenterX - newSize.width / 2
                let newFrame = NSRect(x: newBubbleX, y: bubbleY, width: newSize.width, height: newSize.height)
                DispatchQueue.main.async {
                    self?.selfTalkBubbleWindow?.setFrame(newFrame, display: true)
                }
            },
            onBubbleDisappear: { [weak self] in
                print("🔵 SelfTalkBubbleView onDisappear callback triggered (animation finished)")
                self?.selfTalkBubbleWindow?.orderOut(nil)
                // 气泡动画自然结束，不停止语音，让长语音播放完成
                self?.selfTalkManager?.hideBubble(stopSpeech: false)
            }
        )

        let frame = NSRect(x: bubbleX, y: bubbleY, width: minWidth, height: initialHeight)
        print("🔵 showSelfTalkBubble: Pet position y=\(position.y), bubbleY=\(bubbleY), tailDirection=\(tailDirection)")
        selfTalkBubbleWindow?.setFrame(frame, display: true)

        selfTalkBubbleWindow?.contentView = NSHostingView(rootView: bubbleView)
        print("🔵 showSelfTalkBubble: contentView set, window level = \(selfTalkBubbleWindow?.level.rawValue ?? -1)")

        selfTalkBubbleWindow?.orderFront(nil)

        // Ensure pet window stays above bubble window
        petWindow?.orderFront(nil)

        print("🔵 showSelfTalkBubble: orderFront called, window isVisible = \(selfTalkBubbleWindow?.isVisible ?? false)")

        print("Self-talk bubble shown: '\(text)' at position (\(bubbleX), \(bubbleY))")
    }

    func updateSelfTalkPosition(_ position: CGPoint) {
        // Update SelfTalkManager with current position
        selfTalkManager?.updatePosition(position)

        // US-001: Update bubble window position if it's showing
        if selfTalkManager?.shouldShowBubble == true,
           let bubbleWindow = selfTalkBubbleWindow,
           bubbleWindow.isVisible {
            // Use current window size for position calculation
            let currentWidth = bubbleWindow.frame.width
            let currentHeight = bubbleWindow.frame.height
            let petCenterX = position.x + 32  // 精灵中心
            let bubbleX = petCenterX - currentWidth / 2  // 气泡居中在精灵上方

            // 计算Y位置（根据精灵是否在屏幕顶部）
            let petHeight: CGFloat = 64
            var bubbleY: CGFloat

            if let screen = NSScreen.main {
                let screenFrame = screen.frame
                let petTop = position.y + petHeight
                let isNearTop = petTop > screenFrame.maxY - 60

                if isNearTop {
                    bubbleY = position.y - currentHeight - 5
                } else {
                    bubbleY = position.y + petHeight + 5
                }
            } else {
                bubbleY = position.y + petHeight + 5
            }

            DispatchQueue.main.async {
                bubbleWindow.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
            }
        }
    }
}
