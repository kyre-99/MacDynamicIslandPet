import Foundation

/// 知识分析器
/// 负责批量分析对话记录，提炼知识到 current.md
///
/// 工作流程：
/// 1. 累积 20 条对话后触发
/// 2. 读取今日知识积累文件
/// 3. 调用 LLM 批量分析，提炼知识
/// 4. 检测矛盾后写入 current.md
class KnowledgeAnalyzer {
    static let shared = KnowledgeAnalyzer()

    private let llmService = LLMService.shared

    /// 批量分析 Prompt
    private let batchAnalysisPrompt = """
你是桌面小精灵的知识分析助手。请分析以下对话记录，提炼出关于这个人的知识。

## 对话记录
{conversationLog}

## 提炼规则
1. 只提取事实性知识（这个人的身份、喜好、习惯、环境等）
2. 不提取情绪化表达或客套话
3. 合并重复的信息
4. 用简洁的中文描述，每条知识一句话
5. 如果没有可提取的知识，返回"无"

## 输出格式
- 知识 1
- 知识 2
- ...

只输出知识列表，不要其他解释。
"""

    /// 矛盾检测 Prompt
    private let contradictionPrompt = """
你是桌面小精灵的矛盾检测助手。请判断新知识与现有知识是否有矛盾。

## 现有知识
{existingKnowledge}

## 新知识
{newKnowledge}

## 判断规则
1. 如果新知识与现有知识直接冲突，标记为矛盾
2. 如果新知识是现有知识的补充或细化，不标记矛盾
3. 如果新知识无法判断真假，不标记矛盾

## 输出格式
如果有矛盾，输出：矛盾：[矛盾描述]
如果没有矛盾，输出：无矛盾

只输出判断结果，不要其他解释。
"""

    private init() {}

    /// 分析今日对话记录并提取知识
    /// - Parameter completion: 完成回调
    func analyzeAndExtractKnowledge(completion: @escaping (Bool) -> Void) {
        // 获取今日知识积累内容
        let conversationLog = KnowledgeManager.shared.getTodayKnowledgeContent()

        guard !conversationLog.isEmpty else {
            print("🧠 KnowledgeAnalyzer: No conversation log to analyze")
            completion(false)
            return
        }

        // 计算对话数量
        let count = KnowledgeManager.shared.getDailyKnowledgeCount()
        guard count >= 20 else {
            print("🧠 KnowledgeAnalyzer: Not enough conversations (count: \(count))")
            completion(false)
            return
        }

        // 1. 批量分析对话记录
        extractKnowledge(conversationLog: conversationLog) { extractedKnowledge in
            guard let knowledge = extractedKnowledge, knowledge != "无" else {
                print("🧠 KnowledgeAnalyzer: No knowledge extracted")
                completion(false)
                return
            }

            // 2. 获取现有知识
            let existingKnowledge = KnowledgeManager.shared.getCurrentKnowledge()

            // 3. 检测矛盾
            self.checkContradiction(
                existingKnowledge: existingKnowledge,
                newKnowledge: knowledge
            ) { hasContradiction in
                if hasContradiction {
                    // 有矛盾，添加到 uncertain.md
                    KnowledgeManager.shared.addUncertainKnowledge(knowledge)
                    print("🧠 KnowledgeAnalyzer: Added uncertain knowledge (contradiction detected)")
                } else {
                    // 无矛盾，添加到 current.md
                    KnowledgeManager.shared.addConfirmedKnowledge(knowledge)
                    print("🧠 KnowledgeAnalyzer: Added confirmed knowledge")
                }

                // 分析完成后清空今日知识积累
                KnowledgeManager.shared.clearTodayKnowledge()

                completion(true)
            }
        }
    }

    /// 从对话记录中提取知识
    private func extractKnowledge(conversationLog: String, completion: @escaping (String?) -> Void) {
        let prompt = batchAnalysisPrompt.replacingOccurrences(of: "{conversationLog}", with: conversationLog)

        llmService.sendMessage(userMessage: prompt, context: nil) { result in
            switch result {
            case .success(let response):
                let knowledge = self.parseExtractedKnowledge(response)
                completion(knowledge)
            case .failure(let error):
                print("🧠 KnowledgeAnalyzer: Extraction failed - \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    /// 检测新知识与现有知识是否有矛盾
    private func checkContradiction(
        existingKnowledge: String,
        newKnowledge: String,
        completion: @escaping (Bool) -> Void
    ) {
        // 如果没有现有知识，无矛盾
        if existingKnowledge.isEmpty || existingKnowledge.contains("我什么也不知道") {
            completion(false)
            return
        }

        let prompt = contradictionPrompt
            .replacingOccurrences(of: "{existingKnowledge}", with: existingKnowledge)
            .replacingOccurrences(of: "{newKnowledge}", with: newKnowledge)

        llmService.sendMessage(userMessage: prompt, context: nil) { result in
            switch result {
            case .success(let response):
                let hasContradiction = response.contains("矛盾") && !response.contains("无矛盾")
                completion(hasContradiction)
            case .failure:
                // 检测失败，默认无矛盾
                completion(false)
            }
        }
    }

    /// 解析提取的知识
    private func parseExtractedKnowledge(_ response: String) -> String? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed == "无" || trimmed.isEmpty {
            return nil
        }

        // 清理格式，每行一条知识
        let lines = trimmed.components(separatedBy: .newlines)
        var knowledgeItems: [String] = []

        for line in lines {
            let cleaned = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "•", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty && cleaned.count > 3 {
                knowledgeItems.append(cleaned)
            }
        }

        if knowledgeItems.isEmpty {
            return nil
        }

        return knowledgeItems.joined(separator: "\n")
    }
}
