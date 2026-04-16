import Foundation

/// 知识提取器
/// 负责从对话中提取知识并检测矛盾
///
/// 工作流程：
/// 1. 从对话中提取潜在知识（关于用户、世界、精灵自己的认知）
/// 2. 与现有知识对比检测矛盾
/// 3. 返回提取结果和矛盾标记
class KnowledgeExtractor {
    static let shared = KnowledgeExtractor()

    private let llmService = LLMService.shared

    /// 知识提取 Prompt
    private let extractionPrompt = """
你是桌面小精灵的知识提取助手。请从对话中提取关于这个人的知识。

## 提取规则
1. 只提取事实性知识（这个人的身份、喜好、习惯、环境等）
2. 不提取情绪化表达或客套话
3. 用简洁的中文描述，每条知识一句话
4. 如果没有可提取的知识，返回"无"

## 对话
{conversation}

## 提取的知识格式
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

    /// 提取知识并检测矛盾
    /// - Parameters:
    ///   - userInput: 用户输入
    ///   - petResponse: 精灵回复
    ///   - onComplete: 完成回调（提取的知识，是否有矛盾）
    func extractAndCheckContradiction(
        userInput: String,
        petResponse: String,
        onComplete: @escaping (String?, Bool) -> Void
    ) {
        let conversation = "用户：\(userInput)\n精灵：\(petResponse)"

        // 1. 提取知识
        extractKnowledge(conversation: conversation) { extractedKnowledge in
            guard let knowledge = extractedKnowledge, knowledge != "无" else {
                // 没有可提取的知识
                onComplete(nil, false)
                return
            }

            // 2. 获取现有知识
            let existingKnowledge = KnowledgeManager.shared.getCurrentKnowledge()

            // 3. 检测矛盾
            self.checkContradiction(
                existingKnowledge: existingKnowledge,
                newKnowledge: knowledge
            ) { hasContradiction in
                onComplete(knowledge, hasContradiction)
            }
        }
    }

    /// 从对话中提取知识
    private func extractKnowledge(conversation: String, completion: @escaping (String?) -> Void) {
        let prompt = extractionPrompt.replacingOccurrences(of: "{conversation}", with: conversation)

        llmService.sendMessage(userMessage: prompt, context: nil) { result in
            switch result {
            case .success(let response):
                let knowledge = self.parseExtractedKnowledge(response)
                completion(knowledge)
            case .failure:
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
        if existingKnowledge.isEmpty || existingKnowledge.contains("我刚来到这里") {
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

            if !cleaned.isEmpty {
                knowledgeItems.append(cleaned)
            }
        }

        if knowledgeItems.isEmpty {
            return nil
        }

        return knowledgeItems.joined(separator: "\n")
    }
}
