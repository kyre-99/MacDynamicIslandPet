import SwiftUI
import AppKit

/// 性格配置窗口视图
///
/// 提供精灵性格参数的完整配置界面：
/// - 6个性格维度滑块控件（外向度、好奇心、粘人程度、幽默感、温柔度、叛逆度）
/// - 5种性格模板快速选择按钮（活泼型、温柔型、叛逆型、学者型、宅型）
/// - 实时风格预览区域
/// - 保存按钮（持久化到config.json）
/// - 重置按钮（恢复默认值）
///
/// 窗口标题："精灵性格设置"
struct PersonalityConfigView: View {
    /// 外向度滑块值 (0-100)
    @State private var extroversion: Double = 50
    /// 好奇心滑块值 (0-100)
    @State private var curiosity: Double = 50
    /// 粘人程度滑块值 (0-100)
    @State private var clinginess: Double = 50
    /// 幽默感滑块值 (0-100)
    @State private var humor: Double = 50
    /// 温柔度滑块值 (0-100)
    @State private var gentleness: Double = 50
    /// 叛逆度滑块值 (0-100)
    @State private var rebellion: Double = 50

    /// 保存成功提示显示状态
    @State private var showingSaveSuccess: Bool = false
    /// 保存消息内容
    @State private var saveMessage: String = ""

    /// 用于取消异步任务的标记
    @State private var hideSuccessTask: Task<Void, Never>?

    /// 性格管理器实例
    private let personalityManager = PersonalityManager.shared

