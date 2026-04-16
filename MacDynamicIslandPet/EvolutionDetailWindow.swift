import SwiftUI
import AppKit

// MARK: - Evolution Detail Window

/// 进化详情窗口控制器
/// 使用 NSWindowController 正确管理窗口生命周期
class EvolutionDetailWindowController: NSWindowController {
    convenience init() {
        let contentView = EvolutionDetailView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "与精灵的关系"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("📈 EvolutionDetailWindowController created")
    }

    deinit {
        print("📈 EvolutionDetailWindowController deinit")
    }
}

// MARK: - Evolution Detail View

/// 进化详情视图，SwiftUI实现
/// US-009: 进化状态UI显示
struct EvolutionDetailView: View {
    /// 进化状态
    @State private var evolutionState: EvolutionState = EvolutionState.initial

    /// 刷新触发器
    @State private var refreshTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 顶部区域：天数统计
                DaysTogetherSection(state: evolutionState)

                // 当前等级显示区
                CurrentLevelSection(state: evolutionState)

                // 下一等级进度显示
                NextLevelProgressSection(state: evolutionState)

                // 里程碑列表
                MilestonesSection(milestones: evolutionState.milestones)

                // 维度得分指示器
                DimensionScoresSection(state: evolutionState)

                // 刷新按钮
                HStack {
                    Spacer()
                    Button("刷新") {
                        loadEvolutionState()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            .padding(20)
        }
        .frame(minWidth: 450, minHeight: 550)
        .onAppear {
            loadEvolutionState()
        }
    }

    /// 加载进化状态
    private func loadEvolutionState() {
        evolutionState = EvolutionManager.shared.getEvolutionState()
        refreshTrigger.toggle()
        print("📈 EvolutionDetailView: Loaded state - Level: \(evolutionState.currentLevel.rawValue), Days: \(evolutionState.daysTogether)")
    }
}

// MARK: - Days Together Section

/// 互动天数统计区域
struct DaysTogetherSection: View {
    let state: EvolutionState

    var body: some View {
        VStack(spacing: 12) {
            // 大字体显示天数
            Text("认识 \(state.daysTogether) 天")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)

            // 统计信息
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("\(state.totalInteractionCount)")
                        .font(.headline)
                    Text("共互动")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(state.totalConversationCount)")
                        .font(.headline)
                    Text("累计对话")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let firstDate = state.firstInteractionDate {
                    VStack(spacing: 4) {
                        Text(formatDate(firstDate))
                            .font(.headline)
                        Text("首次相遇")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - Current Level Section

/// 当前等级显示区域
struct CurrentLevelSection: View {
    let state: EvolutionState

    var body: some View {
        VStack(spacing: 15) {
            // 等级图标（大号）
            Text(state.currentLevel.icon)
                .font(.system(size: 48))

            // 等级名称
            Text(state.currentLevel.rawValue)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)

            // 等级描述
            Text(state.currentLevel.levelDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 关系阶段标签
            HStack(spacing: 8) {
                ForEach(Array(RelationshipStage.allCases.prefix(state.currentLevel.levelNumber)), id: \.self) { stage in
                    Text(stage.displayName)
                        .font(.caption)
                        .foregroundColor(stage == state.relationshipStage ? .blue : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(stage == state.relationshipStage ? Color.blue.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

// MARK: - Next Level Progress Section

/// 下一等级进度区域
struct NextLevelProgressSection: View {
    let state: EvolutionState

    var body: some View {
        VStack(spacing: 12) {
            // 进度条标题
            HStack {
                Text("升级进度")
                    .font(.headline)

                Spacer()

                if state.currentLevel != .lv10 {
                    Text("还需 \(state.daysToNextLevel) 天升至 \(getNextLevelName())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("已达最高等级")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // 进度条
            if state.currentLevel != .lv10 {
                ProgressView(value: state.nextLevelProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                // 百分比显示
                Text("\(Int(state.nextLevelProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // 最高等级显示
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("终身伙伴")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 10)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }

    /// 获取下一等级名称
    private func getNextLevelName() -> String {
        if state.currentLevel.levelNumber < 10 {
            let nextLevel = EvolutionLevel.allCases[state.currentLevel.levelNumber]
            return nextLevel.displayName
        }
        return ""
    }
}

// MARK: - Milestones Section

/// 里程碑列表区域
struct MilestonesSection: View {
    let milestones: [EvolutionMilestone]

    var body: some View {
        VStack(spacing: 15) {
            // 标题
            HStack {
                Text("里程碑")
                    .font(.headline)
                Text("(\(milestones.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if milestones.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Text("暂无里程碑")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("继续互动解锁更多成就")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else {
                // 里程碑列表
                LazyVStack(spacing: 10) {
                    ForEach(milestones.sorted(by: { $0.unlockedAt > $1.unlockedAt })) { milestone in
                        MilestoneRowView(milestone: milestone)
                    }
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Milestone Row View

/// 单个里程碑显示行
struct MilestoneRowView: View {
    let milestone: EvolutionMilestone

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Text(milestone.icon)
                .font(.title2)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.name)
                    .font(.headline)

                Text(formatDate(milestone.unlockedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 类型标签
            Text(milestone.type.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(8)
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Dimension Scores Section

/// 维度得分指示器区域
struct DimensionScoresSection: View {
    let state: EvolutionState

    var body: some View {
        VStack(spacing: 15) {
            // 标题
            Text("成长维度")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 三个维度得分
            VStack(spacing: 12) {
                // 情感深度
                DimensionScoreRow(
                    icon: "❤️",
                    name: "情感深度",
                    score: state.emotionalDepthScore,
                    description: "与用户关系从陌生到知己的成长过程"
                )

                // 知识广度
                DimensionScoreRow(
                    icon: "📚",
                    name: "知识广度",
                    score: state.knowledgeBreadthScore,
                    description: "了解用户话题领域的数量增长"
                )

                // 表达成熟度
                DimensionScoreRow(
                    icon: "✨",
                    name: "表达成熟度",
                    score: state.expressionMaturityScore,
                    description: "表达能力从简单到细腻的提升"
                )
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Dimension Score Row

/// 单个维度得分显示行
struct DimensionScoreRow: View {
    let icon: String
    let name: String
    let score: Int
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.title2)

                Text(name)
                    .font(.headline)

                Spacer()

                Text("\(score)/100")
                    .font(.subheadline)
                    .foregroundColor(score >= 80 ? .green : score >= 50 ? .blue : .secondary)
            }

            // 进度条
            ProgressView(value: Double(score) / 100.0)
                .progressViewStyle(.linear)
                .tint(score >= 80 ? .green : score >= 50 ? .blue : .gray)

            // 描述
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Evolution Tooltip View

/// 进化状态Tooltip视图，用于精灵hover时显示
/// US-009: PetView hover tooltip
struct EvolutionTooltipView: View {
    let state: EvolutionState

    var body: some View {
        VStack(spacing: 3) {
            // Lv等级
            Text("Lv\(state.currentLevel.levelNumber)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3))

            // 互动天数
            Text("认识\(state.daysTogether)天")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3))
        }
        .padding(6)
        .background(Color.clear)
    }
}

// MARK: - Preview

#Preview("Evolution Detail View") {
    EvolutionDetailView()
}

#Preview("Evolution Tooltip") {
    EvolutionTooltipView(state: EvolutionState.initial)
}