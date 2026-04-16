import SwiftUI
import AppKit

// MARK: - About Window Controller

/// 关于窗口控制器
class AboutWindowController: NSWindowController {
    convenience init() {
        let contentView = AboutView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "关于 MacDynamicIslandPet"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // 图标
            Image("about_icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // 应用名称
            Text("MacDynamicIslandPet")
                .font(.system(size: 24, weight: .bold))

            // 版本号
            Text("版本 1.0.0")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            // 应用描述
            Text("一只住在你屏幕角落的小精灵")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("它会观察你的活动、记住你们的对话、关心你的情绪，偶尔还会自言自语或跑去看看你正在做什么。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Divider()

            // 功能列表
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "💬", text: "与精灵聊天对话")
                FeatureRow(icon: "💭", text: "精灵自言自语")
                FeatureRow(icon: "👀", text: "观察你正在做什么")
                FeatureRow(icon: "📚", text: "记住你们的对话")
                FeatureRow(icon: "📅", text: "事件提醒（生日、纪念日）")
                FeatureRow(icon: "📰", text: "RSS 新闻关注")
            }
            .padding(.horizontal, 20)

            Spacer()

            // 作者信息
            Text("Made with ❤️ by Claude & You")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(20)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 13))
        }
    }
}