    /// 当前性格参数（用于生成风格描述）
    private var currentProfile: PersonalityProfile {
        PersonalityProfile(
            extroversion: Int(extroversion),
            curiosity: Int(curiosity),
            clinginess: Int(clinginess),
            humor: Int(humor),
            gentleness: Int(gentleness),
            rebellion: Int(rebellion)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("精灵性格设置")
                .font(.headline)
                .padding(.bottom, 8)

            // 性格模板快速选择区域
            VStack(alignment: .leading, spacing: 8) {
                Text("性格模板:")
                    .font(.subheadline)

                HStack(spacing: 12) {
                    ForEach(PersonalityTemplate.allTemplates, id: \.self) { template in
                        Button(action: {
                            applyTemplate(template)
                        }) {
                            VStack(spacing: 4) {
                                Text(template.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(template.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .frame(width: 80, alignment: .leading)
                            }
                            .frame(width: 90, height: 50)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // 性格维度滑块区域
            VStack(alignment: .leading, spacing: 12) {
                Text("性格参数调整:")
                    .font(.subheadline)

                // 外向度滑块
                PersonalitySliderView(
                    title: "外向度",
                    label: "主动活跃",
                    value: $extroversion
                )

                // 好奇心滑块
                PersonalitySliderView(
                    title: "好奇心",
                    label: "喜欢探索",
                    value: $curiosity
                )

                // 粘人程度滑块
                PersonalitySliderView(
                    title: "粘人程度",
                    label: "渴望互动",
                    value: $clinginess
                )

                // 幽默感滑块
                PersonalitySliderView(
                    title: "幽默感",
                    label: "调侃幽默",
                    value: $humor
                )

                // 温柔度滑块
                PersonalitySliderView(
                    title: "温柔度",
                    label: "关心体贴",
                    value: $gentleness
                )

                // 叛逆度滑块
                PersonalitySliderView(
                    title: "叛逆度",
                    label: "搞怪吐槽",
                    value: $rebellion
                )
            }

            Divider()

            // 实时风格预览区域
            VStack(alignment: .leading, spacing: 8) {
                Text("性格风格预览:")
                    .font(.subheadline)

                Text(PersonalityStyleMapping.generateStyleDescription(for: currentProfile))
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(6)

                // 语气风格提示词（调试用，可选显示）
                Text("语气风格: " + PersonalityStyleMapping.generateToneStylePrompt(for: currentProfile))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 状态消息
            if showingSaveSuccess {
                Text(saveMessage)
                    .foregroundColor(saveMessage.contains("成功") ? .green : .red)
                    .font(.subheadline)
            }

            // 操作按钮区域
            HStack(spacing: 16) {
                Button("保存") {
                    saveProfile()
                }
                .buttonStyle(.borderedProminent)

                Button("重置") {
                    resetToDefault()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
    .frame(minWidth: 500, minHeight: 500)
    .onAppear {
        loadCurrentProfile()
    }
    .onDisappear {
        // 取消异步任务，防止窗口关闭后访问已释放内存
        hideSuccessTask?.cancel()
    }
}

    /// 加载当前性格参数
    private func loadCurrentProfile() {
        let profile = personalityManager.loadProfile()
        extroversion = Double(profile.extroversion)
        curiosity = Double(profile.curiosity)
        clinginess = Double(profile.clinginess)
        humor = Double(profile.humor)
        gentleness = Double(profile.gentleness)
        rebellion = Double(profile.rebellion)
    }

    /// 应用性格模板
    /// - Parameter template: 性格模板类型
    private func applyTemplate(_ template: PersonalityTemplate) {
        let profile = template.profile()
        extroversion = Double(profile.extroversion)
        curiosity = Double(profile.curiosity)
        clinginess = Double(profile.clinginess)
        humor = Double(profile.humor)
        gentleness = Double(profile.gentleness)
        rebellion = Double(profile.rebellion)
    }

    /// 保存性格参数到config.json
    private func saveProfile() {
        let profile = currentProfile

        if personalityManager.saveProfile(profile) {
            saveMessage = "性格配置已保存！下次气泡将体现新性格"
            showingSaveSuccess = true

            // 取消之前的任务
            hideSuccessTask?.cancel()

            // 使用 Task 替代 DispatchQueue，Task 会随视图销毁自动取消
            hideSuccessTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                showingSaveSuccess = false
            }
        } else {
            saveMessage = "保存失败，请检查配置文件"
            showingSaveSuccess = true
        }
    }

    /// 重置性格参数到默认值（所有维度50）
    private func resetToDefault() {
        extroversion = 50
        curiosity = 50
        clinginess = 50
        humor = 50
        gentleness = 50
        rebellion = 50
    }
}

/// 性格维度滑块视图组件
///
/// 用于显示单个性格维度的滑块控件
/// 包含标题、标签、滑块和当前数值显示
struct PersonalitySliderView: View {
    /// 维度标题
    let title: String
    /// 维度标签（用于UI显示）
    let label: String
    /// 滑块值绑定 (0-100)
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 12) {
            // 维度标题和标签
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .leading)

            // 滑块
            Slider(value: $value, in: 0...100, step: 1)
                .frame(width: 200)

            // 当前数值显示
            Text("\(Int(value))")
                .font(.subheadline)
                .frame(width: 30, alignment: .trailing)

            // 数值区间提示
            Text(valueRangeLabel)
                .font(.caption2)
                .foregroundColor(valueRangeColor)
                .frame(width: 50, alignment: .trailing)
        }
    }

    /// 数值区间标签
    private var valueRangeLabel: String {
        if value >= 70 {
            return "高"
        } else if value >= 40 {
            return "中"
        } else {
            return "低"
        }
    }

    /// 数值区间颜色
    private var valueRangeColor: Color {
        if value >= 70 {
            return .green
        } else if value >= 40 {
            return .blue
        } else {
            return .orange
        }
    }
}

/// 性格配置窗口控制器
///
/// 用于在macOS中创建和管理性格配置窗口
/// 使用 NSWindowController 正确管理窗口生命周期
class PersonalityConfigWindowController: NSWindowController {
    convenience init() {
        let contentView = PersonalityConfigView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "精灵性格设置"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("🟣 PersonalityConfigWindowController created")
    }

    deinit {
        print("🟣 PersonalityConfigWindowController deinit")
    }
}

#Preview {
    PersonalityConfigView()
}