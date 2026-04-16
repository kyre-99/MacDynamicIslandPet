import Foundation
import AppKit
import Combine

/// Monitors active window/application changes using NSWorkspace API
/// US-002: Provides information about what application the user is currently using
class WindowObserver: ObservableObject {
    static let shared = WindowObserver()

    // MARK: - Published Properties

    /// Name of the currently active application (e.g., "Safari", "Xcode", "WeChat")
    @Published var currentActiveApp: String = ""

    /// How long the user has been in the current application (in seconds)
    @Published var activeAppDuration: TimeInterval = 0

    /// Time when the current application became active
    @Published var lastAppSwitchTime: Date = Date()

    // MARK: - Private Properties

    private var workspace: NSWorkspace = NSWorkspace.shared
    private var cancellables = Set<AnyCancellable>()
    private var durationTimer: Timer?

    // MARK: - History Tracking

    /// Recent window switch history (for pattern detection)
    private var appSwitchHistory: [(app: String, time: Date)] = []
    private let maxHistorySize: Int = 20

    // MARK: - Initialization

    private init() {
        setupObservers()
        startDurationTimer()
        initializeCurrentApp()
    }

    deinit {
        durationTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Setup

    /// Setup NSWorkspace notification observers
    private func setupObservers() {
        // Observe when active application changes
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    /// Initialize with current active app
    private func initializeCurrentApp() {
        if let activeApp = workspace.frontmostApplication {
            currentActiveApp = activeApp.localizedName ?? "Unknown"
            lastAppSwitchTime = Date()
        }
    }

    /// Start timer to update duration
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
        RunLoop.current.add(durationTimer!, forMode: .common)
    }

    // MARK: - Notification Handler

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        guard let newApp = notification.userInfo?["NSWorkspaceApplicationKey"] as? NSRunningApplication else {
            print("🟣 WindowObserver: No app info in notification")
            return
        }

        let appName = newApp.localizedName ?? "Unknown"
        print("🟣 WindowObserver: App changed to '\(appName)' (previous: '\(currentActiveApp)')")

        // Only update if actually changed
        if appName != currentActiveApp {
            let previousApp = currentActiveApp
            let switchTime = Date()

            // Update published properties
            currentActiveApp = appName
            lastAppSwitchTime = switchTime
            activeAppDuration = 0

            print("🟣 WindowObserver: Published currentActiveApp = '\(appName)'")

            // Add to history
            appSwitchHistory.append((app: appName, time: switchTime))
            if appSwitchHistory.count > maxHistorySize {
                appSwitchHistory.removeFirst()
            }

            // Add to history
            addToHistory(app: previousApp, time: switchTime)

            print("WindowObserver: App switched from '\(previousApp)' to '\(appName)'")
        }
    }

    // MARK: - Duration Update

    private func updateDuration() {
        activeAppDuration = Date().timeIntervalSince(lastAppSwitchTime)
    }

    // MARK: - History Management

    private func addToHistory(app: String, time: Date) {
        appSwitchHistory.append((app: app, time: time))
        if appSwitchHistory.count > maxHistorySize {
            appSwitchHistory.removeFirst()
        }
    }

    // MARK: - Public Query Methods

    /// Get recent app switch history (last N entries)
    func getRecentSwitchHistory(limit: Int = 5) -> [(app: String, time: Date)] {
        let startIndex = max(0, appSwitchHistory.count - limit)
        return Array(appSwitchHistory[startIndex..<appSwitchHistory.count])
    }

    /// Check if user has been in current app for at least specified duration
    func hasBeenInCurrentApp(for duration: TimeInterval) -> Bool {
        return activeAppDuration >= duration
    }

    /// Get all recent apps the user has switched through
    func getRecentApps(limit: Int = 5) -> [String] {
        let recentHistory = getRecentSwitchHistory(limit: limit)
        return recentHistory.map { $0.app }
    }

    /// Count how many times user has switched apps in the last N minutes
    func switchCountInLast(minutes: Int) -> Int {
        let cutoffTime = Date().addingTimeInterval(-TimeInterval(minutes * 60))
        return appSwitchHistory.filter { $0.time >= cutoffTime }.count
    }

    /// Detect if user is switching apps frequently (indicating distraction/multitasking)
    func isFrequentSwitching(threshold: Int = 5, withinMinutes: Int = 10) -> Bool {
        return switchCountInLast(minutes: withinMinutes) >= threshold
    }

    // MARK: - App Categories

    /// Categorize the current application type
    func getAppCategory(_ appName: String) -> AppCategory {
        let lowerName = appName.lowercased()

        // Development tools
        if lowerName.contains("xcode") || lowerName.contains("vscode") ||
           lowerName.contains("sublime") || lowerName.contains("atom") ||
           lowerName.contains("intellij") || lowerName.contains("terminal") ||
           lowerName.contains("iterm") {
            return .development
        }

        // Communication apps
        if lowerName.contains("wechat") || lowerName.contains("slack") ||
           lowerName.contains("discord") || lowerName.contains("telegram") ||
           lowerName.contains("messages") || lowerName.contains("zoom") ||
           lowerName.contains("teams") || lowerName.contains("skype") {
            return .communication
        }

        // Browser
        if lowerName.contains("safari") || lowerName.contains("chrome") ||
           lowerName.contains("firefox") || lowerName.contains("edge") ||
           lowerName.contains("browser") {
            return .browser
        }

        // Entertainment
        if lowerName.contains("youtube") || lowerName.contains("spotify") ||
           lowerName.contains("netflix") || lowerName.contains("music") ||
           lowerName.contains("video") || lowerName.contains("tv") {
            return .entertainment
        }

        // Productivity
        if lowerName.contains("notes") || lowerName.contains("word") ||
           lowerName.contains("excel") || lowerName.contains("powerpoint") ||
           lowerName.contains("pages") || lowerName.contains("numbers") ||
           lowerName.contains("keynote") || lowerName.contains("notion") {
            return .productivity
        }

        return .other
    }

    /// Get current app category
    var currentAppCategory: AppCategory {
        return getAppCategory(currentActiveApp)
    }
}

// MARK: - App Category Enum

/// Categories for different application types
enum AppCategory: String, CaseIterable {
    case development    // Coding tools: Xcode, VSCode, Terminal
    case communication  // Chat apps: WeChat, Slack, Discord
    case browser        // Web browsers: Safari, Chrome, Firefox
    case entertainment  // Media apps: YouTube, Spotify, Netflix
    case productivity   // Work apps: Notes, Word, Excel
    case other          // Uncategorized apps

    var displayName: String {
        switch self {
        case .development: return "开发工具"
        case .communication: return "通讯软件"
        case .browser: return "浏览器"
        case .entertainment: return "娱乐应用"
        case .productivity: return "办公软件"
        case .other: return "其他应用"
        }
    }

    var icon: String {
        switch self {
        case .development: return "💻"
        case .communication: return "💬"
        case .browser: return "🌐"
        case .entertainment: return "🎮"
        case .productivity: return "📝"
        case .other: return "📱"
        }
    }
}