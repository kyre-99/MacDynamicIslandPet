import Foundation

// MARK: - Conversation Analysis Manager

/// 对话分析管理器
///
/// 职责：
/// - 对话窗口关闭时触发知识提炼（20条对话）
/// - 调用 KnowledgeAnalyzer 批量分析对话
class ConversationAnalysisManager {
    /// 共享单例实例
    static let shared = ConversationAnalysisManager()

    /// 是否正在分析（避免重复触发）
    private var isAnalyzing = false
    private let stateLock = NSLock()
    private let relationshipMemoryManager = RelationshipMemoryManager.shared

    private init() {
        print("🧠 ConversationAnalysisManager initialized")
    }

    // MARK: - Trigger Methods

    /// 对话窗口关闭时调用（从ConversationManager）
    func onConversationWindowClosed() {
        let recentConversationCount = KnowledgeManager.shared.getRecentConversations(count: 12).count
        if recentConversationCount > 0 {
            let snapshot = relationshipMemoryManager.refreshRelationshipSnapshot()
            print("🫶 ConversationAnalysisManager: Relationship snapshot refreshed - stage=\(snapshot.stageSummary)")
        }

        // 检查今日知识积累是否达到 20 条
        let count = KnowledgeManager.shared.getDailyKnowledgeCount()
        if count >= 20 {
            guard beginAnalysisIfNeeded() else {
                print("🧠 ConversationAnalysisManager: Already analyzing, skip")
                return
            }

            print("🧠 ConversationAnalysisManager: Window closed, daily knowledge count=\(count), triggering knowledge analysis")
            triggerKnowledgeAnalysis()
        } else if count > 0 {
            print("🧠 ConversationAnalysisManager: Window closed, but daily knowledge count=\(count) < 20, skip analysis")
        }
    }

    /// 触发知识提炼分析（20 条对话后）
    private func triggerKnowledgeAnalysis() {
        print("🧠 ConversationAnalysisManager: Triggering knowledge analysis with \(KnowledgeManager.shared.getDailyKnowledgeCount()) conversations")

        // 后台线程执行分析
        DispatchQueue.global(qos: .background).async {
            KnowledgeAnalyzer.shared.analyzeAndExtractKnowledge { success in
                self.finishAnalysis()
            }
        }
    }

    /// 是否正在分析
    func isCurrentlyAnalyzing() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isAnalyzing
    }

    private func beginAnalysisIfNeeded() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !isAnalyzing else { return false }
        isAnalyzing = true
        return true
    }

    private func finishAnalysis() {
        stateLock.lock()
        isAnalyzing = false
        stateLock.unlock()
    }
}
