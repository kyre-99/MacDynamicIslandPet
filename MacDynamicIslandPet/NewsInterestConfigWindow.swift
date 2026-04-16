import SwiftUI
import AppKit

/// 新闻兴趣配置窗口视图
///
/// 提供精灵关注的新闻领域完整配置界面：
/// - 6个新闻领域复选框（科技、娱乐、生活、游戏、财经、体育）
/// - 自定义RSS源输入区域（添加/删除自定义URL）
/// - 实时显示当前选中领域数量提示
/// - 保存按钮（持久化到config.json）
/// - 重置按钮（恢复默认配置）
///
/// 窗口标题："精灵关注的新闻领域"
/// US-011: 新闻源配置UI实现
struct NewsInterestConfigView: View {
    /// 科技领域选中状态
    @State private var techSelected: Bool = false
    /// 娱乐领域选中状态
    @State private var entertainmentSelected: Bool = false
    /// 生活领域选中状态
    @State private var lifeSelected: Bool = false
    /// 游戏领域选中状态
    @State private var gamesSelected: Bool = false
    /// 财经领域选中状态
    @State private var financeSelected: Bool = false
    /// 体育领域选中状态
    @State private var sportsSelected: Bool = false

    /// 自定义RSS源列表
    @State private var customRSSSources: [String] = []
    /// 当前输入的自定义RSS URL
    @State private var newRSSURL: String = ""

    /// 保存成功提示显示状态
    @State private var showingSaveSuccess: Bool = false
    /// 保存消息内容
    @State private var saveMessage: String = ""

    /// 用于取消异步任务的标记
    @State private var hideSuccessTask: Task<Void, Never>?

    /// 配置管理器实例
    private let configManager = AppConfigManager.shared

    /// 当前选中的领域数量
    private var selectedCount: Int {
        [
            techSelected,
            entertainmentSelected,
            lifeSelected,
            gamesSelected,
            financeSelected,
            sportsSelected
        ].filter { $0 }.count
    }

