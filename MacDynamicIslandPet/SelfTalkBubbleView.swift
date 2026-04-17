import SwiftUI

/// A comic-style self-talk bubble that appears near the pet
/// Features:
/// - Stream-style text output (character by character)
/// - Dynamic width that grows with text
/// - Higher transparency
/// - Emotion-based colors
struct SelfTalkBubbleView: View {
    var text: String
    var position: CGPoint  // Pet position for bubble positioning
    var petSize: CGSize = CGSize(width: 64, height: 64)
    var emotion: PetEmotion = .content  // 情绪影响气泡颜色
    var tailDirection: TailDirection = .down  // 气泡尾巴方向

    // Callback for size changes - used to update window position
    var onSizeChange: ((CGSize) -> Void)?

    // Animation state
    @State private var displayedText: String = ""
    @State private var currentWidth: CGFloat = 80  // 开始宽度较小
    @State private var currentHeight: CGFloat = 50  // 开始高度适中
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.1  // Start small for bounce-in
    @State private var decorationOpacity: Double = 0.0
    @State private var textIndex: Int = 0
    @State private var lastNotifiedWidth: CGFloat = 80  // 记录上次通知的宽度，减少更新频率
    @State private var scheduledWorkItems: [DispatchWorkItem] = []

    // Callback
    var onBubbleDisappear: (() -> Void)?

    // MARK: - Dynamic Size (宽度增加以容纳完整内容)

    private var minWidth: CGFloat { 100 }
    private var maxWidth: CGFloat { 350 }  // 增加宽度以容纳更长观点
    private var minHeight: CGFloat { 50 }
    private var maxHeight: CGFloat { 120 }  // 最大高度适应多行文本

    // MARK: - Emotion Colors (情绪影响气泡颜色，提高透明度)

    /// 气泡背景颜色（70%透明度）
    private var bubbleColor: Color {
        switch emotion {
        case .content: return Color(red: 0.66, green: 0.85, blue: 0.58).opacity(0.7)
        case .bored: return Color(red: 0.72, green: 0.91, blue: 0.57).opacity(0.7)
        case .excited: return Color.yellow.opacity(0.7)
        case .curious: return Color(red: 1.0, green: 0.95, blue: 0.4).opacity(0.7)
        case .worried: return Color(red: 0.85, green: 0.7, blue: 0.9).opacity(0.7)
        case .playful: return Color(red: 1.0, green: 0.72, blue: 0.7).opacity(0.7)
        case .tired: return Color(red: 0.9, green: 0.9, blue: 0.85).opacity(0.7)
        }
    }

    /// 边框颜色（50%透明度）
    private var borderColor: Color {
        switch emotion {
        case .content: return Color(red: 0.4, green: 0.6, blue: 0.35).opacity(0.5)
        case .bored: return Color(red: 0.45, green: 0.65, blue: 0.35).opacity(0.5)
        case .excited: return Color.orange.opacity(0.5)
        case .curious: return Color.orange.opacity(0.45)
        case .worried: return Color(red: 0.6, green: 0.5, blue: 0.7).opacity(0.5)
        case .playful: return Color(red: 0.9, green: 0.5, blue: 0.5).opacity(0.5)
        case .tired: return Color.gray.opacity(0.45)
        }
    }

    /// 文字颜色
    private var textColor: Color {
        switch emotion {
        case .content, .bored: return Color(red: 0.2, green: 0.3, blue: 0.15)
        case .excited, .curious: return Color(red: 0.3, green: 0.2, blue: 0.1)
        case .worried: return Color(red: 0.35, green: 0.25, blue: 0.4)
        case .playful: return Color(red: 0.4, green: 0.2, blue: 0.25)
        case .tired: return Color.gray
        }
    }

    var body: some View {
        ZStack {
            // Main bubble - 居中显示
            ZStack {
                // Cloud/bubble shape background
                CloudBubbleShape()
                    .fill(bubbleColor)
                    .frame(width: currentWidth, height: currentHeight)
                    .overlay(
                        CloudBubbleShape()
                            .stroke(borderColor, lineWidth: 2)
                    )

                // Tail - 居中在气泡下方/上方
                tailView

                // Text content (stream output) - 支持多行完整显示
                Text(displayedText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(5)  // 允许最多5行，让长观点能完整显示
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .frame(width: currentWidth, height: currentHeight + 15)  // 窗口跟随实际气泡大小

            // Decorations (stars and dots)
            if decorationOpacity > 0 {
                decorationsView
                    .opacity(decorationOpacity)
            }
        }
        .onAppear {
            startStreamAnimation()
        }
        .onDisappear {
            cancelScheduledAnimations()
        }
    }

    // MARK: - Tail View

    @ViewBuilder
    private var tailView: some View {
        switch tailDirection {
        case .down:
            // 尾巴向下（气泡在精灵上方），居中
            TriangleTail(direction: .down)
                .fill(bubbleColor)
                .frame(width: 12, height: 10)
                .overlay(
                    TriangleTail(direction: .down)
                        .stroke(borderColor, lineWidth: 2)
                )
                .offset(x: 0, y: currentHeight / 2 + 5)
        case .up:
            // 尾巴向上（气泡在精灵下方），居中
            TriangleTail(direction: .up)
                .fill(bubbleColor)
                .frame(width: 12, height: 10)
                .overlay(
                    TriangleTail(direction: .up)
                        .stroke(borderColor, lineWidth: 2)
                )
                .offset(x: 0, y: -currentHeight / 2 - 5)
        case .left:
            TriangleTail(direction: .left)
                .fill(bubbleColor)
                .frame(width: 10, height: 12)
                .overlay(
                    TriangleTail(direction: .left)
                        .stroke(borderColor, lineWidth: 2)
                )
                .offset(x: -currentWidth / 2 - 5, y: 6)
        case .right:
            TriangleTail(direction: .right)
                .fill(bubbleColor)
                .frame(width: 10, height: 12)
                .overlay(
                    TriangleTail(direction: .right)
                        .stroke(borderColor, lineWidth: 2)
                )
                .offset(x: currentWidth / 2 + 5, y: 6)
        }
    }

    // MARK: - Decorations

    private var decorationsView: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { _ in
                Text("✨")
                    .font(.system(size: 8))
                    .offset(x: CGFloat.random(in: -currentWidth/2...currentWidth/2), y: -currentHeight/2 - 15)
            }
        }
    }

