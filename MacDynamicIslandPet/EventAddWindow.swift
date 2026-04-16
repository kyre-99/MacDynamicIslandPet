import SwiftUI
import AppKit

// MARK: - Event Add Window

/// 事件添加窗口控制器
/// 使用 NSWindowController 正确管理窗口生命周期
class EventAddWindowController: NSWindowController {
    convenience init() {
        let contentView = EventAddView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "添加事件"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("📅 EventAddWindowController created")
    }

    deinit {
        print("📅 EventAddWindowController deinit")
    }
}

// MARK: - Event List Window

/// 事件列表窗口控制器
class EventListWindowController: NSWindowController {
    convenience init() {
        let contentView = EventListView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "事件时间线"
        window.center()
        window.contentView = hostingView

        self.init(window: window)
        print("📅 EventListWindowController created")
    }

    deinit {
        print("📅 EventListWindowController deinit")
    }
}

// MARK: - Event Add View

/// 事件添加视图，SwiftUI实现
struct EventAddView: View {
    /// 选中的日期
    @State private var selectedDate = Date()

    /// 选中的事件类型
    @State private var selectedEventType: EventType = .birthday

    /// 事件描述
    @State private var description: String = ""

    /// 重要性评分
    @State private var importance: Int = 5

    /// 是否每年重复
    @State private var isRecurring: Bool = false

    /// 保存成功提示
    @State private var showSuccessMessage: Bool = false

    /// 用于取消异步任务的标记
    @State private var hideSuccessTask: Task<Void, Never>?

    /// 窗口引用（用于关闭）
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题
                Text("添加新事件")
                    .font(.headline)
                    .padding(.top, 10)

            // 日期选择
            VStack(alignment: .leading, spacing: 8) {
                Text("事件日期")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.field)
                .labelsHidden()
            }

            // 事件类型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("事件类型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("事件类型", selection: $selectedEventType) {
                    ForEach(EventType.allCases, id: \.self) { type in
                        HStack {
                            Text(type.icon)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }

            // 事件描述
            VStack(alignment: .leading, spacing: 8) {
                Text("事件描述")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("输入事件描述...", text: $description)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            // 重要性滑块
            VStack(alignment: .leading, spacing: 8) {
                Text("重要性评分：\(importance)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { Double(importance) },
                    set: { importance = Int($0) }
                ), in: 1...10, step: 1)
                .frame(maxWidth: .infinity)

                HStack {
                    Text("低")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("高")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 每年重复复选框
            Toggle(isOn: $isRecurring) {
                HStack {
                    Text("每年重复")
                    Text("(适用于生日、纪念日)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            // 类型说明
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedEventType.icon + " " + selectedEventType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(selectedEventType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            Spacer()

            // 按钮区域
            HStack(spacing: 20) {
                Button("重置") {
                    resetForm()
                }
                .buttonStyle(.bordered)

                Button("保存") {
                    saveEvent()
                }
                .buttonStyle(.borderedProminent)
                .disabled(description.isEmpty)
            }
            .padding(.bottom, 10)

            // 成功提示
            if showSuccessMessage {
                Text("事件已成功添加！")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        .padding(20)
    }
    .frame(minWidth: 380, minHeight: 450)
    .onDisappear {
        // 取消异步任务，防止窗口关闭后访问已释放内存
        hideSuccessTask?.cancel()
    }
}

    /// 重置表单
    private func resetForm() {
        selectedDate = Date()
        selectedEventType = .birthday
        description = ""
        importance = 5
        isRecurring = false
        showSuccessMessage = false
        hideSuccessTask?.cancel()
    }

    /// 保存事件
    private func saveEvent() {
        // 创建事件
        let event = TimelineEvent.create(
            date: selectedDate,
            type: selectedEventType,
            description: description,
            importance: importance,
            source: "manual",
            relatedConversations: [],
            isRecurring: isRecurring
        )

        // 保存到时间线
        let success = TimelineMemoryManager.shared.addEvent(event)

        if success {
            showSuccessMessage = true

            // 取消之前的任务
            hideSuccessTask?.cancel()

            // 使用 Task 替代 DispatchQueue
            hideSuccessTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                showSuccessMessage = false
                // 重置表单以便添加下一个事件
                description = ""
            }

            print("📅 Event saved manually: \(event.type.rawValue) - \(event.description)")
        } else {
            print("⚠️ Failed to save event")
        }
    }
}

// MARK: - Event List Window (for viewing events)

// MARK: - Event List View

/// 事件列表视图，显示所有事件
struct EventListView: View {
    /// 所有事件
    @State private var events: [TimelineEvent] = []

    /// 选中的筛选类型
    @State private var filterType: EventType? = nil

    /// 刷新触发器
    @State private var refreshTrigger = false

    var body: some View {
        VStack(spacing: 15) {
            // 筛选器
            HStack {
                Text("筛选类型:")
                    .font(.subheadline)

                Picker("筛选", selection: Binding(
                    get: { filterType?.rawValue ?? "全部" },
                    set: { newValue in
                        filterType = newValue == "全部" ? nil : EventType(rawValue: newValue)
                    }
                )) {
                    Text("全部").tag("全部")
                    ForEach(EventType.allCases, id: \.self) { type in
                        Text(type.icon + " " + type.rawValue).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Spacer()

                Button("刷新") {
                    loadEvents()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            // 事件列表
            if filteredEvents.isEmpty {
                VStack(spacing: 10) {
                    Text("暂无事件")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击\"添加事件\"添加新的时间线事件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredEvents) { event in
                            EventRowView(event: event, onDelete: {
                                deleteEvent(event.id)
                            })
                        }
                    }
                }
            }

            // 统计信息
            HStack {
                Text("总计: \(filteredEvents.count) 个事件")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                let upcomingCount = TimelineMemoryManager.shared.getUpcomingEvents(7).count
                if upcomingCount > 0 {
                    Text("本周即将到来: \(upcomingCount) 个")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 10)
        }
        .padding(15)
        .onAppear {
            loadEvents()
        }
    }

    /// 筛选后的事件列表
    private var filteredEvents: [TimelineEvent] {
        if let type = filterType {
            return events.filter { $0.type == type }
        }
        return events
    }

    /// 加载事件
    private func loadEvents() {
        events = TimelineMemoryManager.shared.getAllEvents()
        refreshTrigger.toggle()
    }

    /// 删除事件
    private func deleteEvent(_ eventId: String) {
        TimelineMemoryManager.shared.deleteEvent(eventId)
        loadEvents()
    }
}

// MARK: - Event Row View

/// 单个事件显示行
struct EventRowView: View {
    let event: TimelineEvent
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Text(event.type.icon)
                .font(.title2)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(event.description)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // 日期
                    Text(formatDate(event.date))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 重复标记
                    if event.isRecurring {
                        Text("每年")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }

                    // 来源标记
                    Text(event.source == "manual" ? "手动添加" : "自动提取")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 重要性评分（星星）
                HStack(spacing: 2) {
                    ForEach(1..<(event.importance + 1), id: \.self) { _ in
                        Text("⭐")
                            .font(.caption2)
                    }
                    Text("(\(event.importance))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 删除按钮
            Button(action: {
                showDeleteConfirm = true
            }) {
                Text("删除")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .confirmationDialog("确认删除？", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    onDelete()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复，确定要删除这个事件吗？")
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY年MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Event Add View") {
    EventAddView()
}

#Preview("Event List View") {
    EventListView()
}