    /// 当前选中的领域名称列表
    private var selectedCategories: [String] {
        var categories: [String] = []
        if techSelected { categories.append(NewsCategory.tech.rawValue) }
        if entertainmentSelected { categories.append(NewsCategory.entertainment.rawValue) }
        if lifeSelected { categories.append(NewsCategory.life.rawValue) }
        if gamesSelected { categories.append(NewsCategory.games.rawValue) }
        if financeSelected { categories.append(NewsCategory.finance.rawValue) }
        if sportsSelected { categories.append(NewsCategory.sports.rawValue) }
        return categories
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                Text("精灵关注的新闻领域")
                    .font(.headline)
                    .padding(.bottom, 8)

            // 新闻领域复选框区域
            VStack(alignment: .leading, spacing: 12) {
                Text("选择精灵关注的新闻领域:")
                    .font(.subheadline)

                // 科技领域
                NewsCategoryCheckboxView(
                    category: .tech,
                    isSelected: $techSelected,
                    rssDescription: "feeds.arstechnica.com"
                )

                // 娱乐领域
                NewsCategoryCheckboxView(
                    category: .entertainment,
                    isSelected: $entertainmentSelected,
                    rssDescription: "reddit.com/r/entertainment"
                )

                // 生活领域
                NewsCategoryCheckboxView(
                    category: .life,
                    isSelected: $lifeSelected,
                    rssDescription: "lifehacker.com"
                )

                // 游戏领域
                NewsCategoryCheckboxView(
                    category: .games,
                    isSelected: $gamesSelected,
                    rssDescription: "reddit.com/r/gaming"
                )

                // 财经领域
                NewsCategoryCheckboxView(
                    category: .finance,
                    isSelected: $financeSelected,
                    rssDescription: "reddit.com/r/finance"
                )

                // 体育领域
                NewsCategoryCheckboxView(
                    category: .sports,
                    isSelected: $sportsSelected,
                    rssDescription: "reddit.com/r/sports"
                )
            }

            Divider()

            // 自定义RSS源输入区域
            VStack(alignment: .leading, spacing: 8) {
                Text("自定义RSS源:")
                    .font(.subheadline)

                // 输入框和添加按钮
                HStack(spacing: 8) {
                    TextField("输入RSS URL", text: $newRSSURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)

                    Button("添加") {
                        addCustomRSS()
                    }
                    .buttonStyle(.bordered)
                    .disabled(newRSSURL.isEmpty || !isValidURL(newRSSURL))
                }

                // 自定义RSS源列表
                if !customRSSSources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已添加的自定义源:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(customRSSSources.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                Text(customRSSSources[index])
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Button("删除") {
                                    removeCustomRSS(at: index)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(4)
                }
            }

            Divider()

            // 状态提示区域
            VStack(alignment: .leading, spacing: 4) {
                Text("精灵将关注 \(selectedCount) 个新闻领域")
                    .font(.subheadline)
                    .foregroundColor(selectedCount > 0 ? .primary : .orange)

                if selectedCount == 0 {
                    Text("建议至少选择一个领域，否则精灵不会进行自主思考")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
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
                    saveConfiguration()
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
            loadCurrentConfiguration()
        }
        .onDisappear {
            // 取消异步任务，防止窗口关闭后访问已释放内存
            hideSuccessTask?.cancel()
        }
    }

    /// 加载当前配置
    private func loadCurrentConfiguration() {
        guard let config = configManager.config else {
            // 使用默认配置
            techSelected = true
            entertainmentSelected = true
            gamesSelected = true
            return
        }

        // 加载新闻兴趣配置
        if let newsInterests = config.newsInterests {
            techSelected = newsInterests.contains(NewsCategory.tech.rawValue)
            entertainmentSelected = newsInterests.contains(NewsCategory.entertainment.rawValue)
            lifeSelected = newsInterests.contains(NewsCategory.life.rawValue)
            gamesSelected = newsInterests.contains(NewsCategory.games.rawValue)
            financeSelected = newsInterests.contains(NewsCategory.finance.rawValue)
            sportsSelected = newsInterests.contains(NewsCategory.sports.rawValue)
        } else {
            // 默认配置
            techSelected = true
            entertainmentSelected = true
            gamesSelected = true
        }

        // 加载自定义RSS源
        if let customSources = config.customRSSSources {
            customRSSSources = customSources
        }
    }

    /// 添加自定义RSS源
    private func addCustomRSS() {
        let trimmedURL = newRSSURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查URL是否有效
        guard isValidURL(trimmedURL) else { return }

        // 检查是否已存在
        guard !customRSSSources.contains(trimmedURL) else {
            saveMessage = "该RSS源已存在"
            showingSaveSuccess = true

            // 取消之前的任务
            hideSuccessTask?.cancel()

            // 使用 Task 替代 DispatchQueue
            hideSuccessTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                showingSaveSuccess = false
            }
            return
        }

        // 添加到列表
        customRSSSources.append(trimmedURL)
        newRSSURL = ""
    }

    /// 删除自定义RSS源
    /// - Parameter index: 要删除的索引
    private func removeCustomRSS(at index: Int) {
        customRSSSources.remove(at: index)
    }

    /// 验证URL是否有效
    /// - Parameter urlString: URL字符串
    /// - Returns: 是否有效
    private func isValidURL(_ urlString: String) -> Bool {
        // 检查是否为空
        guard !urlString.isEmpty else { return false }

        // 检查是否可以创建URL
        guard URL(string: urlString) != nil else { return false }

        // 检查是否为http或https
        guard urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else { return false }

        return true
    }

    /// 保存配置到config.json
    private func saveConfiguration() {
        // 获取当前配置
        guard var config = configManager.config else {
            saveMessage = "无法读取当前配置文件"
            showingSaveSuccess = true
            return
        }

        // 更新新闻兴趣配置
        config.newsInterests = selectedCategories

        // 更新自定义RSS源配置
        config.customRSSSources = customRSSSources.isEmpty ? nil : customRSSSources

        // 保存配置
        if configManager.saveConfig(config) {
            saveMessage = "配置已保存！精灵将关注新的新闻领域"
            showingSaveSuccess = true

            // 通知AutonomousThinkingManager更新新闻源
            AutonomousThinkingManager.shared.updateNewsCategories()

            // 取消之前的任务
            hideSuccessTask?.cancel()

            // 使用 Task 替代 DispatchQueue
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

    /// 重置到默认配置
    private func resetToDefault() {
        // 默认选中科技、娱乐、游戏
        techSelected = true
        entertainmentSelected = true
        gamesSelected = true
        lifeSelected = false
        financeSelected = false
        sportsSelected = false

        // 清空自定义RSS源
        customRSSSources = []
        newRSSURL = ""
    }
}

/// 新闻领域复选框视图组件
///
/// 用于显示单个新闻领域的复选框控件
/// 包含图标、名称、复选框和RSS源说明
struct NewsCategoryCheckboxView: View {
    /// 新闻领域类型
    let category: NewsCategory
    /// 选中状态绑定
    @Binding var isSelected: Bool
    /// RSS源说明
    let rssDescription: String

    var body: some View {
        HStack(spacing: 12) {
            // 领域图标
            Text(category.icon)
                .font(.title3)

            // 领域名称
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.subheadline)
                Text("RSS源: \(rssDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 150, alignment: .leading)

            // 复选框
            Toggle("", isOn: $isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// 新闻兴趣配置窗口控制器
/// 使用 NSWindowController 正确管理窗口生命周期
class NewsInterestConfigWindowController: NSWindowController {
    convenience init() {
        let contentView = NewsInterestConfigView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "精灵关注的新闻领域"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("🟣 NewsInterestConfigWindowController created")
    }

    deinit {
        print("🟣 NewsInterestConfigWindowController deinit")
    }
}

#Preview {
    NewsInterestConfigView()
}