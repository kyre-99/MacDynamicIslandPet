import Foundation
import AppKit
import SwiftUI
import Combine

/// Manages window display for scene objects
/// Similar to pet window: transparent, floating, borderless
class SceneWindowManager: ObservableObject {
    static let shared = SceneWindowManager()

    // MARK: - Properties

    /// Dictionary of window IDs to NSWindow instances
    private var windows: [UUID: NSWindow] = [:]

    /// Scene object manager reference
    private let sceneManager = SceneObjectManager.shared

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        print("🪟 SceneWindowManager: initializing...")

        // Subscribe to scene object changes
        setupSceneObjectObserver()
    }

    // MARK: - Setup

    private func setupSceneObjectObserver() {
        // Observe activeObjects changes
        sceneManager.$activeObjects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] objects in
                self?.syncWindows(with: objects)
            }
            .store(in: &cancellables)

        print("🪟 SceneWindowManager: observer setup complete")
    }

    /// Sync windows with current scene objects
    private func syncWindows(with objects: [SceneObject]) {
        // Remove windows for objects no longer in list
        let currentIds = Set(objects.map { $0.id })
        let windowIds = Set(windows.keys)

        // Remove obsolete windows
        for id in windowIds where !currentIds.contains(id) {
            removeWindow(for: id)
        }

        // Add/update windows for current objects
        for object in objects where object.isVisible {
            if windows[object.id] == nil {
                _ = createWindow(for: object)
            } else {
                updateWindow(for: object)
            }
        }
    }

    /// Update window position and opacity for an object
    func updateWindow(for object: SceneObject) {
        guard let window = windows[object.id] else { return }

        // Update position
        let frame = NSRect(
            x: object.position.x,
            y: object.position.y,
            width: object.size.width,
            height: object.size.height
        )
        window.setFrame(frame, display: true)

        // Update opacity by recreating the content view
        // (NSHostingView doesn't support dynamic SwiftUI state updates well)
        let sceneView = SceneObjectView(type: object.type, opacity: object.opacity)
        window.contentView = NSHostingView(rootView: sceneView)
    }

    // MARK: - Window Creation

    /// Create a transparent floating window for a scene object
    func createWindow(for object: SceneObject) -> NSWindow {
        let contentRect = NSRect(
            x: object.position.x,
            y: object.position.y,
            width: object.size.width,
            height: object.size.height
        )

        let styleMask: NSWindow.StyleMask = [.borderless]

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // Window properties for transparent background and floating above all
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.ignoresMouseEvents = true  // Scene objects don't intercept mouse events
        window.hasShadow = false
        window.isMovable = false
        window.canBecomeVisibleWithoutLogin = true

        // Create view with the scene image and opacity
        let sceneView = SceneObjectView(type: object.type, opacity: object.opacity)
        window.contentView = NSHostingView(rootView: sceneView)

        // Store and show
        windows[object.id] = window
        window.orderFront(nil)

        print("🪟 Created window for \(object.type.displayName) at \(object.position) with opacity \(object.opacity)")
        return window
    }

    /// Remove window for an object ID
    func removeWindow(for id: UUID) {
        guard let window = windows[id] else { return }

        window.orderOut(nil)
        windows.removeValue(forKey: id)

        print("🪟 Removed window for object ID: \(id)")
    }

    // MARK: - Public Methods

    /// Show a specific scene object window
    func showObject(_ object: SceneObject) {
        guard let window = windows[object.id] else {
            // Create if doesn't exist
            createWindow(for: object)
            return
        }

        window.orderFront(nil)
    }

    /// Hide a specific scene object window
    func hideObject(_ object: SceneObject) {
        guard let window = windows[object.id] else { return }
        window.orderOut(nil)
    }

    /// Hide all scene object windows
    func hideAll() {
        for (_, window) in windows {
            window.orderOut(nil)
        }
        print("🪟 All scene windows hidden")
    }

    /// Show all scene object windows
    func showAll() {
        for (_, window) in windows {
            window.orderFront(nil)
        }
        print("🪟 All scene windows shown")
    }

    /// Clear all windows
    func clearAll() {
        for (_, window) in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        print("🪟 All scene windows cleared")
    }

    /// Bring scene windows to front (after pet window)
    func bringToFront() {
        for (_, window) in windows {
            window.orderFront(nil)
        }
    }

    /// Check if any scene windows are visible
    var hasVisibleWindows: Bool {
        return windows.values.contains { $0.isVisible }
    }

    /// Get window for specific object
    func getWindow(for object: SceneObject) -> NSWindow? {
        return windows[object.id]
    }

    /// Get house window if exists
    func getHouseWindow() -> NSWindow? {
        let houseObject = sceneManager.getHouseObject()
        guard let house = houseObject else { return nil }
        return windows[house.id]
    }
}

// MARK: - Scene Object View (SwiftUI)

/// SwiftUI view for displaying a scene object image
struct SceneObjectView: View {
    let type: SceneObjectType
    let opacity: Double  // 透明度（用于淡出动画）

    @State private var image: NSImage?

    init(type: SceneObjectType, opacity: Double = 1.0) {
        self.type = type
        self.opacity = opacity
    }

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)  // Preserve pixel art look
                    .aspectRatio(contentMode: .fit)
                    .opacity(opacity)  // 应用透明度
            } else {
                // Placeholder while loading
                Rectangle()
                    .fill(Color.clear)
            }
        }
        .frame(
            width: type.defaultSize.width,
            height: type.defaultSize.height
        )
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        image = SceneObjectManager.shared.loadImage(for: type)
    }
}

// MARK: - Movement Direction Helper Extension

/// Helper extension for MovementDirection (from PetMover.swift)
extension MovementDirection {
    /// Get animation prefix for this direction
    var animationPrefix: String {
        switch self {
        case .north: return "north"
        case .south: return "south"
        case .east: return "east"
        case .west: return "west"
        }
    }
}