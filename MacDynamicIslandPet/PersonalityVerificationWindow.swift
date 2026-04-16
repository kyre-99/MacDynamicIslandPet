import SwiftUI
import AppKit

/// 性格验证UI窗口控制器
/// US-014: 提供可视化验证界面
/// 使用 NSWindowController 正确管理窗口生命周期
class PersonalityVerificationWindowController: NSWindowController {
    convenience init() {
        let contentView = PersonalityVerificationView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "性格影响验证"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("🟣 PersonalityVerificationWindowController created")
    }

    deinit {
        print("🟣 PersonalityVerificationWindowController deinit")
    }
}

/// 性格验证SwiftUI视图
/// US-014: 验证性格参数确实影响精灵的对话风格
struct PersonalityVerificationView: View {
    /// 测试管理器
    @ObservedObject private var testManager = PersonalityVerificationTests.shared

    /// 是否正在运行测试
    @State private var isRunningTests = false

    /// 测试结果列表
    @State private var testResults: [PersonalityVerificationTests.TestResult] = []

    /// 显示详情的结果索引
    @State private var selectedResultIndex: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题区域
                headerSection

                // 运行测试按钮
                runTestsButton

                // 测试结果列表
                if !testResults.isEmpty {
                    resultsSection
                }

                // 气泡类型统计图表
                if !testResults.isEmpty {
                    bubbleTypeChartSection
                }
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("性格影响验证")
                .font(.title2)
                .fontWeight(.bold)

            Text("验证性格参数确实影响精灵的对话风格")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Run Tests Button

    private var runTestsButton: some View {
        Button(action: runAllTests) {
            HStack {
                if isRunningTests {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在运行测试...")
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "play.circle")
                    Text("运行所有验证测试")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
        .disabled(isRunningTests)
        .buttonStyle(.plain)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 12) {
            // 统计摘要
            Text(testManager.getStatisticsSummary())
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(testResults.allSatisfy { $0.passed } ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                )

            // 测试结果列表
            ForEach(testResults.indices, id: \.self) { index in
                TestResultRow(
                    result: testResults[index],
                    isSelected: selectedResultIndex == index,
                    onTap: {
                        selectedResultIndex = selectedResultIndex == index ? nil : index
                    }
                )
            }
        }
    }

    // MARK: - Bubble Type Chart Section

    private var bubbleTypeChartSection: some View {
        VStack(spacing: 12) {
            Text("气泡类型统计")
                .font(.headline)

            let stats = testManager.getBubbleTypeStatistics()
            let total = stats.values.reduce(0, +)

            if total > 0 {
                VStack(spacing: 8) {
                    ForEach(["teasing", "caring", "greeting", "opinion", "memory"], id: \.self) { type in
                        if let count = stats[type], count > 0 {
                            BubbleTypeBar(
                                type: type,
                                count: count,
                                total: total
                            )
                        }
                    }
                }
            } else {
                Text("暂无统计数据")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func runAllTests() {
        isRunningTests = true

        DispatchQueue.global(qos: .userInitiated).async {
            let results = testManager.runAllTests()

            DispatchQueue.main.async {
                self.testResults = results
                self.isRunningTests = false
            }
        }
    }
}

// MARK: - Test Result Row View

/// 单个测试结果行视图
struct TestResultRow: View {
    let result: PersonalityVerificationTests.TestResult
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 结果行
            HStack {
                // 状态指示器
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? .green : .red)

                // 测试名称
                Text(result.testName)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                // 气泡数量（如果有）
                if result.totalBubbles > 0 {
                    Text("\(result.totalBubbles)次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 展开指示器
                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .onTapGesture(perform: onTap)

            // 详情展开
            if isSelected {
                VStack(spacing: 8) {
                    Text(result.details)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Bubble Type Bar View

/// 气泡类型统计柱状图
struct BubbleTypeBar: View {
    let type: String
    let count: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标和名称
            HStack(spacing: 4) {
                Text(getBubbleIcon(type))
                Text(getBubbleDisplayName(type))
                    .font(.body)
            }
            .frame(width: 80, alignment: .leading)

            // 进度条
            GeometryReader { geometry in
                let percentage = CGFloat(count) / CGFloat(total)
                Rectangle()
                    .fill(getBubbleColor(type))
                    .frame(width: geometry.size.width * percentage)
            }
            .frame(height: 20)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)

            // 数量和百分比
            Text("\(count) (\(Int(Double(count) / Double(total) * 100))%)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    private func getBubbleIcon(_ type: String) -> String {
        switch type {
        case "greeting": return "👋"
        case "caring": return "💕"
        case "memory": return "💭"
        case "opinion": return "💡"
        case "teasing": return "😜"
        default: return "•"
        }
    }

    private func getBubbleDisplayName(_ type: String) -> String {
        switch type {
        case "greeting": return "问候"
        case "caring": return "关心"
        case "memory": return "回忆"
        case "opinion": return "观点"
        case "teasing": return "调侃"
        default: return type
        }
    }

    private func getBubbleColor(_ type: String) -> Color {
        switch type {
        case "greeting": return .blue
        case "caring": return .pink
        case "memory": return .purple
        case "opinion": return .yellow
        case "teasing": return .orange
        default: return .gray
        }
    }
}

// MARK: - Preview Provider

struct PersonalityVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalityVerificationView()
    }
}