import SwiftUI
import AppKit

/// 交互选项窗口视图 - 显示拍一拍和聊天两个选项
struct InteractionOptionsView: View {
    let onPat: () -> Void
    let onChat: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 拍一拍按钮
            Button(action: {
                onPat()
                onClose()
            }) {
                HStack(spacing: 8) {
                    Text("👋")
                        .font(.system(size: 18))
                    Text("拍一拍")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .buttonStyle(PlainButtonStyle())

            Divider()

            // 聊天按钮
            Button(action: {
                onChat()
                onClose()
            }) {
                HStack(spacing: 8) {
                    Text("💬")
                        .font(.system(size: 18))
                    Text("聊一聊")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 100)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

/// 管理交互选项窗口
class InteractionOptionsManager {
    static let shared = InteractionOptionsManager()

    private var optionsWindow: NSWindow?
    private var lastPetPosition: CGPoint = .zero

    var isVisible: Bool {
        return optionsWindow?.isVisible == true
    }

    private init() {}

    /// 显示选项窗口
    func showWindow(near petPosition: CGPoint, petWindowSize: CGSize = CGSize(width: 64, height: 64),
                    onPat: @escaping () -> Void, onChat: @escaping () -> Void) {
        // 保存精灵位置用于后续检查
        lastPetPosition = petPosition

        // 如果已经显示，先关闭
        if let window = optionsWindow, window.isVisible {
            hideWindow()
        }

        createWindow(onPat: onPat, onChat: onChat)
        positionWindow(near: petPosition, petWindowSize: petWindowSize)
        optionsWindow?.orderFront(nil)
        optionsWindow?.makeKey()

        // 设置点击外部关闭
        setupClickOutsideMonitor()
    }

    /// 关闭选项窗口
    func hideWindow() {
        optionsWindow?.orderOut(nil)
        optionsWindow = nil
        removeClickOutsideMonitor()

        // Check if mouse is still over pet after closing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let mouseLocation = NSEvent.mouseLocation
            if HoverInteractionManager.shared.isMouseNearPet(mouseLocation: mouseLocation, petPosition: self.lastPetPosition) {
                HoverInteractionManager.shared.showHandCursor()
            } else {
                HoverInteractionManager.shared.resetCursor()
            }
        }
    }

    private func createWindow(onPat: @escaping () -> Void, onChat: @escaping () -> Void) {
        let contentRect = NSRect(x: 0, y: 0, width: 100, height: 80)
        let styleMask: NSWindow.StyleMask = [.borderless]

        optionsWindow = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        optionsWindow?.isOpaque = false
        optionsWindow?.backgroundColor = NSColor.clear
        optionsWindow?.level = .floating
        optionsWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        optionsWindow?.hasShadow = false  // 我们用 SwiftUI shadow
        optionsWindow?.isMovableByWindowBackground = false

        optionsWindow?.contentView?.wantsLayer = true
        optionsWindow?.contentView?.layer?.backgroundColor = CGColor.clear

        let optionsView = InteractionOptionsView(
            onPat: onPat,
            onChat: onChat,
            onClose: { [weak self] in
                self?.hideWindow()
            }
        )

        optionsWindow?.contentView = NSHostingView(rootView: optionsView)
    }

    private func positionWindow(near petPosition: CGPoint, petWindowSize: CGSize) {
        guard let window = optionsWindow,
              let screen = NSScreen.main else { return }

        let screenRect = screen.visibleFrame
        let windowSize = CGSize(width: 100, height: 80)

        // 放在精灵右侧，稍微偏上
        let xOffset: CGFloat = petWindowSize.width + 5
        let yOffset: CGFloat = 20

        var windowX = petPosition.x + xOffset
        var windowY = petPosition.y + yOffset

        // 边界检查
        if windowX + windowSize.width > screenRect.maxX {
            windowX = petPosition.x - windowSize.width - 5
        }
        if windowY < screenRect.minY {
            windowY = screenRect.minY + 5
        }
        if windowY + windowSize.height > screenRect.maxY {
            windowY = screenRect.maxY - windowSize.height - 5
        }
        if windowX < screenRect.minX {
            windowX = screenRect.minX + 5
        }

        let windowRect = NSRect(x: windowX, y: windowY, width: windowSize.width, height: windowSize.height)
        window.setFrame(windowRect, display: true)
    }

    // MARK: - Click Outside Monitor

    private var clickOutsideMonitor: Any?

    private func setupClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let window = self?.optionsWindow, window.isVisible else { return }

            let windowFrame = window.frame
            let screenLocation = NSEvent.mouseLocation

            if !windowFrame.contains(screenLocation) {
                self?.hideWindow()
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    deinit {
        removeClickOutsideMonitor()
        optionsWindow?.close()
    }
}