    // MARK: - Stream Animation

    private func startStreamAnimation() {
        cancelScheduledAnimations()

        // Bounce-in animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.0
        }

        // 开始宽度和高度
        currentWidth = minWidth
        currentHeight = minHeight

        // 逐字输出动画（每个字160ms）
        let chars = text.map { String($0) }
        var delay: TimeInterval = 0

        for (index, char) in chars.enumerated() {
            delay = Double(index) * 0.16  // 每个字160ms，更像说话

            let workItem = DispatchWorkItem {
                displayedText += char

                // 动态调整宽度和高度
                let textLength = displayedText.count
                let newWidth = min(maxWidth, minWidth + CGFloat(textLength) * 12)

                // 根据文本估算需要的行数来动态调整高度
                // 假设每行大约容纳 maxWidth / 12 个字符
                let estimatedLines = max(1, Int((newWidth > 0 ? CGFloat(textLength) * 12 / newWidth : 1).rounded(.up)))
                let newHeight = min(maxHeight, minHeight + CGFloat(estimatedLines - 1) * 20)

                withAnimation(.easeOut(duration: 0.15)) {
                    currentWidth = newWidth
                    currentHeight = newHeight
                }

                // 只在宽度变化超过20px时才通知窗口更新，减少闪烁
                if abs(newWidth - lastNotifiedWidth) > 20 {
                    lastNotifiedWidth = newWidth
                    onSizeChange?(CGSize(width: newWidth, height: newHeight + 15))
                }

                // 显示装饰
                if index == 2 {
                    withAnimation(.easeIn(duration: 0.1)) {
                        decorationOpacity = 0.6
                    }
                }
            }
            scheduledWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        // 文字输出完成后，最后确保窗口尺寸正确
        let finalDelay = Double(chars.count) * 0.16 + 0.1
        let finalResizeWorkItem = DispatchWorkItem {
            let finalWidth = currentWidth
            let finalHeight = currentHeight
            onSizeChange?(CGSize(width: finalWidth, height: finalHeight + 15))
        }
        scheduledWorkItems.append(finalResizeWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay, execute: finalResizeWorkItem)

        // 全部输出完成后，停留更长时间让用户看完
        // 根据内容长度动态调整停留时间：最少6秒，最长12秒
        let streamDuration = Double(chars.count) * 0.16  // 流式输出总时间
        let baseStayDuration = 6.0  // 基础停留时间
        let extraStayDuration = min(6.0, Double(chars.count) * 0.1)  // 根据内容长度增加停留
        let stayDuration = baseStayDuration + extraStayDuration  // 总停留时间

        let fadeWorkItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
                decorationOpacity = 0
            }
        }
        scheduledWorkItems.append(fadeWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + streamDuration + stayDuration, execute: fadeWorkItem)

        let disappearWorkItem = DispatchWorkItem {
            onBubbleDisappear?()
        }
        scheduledWorkItems.append(disappearWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + streamDuration + stayDuration + 0.4, execute: disappearWorkItem)
    }

    private func cancelScheduledAnimations() {
        scheduledWorkItems.forEach { $0.cancel() }
        scheduledWorkItems.removeAll()
    }
}

// MARK: - Cloud Bubble Shape

struct CloudBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Simple pill shape with slight bumps
        path.move(to: CGPoint(x: 10, y: h / 2))

        // Top with bumps
        path.addQuadCurve(to: CGPoint(x: 20, y: 10), control: CGPoint(x: 10, y: 10))
        for i in 0..<5 {
            let cx = 30 + CGFloat(i) * (w - 60) / 5
            path.addQuadCurve(to: CGPoint(x: cx + 15, y: 10), control: CGPoint(x: cx, y: 6))
        }
        path.addQuadCurve(to: CGPoint(x: w - 20, y: 10), control: CGPoint(x: w - 30, y: 10))
        path.addQuadCurve(to: CGPoint(x: w - 10, y: h / 2), control: CGPoint(x: w - 10, y: 10))

        // Bottom smooth
        path.addQuadCurve(to: CGPoint(x: w / 2, y: h - 10), control: CGPoint(x: w - 10, y: h - 10))
        path.addQuadCurve(to: CGPoint(x: 10, y: h / 2), control: CGPoint(x: 10, y: h - 10))

        return path
    }
}

// MARK: - SelfTalkBubbleWindow

class SelfTalkBubbleWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = NSColor.clear
        // Use a level just below screenSaver (pet window uses screenSaver)
        // This ensures pet is always visible above the bubble
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        hasShadow = false  // 无阴影，更轻量
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Preview

#if DEBUG
struct SelfTalkBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SelfTalkBubbleView(text: "温和调侃~", position: CGPoint(x: 100, y: 100), emotion: .content)
            SelfTalkBubbleView(text: "关心提醒!", position: CGPoint(x: 100, y: 100), emotion: .worried)
            SelfTalkBubbleView(text: "搞怪吐槽~嘿嘿", position: CGPoint(x: 100, y: 100), emotion: .playful)
        }
    }
}
#endif
