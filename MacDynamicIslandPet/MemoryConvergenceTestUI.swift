import SwiftUI

/// 记忆收敛测试窗口控制器
/// US-015: 提供可视化测试界面
/// 使用 NSWindowController 正确管理窗口生命周期
class MemoryConvergenceTestWindowController: NSWindowController {
    convenience init() {
        let contentView = MemoryConvergenceTestView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "记忆系统收敛测试"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("🟣 MemoryConvergenceTestWindowController created")
    }

    deinit {
        print("🟣 MemoryConvergenceTestWindowController deinit")
    }
}

/// 记忆收敛测试视图
struct MemoryConvergenceTestView: View {
    @ObservedObject var tests = MemoryConvergenceTests.shared
    @ObservedObject var dataGenerator = SimulatedInteractionDataGenerator.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题
                Text("长期运行稳定性测试")
                    .font(.headline)
                    .padding(.top, 10)

                // 模拟数据生成区
                VStack(alignment: .leading, spacing: 10) {
                    Text("模拟数据生成")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    HStack {
                        Button("生成30天模拟数据") {
                            _ = dataGenerator.generate30DaySimulation(days: 30)
                        }
                        .disabled(dataGenerator.isGenerating)

                        if dataGenerator.isGenerating {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text(dataGenerator.statusDescription)
                                .font(.caption)
                        }
                    }

                    // 进度条
                    if dataGenerator.isGenerating {
                        ProgressView(value: dataGenerator.progress, total: 100)
                            .frame(width: 200)
                    }

                    // 文件大小显示
                    HStack {
                        Text("记忆目录大小:")
                            .font(.caption)
                        Text(dataGenerator.formatSize(dataGenerator.calculateMemoryDirectorySize()))
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Divider()

                // 测试执行区
                VStack(alignment: .leading, spacing: 10) {
                    Text("收敛测试")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    Button("运行所有测试") {
                        tests.runAllTests()
                    }
                    .disabled(dataGenerator.isGenerating)

                    // 测试进度
                    if tests.progress > 0 {
                        HStack {
                            ProgressView(value: tests.progress, total: 100)
                                .frame(width: 150)
                            Text("\(Int(tests.progress))%")
                                .font(.caption)
                        }
                    }

                    // 测试结果列表
                    if !tests.allResults.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(tests.allResults, id: \.testName) { result in
                                ConvergenceTestResultRow(result: result)
                            }
                        }
                        .padding(.top, 5)

                        // 统计摘要
                        Text(tests.getStatisticsSummary())
                            .font(.caption)
                            .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Divider()

                // 性能指标显示
                VStack(alignment: .leading, spacing: 10) {
                    Text("性能指标")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    HStack(spacing: 20) {
                        MetricDisplay(
                            title: "文件大小",
                            value: tests.getFileSizeStatistics(),
                            threshold: "<10MB",
                            passed: tests.allResults.first { $0.testName.contains("文件大小") }?.passed ?? false
                        )

                        MetricDisplay(
                            title: "检索速度",
                            value: String(format: "%.2fms", tests.getAverageRetrievalSpeed()),
                            threshold: "<100ms",
                            passed: tests.allResults.first { $0.testName.contains("检索速度") }?.passed ?? false
                        )

                        MetricDisplay(
                            title: "清理状态",
                            value: tests.allResults.first { $0.testName.contains("清理") }?.passed ?? false ? "已清理" : "待验证",
                            threshold: "30天前文件",
                            passed: tests.allResults.first { $0.testName.contains("清理") }?.passed ?? false
                        )

                        MetricDisplay(
                            title: "进化等级",
                            value: tests.allResults.first { $0.testName.contains("进化") }?.passed ?? false ? "正确" : "待验证",
                            threshold: "1-10级",
                            passed: tests.allResults.first { $0.testName.contains("进化") }?.passed ?? false
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
        }
        .frame(minWidth: 580, minHeight: 480)
    }
}

/// 测试结果行
struct ConvergenceTestResultRow: View {
    let result: MemoryConvergenceTests.TestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // 通过/失败图标
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? .green : .red)

                // 测试名称
                Text(result.testName)
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                // 结果详情
                Text(result.passed ? "通过" : "失败")
                    .font(.caption)
                    .foregroundColor(result.passed ? .green : .red)
            }
            .padding(.vertical, 2)

            // 展开详情
            if !result.passed {
                Text(result.details)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }
        }
    }
}

/// 性能指标显示组件
struct MetricDisplay: View {
    let title: String
    let value: String
    let threshold: String
    let passed: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)

            Text(value)
                .font(.headline)
                .foregroundColor(passed ? .green : .red)

            Text("阈值: \(threshold)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 100)
        .padding(5)
        .background(passed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(5)
    }
}