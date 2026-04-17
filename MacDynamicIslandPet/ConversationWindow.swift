import SwiftUI
import Combine

/// A comic-style conversation window for chatting with the pet
struct ConversationWindowView: View {
    // Conversation state
    @State private var inputText: String = ""
    @State private var conversations: [EnhancedMemoryItem] = []
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?
    @State private var isViewVisible: Bool = false

    // Callbacks
    var onClose: (() -> Void)?
    var onSendMessage: ((String, @escaping (Result<String, LLMError>) -> Void) -> Void)?

    // Pet position for positioning window nearby
    var petPosition: CGPoint = .zero

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            headerView

            // Conversation history
            conversationListView

            // Input area
            inputAreaView
        }
        .frame(minWidth: 260, idealWidth: 320, maxWidth: 500,
               minHeight: 300, idealHeight: 400, maxHeight: 600)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.95),  // 暖白
                            Color(red: 0.99, green: 0.96, blue: 0.92)  // 米黄
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))  // 裁剪为圆角形状
        .overlay(
            // 温馨风格边框 - 暖棕色
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(red: 0.85, green: 0.75, blue: 0.6), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)  // 阴影放在裁剪后面
        .onAppear {
            isViewVisible = true
            // 每次打开窗口时清空对话界面（开始新对话）
            // 历史记忆保留在后台MemoryManager中
            conversations = []
            inputText = ""
            print("🧠 ConversationWindow: 清空对话界面，开始新对话")
        }
        .onDisappear {
            isViewVisible = false
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            // 精灵头像 - 使用提供的图片素材
            Image("dialog_avatar")
                .resizable()
                .interpolation(.none)  // 保持像素艺术风格
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)

            Text("精灵寄语")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.2))  // 暖棕色

            Spacer()

            // 关闭按钮 - 温馨风格
            Button(action: {
                onClose?()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.95, green: 0.75, blue: 0.6),  // 珊瑚色
                                    Color(red: 0.85, green: 0.55, blue: 0.4)   // 暖橙色
                                ]),
                                center: .center,
                                startRadius: 5,
                                endRadius: 15
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .strokeBorder(Color(red: 0.75, green: 0.55, blue: 0.4), lineWidth: 1)
                        )
                    Text("×")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.85),  // 浅黄
                            Color(red: 0.98, green: 0.9, blue: 0.75)   // 暖黄
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            // 底部暖棕色线条
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.75, blue: 0.6).opacity(0.5),
                            Color(red: 0.75, green: 0.6, blue: 0.45).opacity(0.7),
                            Color(red: 0.85, green: 0.75, blue: 0.6).opacity(0.5)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Conversation List View

    private var conversationListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if conversations.isEmpty && !isThinking {
                        // Empty state
                        emptyStateView
                    }

                    ForEach(conversations.indices, id: \.self) { index in
                        conversationItemView(conversations[index])
                    }

                    // Thinking indicator
                    if isThinking {
                        thinkingIndicatorView
                            .id("thinking")
                    }

                    // Error message
                    if let error = errorMessage {
                        errorView(error)
                            .id("error")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: conversations.count) { _ in
                // Scroll to bottom when new message arrives
                withAnimation {
                    proxy.scrollTo(conversations.count - 1, anchor: .bottom)
                }
            }
            .onChange(of: isThinking) { thinking in
                if thinking {
                    withAnimation {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            // 可爱精灵头像 - 使用提供的图片素材
            Image("dialog_avatar")
                .resizable()
                .interpolation(.none)  // 保持像素艺术风格
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
            Text("还没有对话记录")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
            Text("在下方输入框中开始与精灵的交流吧~")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.7, green: 0.6, blue: 0.5).opacity(0.9))
        }
        .padding(.vertical, 24)
    }

    private func conversationItemView(_ convo: EnhancedMemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // User message - comic speech bubble style (pointing right)
            messageBubble(
                text: convo.userInput,
                isUser: true,
                timestamp: formatTimestamp(convo.timestamp)
            )

            // Pet response - comic speech bubble style (pointing left)
            messageBubble(
                text: convo.petResponse,
                isUser: false,
                timestamp: nil
            )
        }
    }

    private func messageBubble(text: String, isUser: Bool, timestamp: String?) -> some View {
        HStack(alignment: .top, spacing: 4) {
            if !isUser {
                // 精灵头像 - 使用提供的图片素材
                Image("dialog_avatar")
                    .resizable()
                    .interpolation(.none)  // 保持像素艺术风格
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
                if let ts = timestamp {
                    Text(formatTimestamp(ts))
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.7, green: 0.6, blue: 0.5))
                }

                ZStack {
                    // 温馨风格气泡背景
                    Group {
                        if isUser {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.95, green: 0.85, blue: 0.65),  // 暖黄
                                            Color(red: 0.9, green: 0.78, blue: 0.55)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)  // 精灵消息用白色
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isUser ?
                                    Color(red: 0.85, green: 0.7, blue: 0.5).opacity(0.8) :
                                    Color(red: 0.8, green: 0.75, blue: 0.7).opacity(0.6),
                                lineWidth: 1
                            )
                    )

                    // 尾巴装饰
                    if isUser {
                        // 尾巴指向右
                        TriangleTail(direction: .right)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.95, green: 0.85, blue: 0.65),
                                        Color(red: 0.9, green: 0.78, blue: 0.55)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 10, height: 10)
                            .offset(x: -12, y: -5)
                    } else {
                        // 尾巴指向左，带小星星
                        ZStack {
                            TriangleTail(direction: .left)
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .offset(x: 12, y: -5)
                            // 小星星
                            Text("✨")
                                .font(.system(size: 8))
                                .offset(x: 8, y: -8)
                        }
                    }

                    // 文字内容
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))  // 深棕色文字
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: 200, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if isUser {
                Spacer()
            }
        }
    }

    private var thinkingIndicatorView: some View {
        HStack(alignment: .top, spacing: 4) {
            // 精灵头像 - 使用提供的图片素材
            Image("dialog_avatar")
                .resizable()
                .interpolation(.none)  // 保持像素艺术风格
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(red: 0.8, green: 0.75, blue: 0.7).opacity(0.8), lineWidth: 1)
                    )
                    .frame(height: 32)

                // 可爱圆点跳动效果
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color(red: 0.9, green: 0.7, blue: 0.4))  // 暖橙色
                            .frame(width: 6, height: 6)
                            .scaleEffect(animationScale[index])
                            .animation(
                                Animation.easeInOut(duration: 0.4)
                                    .repeatForever()
                                    .delay(Double(index) * 0.15),
                                value: animationScale[index]
                            )
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(width: 80)

            Spacer()
        }
        .onAppear {
            animationScale = [1.0, 1.0, 1.0]
            // Trigger animation
            DispatchQueue.main.async {
                animationScale = [1.3, 1.3, 1.3]
            }
        }
    }

    @State private var animationScale: [Double] = [1.0, 1.0, 1.0]
    @State private var rotationAngle: [Double] = [0, 0, 0]

    private func errorView(_ message: String) -> some View {
        HStack {
            Text("⚠️")
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.3))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 1.0, green: 0.9, blue: 0.85).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(red: 0.9, green: 0.5, blue: 0.4).opacity(0.4), lineWidth: 1)
                )
        )
    }

    // MARK: - Input Area View

    private var inputAreaView: some View {
        HStack(spacing: 8) {
            // 输入框 - 温馨风格
            TextField("输入消息...", text: $inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(red: 0.85, green: 0.75, blue: 0.65), lineWidth: 1.5)
                        )
                )
                .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.2))
                .disabled(isThinking)
                .onSubmit {
                    sendMessage()
                }

            // 发送按钮 - 暖橙色
            Button(action: {
                sendMessage()
            }) {
                ZStack {
                    // 背景
                    Group {
                        if isThinking || inputText.isEmpty {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.85, green: 0.8, blue: 0.75))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.95, green: 0.75, blue: 0.5),  // 暖橙
                                            Color(red: 0.9, green: 0.65, blue: 0.4)    // 深橙
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .frame(width: 44, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(red: 0.8, green: 0.7, blue: 0.6), lineWidth: 1.5)
                    )

                    // 内容
                    if isThinking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .tint(Color(red: 0.6, green: 0.5, blue: 0.4))
                    } else {
                        Text("✦")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.25))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isThinking || inputText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.9),
                            Color(red: 0.98, green: 0.92, blue: 0.82)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            // 顶部暖色线条
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.9, green: 0.8, blue: 0.7).opacity(0.5),
                            Color(red: 0.85, green: 0.75, blue: 0.65).opacity(0.7),
                            Color(red: 0.9, green: 0.8, blue: 0.7).opacity(0.5)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func loadRecentConversations() {
        conversations = MemoryManager.shared.getRecentConversations(count: 10)
    }

    private func sendMessage() {
        guard !inputText.isEmpty && !isThinking else { return }

        let message = inputText
        inputText = ""
        isThinking = true
        errorMessage = nil

        // Call the send message callback
        onSendMessage?(message) { result in
            DispatchQueue.main.async {
                guard isViewVisible else {
                    return
                }
                isThinking = false

                switch result {
                case .success(let response):
                    // Add to conversations list
                    let enhancedItem = EnhancedMemoryItem.create(
                        userInput: message,
                        petResponse: response,
                        topics: ConversationTopic.classify(content: message + " " + response),
                        emotions: EmotionTag.quickDetect(content: message + " " + response),
                        importance: ImportanceKeyword.calculateImportance(content: message)
                    )
                    conversations.append(enhancedItem)

                    // Save to memory
                    MemoryManager.shared.saveConversation(userInput: message, petResponse: response)

                case .failure(let error):
                    errorMessage = error.errorDescription ?? "发送失败"
                }
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        // Format Date to "HH:mm"
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        // Format: "yyyy-MM-dd HH:mm:ss" -> "HH:mm"
        let parts = timestamp.split(separator: " ")
        if parts.count >= 2 {
            let timeParts = parts[1].split(separator: ":")
            if timeParts.count >= 2 {
                return "\(timeParts[0]):\(timeParts[1])"
            }
        }
        return timestamp
    }
}

// MARK: - Triangle Tail Shape

enum TailDirection {
    case left, right, down, up
}

struct TriangleTail: Shape {
    var direction: TailDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch direction {
        case .left:
            // Triangle pointing left
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .right:
            // Triangle pointing right
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .down:
            // Triangle pointing down
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        case .up:
            // Triangle pointing up
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Preview

#if DEBUG
struct ConversationWindowView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationWindowView()
    }
}
#endif
