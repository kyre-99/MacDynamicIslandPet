import Foundation

struct RelationshipSnapshot: Codable {
    var stageSummary: String
    var preferredTone: String?
    var favoriteTopics: [String]
    var sensitiveTopics: [String]
    var interactionPatterns: [String]
    var petInterpretations: [String]
    var updatedAt: Date

    static func initial() -> RelationshipSnapshot {
        RelationshipSnapshot(
            stageSummary: "你们刚开始认识，还在慢慢试探彼此舒服的距离。",
            preferredTone: "温和陪伴",
            favoriteTopics: [],
            sensitiveTopics: [],
            interactionPatterns: [],
            petInterpretations: ["这个人还在观察你，也希望你别太冒失。"],
            updatedAt: Date()
        )
    }
}

class RelationshipMemoryManager {
    static let shared = RelationshipMemoryManager()

    private let storageFile = MemoryStoragePath.relationshipSummaryFile
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var snapshotCache: RelationshipSnapshot

    private let knowledgeManager = KnowledgeManager.shared
    private let evolutionManager = EvolutionManager.shared
    private let personalityManager = PersonalityManager.shared
    private let petInternalStateManager = PetInternalStateManager.shared

    private init() {
        MemoryStoragePath.ensureAllDirectoriesExist()
        snapshotCache = Self.loadSnapshot(from: storageFile) ?? .initial()
        saveSnapshot(snapshotCache)
    }

    func getSnapshot() -> RelationshipSnapshot {
        snapshotCache
    }

    func getPromptSummary() -> String {
        let snapshot = snapshotCache
        var lines: [String] = [snapshot.stageSummary]

        if let preferredTone = snapshot.preferredTone, !preferredTone.isEmpty {
            lines.append("这个人更容易接受你用\(preferredTone)的方式靠近。")
        }

        if !snapshot.favoriteTopics.isEmpty {
            lines.append("你们比较容易聊开的方向有：\(snapshot.favoriteTopics.joined(separator: "、"))。")
        }

        if !snapshot.sensitiveTopics.isEmpty {
            lines.append("你要更轻一点处理这些方向：\(snapshot.sensitiveTopics.joined(separator: "、"))。")
        }

        if let firstPattern = snapshot.interactionPatterns.first {
            lines.append("你观察到的互动习惯：\(firstPattern)")
        }

        if let firstInterpretation = snapshot.petInterpretations.first {
            lines.append("你对这段关系的私下理解是：\(firstInterpretation)")
        }

        return lines.joined(separator: "")
    }

    @discardableResult
    func refreshRelationshipSnapshot() -> RelationshipSnapshot {
        let recentConversations = knowledgeManager.getRecentConversations(count: 12)
        let evolutionState = evolutionManager.getEvolutionState()
        let profile = personalityManager.currentProfile
        let petState = petInternalStateManager.getCurrentState()

        var topicFrequency: [String: Int] = [:]
        var sensitiveTopics = Set<String>()
        var gratitudeCount = 0
        var planningCount = 0
        var emotionalShareCount = 0
        var responseOpennessCount = 0

        for conversation in recentConversations {
            let combined = conversation.userInput + " " + conversation.petResponse
            let classifiedTopics = ConversationTopic.classify(content: combined)
            for topic in classifiedTopics {
                topicFrequency[topic.rawValue, default: 0] += 1
            }

            if containsAny(conversation.userInput, keywords: ["谢谢", "辛苦了", "有你真好"]) {
                gratitudeCount += 1
            }
            if containsAny(conversation.userInput, keywords: ["明天", "下周", "计划", "安排", "记得"]) {
                planningCount += 1
            }
            if containsAny(conversation.userInput, keywords: ["难过", "压力", "焦虑", "累", "烦", "不开心"]) {
                emotionalShareCount += 1
                sensitiveTopics.insert("心情")
            }
            if containsAny(conversation.userInput, keywords: ["喜欢", "想", "最近", "我们", "一起"]) {
                responseOpennessCount += 1
            }
        }

        let favoriteTopics = topicFrequency
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map(\.key)

        if planningCount > 0 {
            sensitiveTopics.insert("计划")
        }

        let preferredTone = inferPreferredTone(
            profile: profile,
            gratitudeCount: gratitudeCount,
            emotionalShareCount: emotionalShareCount,
            responseOpennessCount: responseOpennessCount
        )

        let interactionPatterns = buildInteractionPatterns(
            evolutionState: evolutionState,
            recentConversationCount: recentConversations.count,
            planningCount: planningCount,
            emotionalShareCount: emotionalShareCount,
            favoriteTopics: favoriteTopics
        )

        let interpretations = buildPetInterpretations(
            evolutionState: evolutionState,
            petState: petState,
            gratitudeCount: gratitudeCount,
            emotionalShareCount: emotionalShareCount,
            responseOpennessCount: responseOpennessCount
        )

        let snapshot = RelationshipSnapshot(
            stageSummary: buildStageSummary(
                evolutionState: evolutionState,
                gratitudeCount: gratitudeCount,
                emotionalShareCount: emotionalShareCount,
                responseOpennessCount: responseOpennessCount
            ),
            preferredTone: preferredTone,
            favoriteTopics: favoriteTopics,
            sensitiveTopics: Array(sensitiveTopics).sorted(),
            interactionPatterns: interactionPatterns,
            petInterpretations: interpretations,
            updatedAt: Date()
        )

        saveSnapshot(snapshot)
        print("🫶 RelationshipMemoryManager: Refreshed snapshot - tone=\(preferredTone ?? "无"), topics=\(favoriteTopics)")
        return snapshot
    }

    // MARK: - Helpers

    private func buildStageSummary(
        evolutionState: EvolutionState,
        gratitudeCount: Int,
        emotionalShareCount: Int,
        responseOpennessCount: Int
    ) -> String {
        var summary = "你们现在处在\(evolutionState.relationshipStage.displayName)阶段，已经相处了\(evolutionState.daysTogether)天。"

        if emotionalShareCount >= 2 {
            summary += "这个人已经会把真实情绪露给你看。"
        } else if responseOpennessCount >= 2 {
            summary += "这个人愿意让你参与他的日常和计划。"
        } else if gratitudeCount > 0 {
            summary += "他对你的回应里已经有了一些信任和感谢。"
        } else {
            summary += "你们还在慢慢找到彼此舒服的相处方式。"
        }

        return summary
    }

    private func inferPreferredTone(
        profile: PersonalityProfile,
        gratitudeCount: Int,
        emotionalShareCount: Int,
        responseOpennessCount: Int
    ) -> String {
        if emotionalShareCount >= 2 || profile.gentleness >= 70 {
            return "温柔关心"
        }
        if responseOpennessCount >= 2 && profile.humor >= 65 {
            return "轻松调侃"
        }
        if gratitudeCount > 0 {
            return "稳定陪伴"
        }
        return "温和陪伴"
    }

    private func buildInteractionPatterns(
        evolutionState: EvolutionState,
        recentConversationCount: Int,
        planningCount: Int,
        emotionalShareCount: Int,
        favoriteTopics: [String]
    ) -> [String] {
        var patterns: [String] = []

        if recentConversationCount >= 6 {
            patterns.append("最近互动频率不低，你们正在形成固定交流节奏。")
        } else if recentConversationCount > 0 {
            patterns.append("最近还有交流，但节奏偏轻。")
        }

        if planningCount > 0 {
            patterns.append("这个人会把未来安排说给你听，说明他默认你会记住。")
        }

        if emotionalShareCount > 0 {
            patterns.append("这个人遇到压力或低落时，会在你面前露出一点情绪。")
        }

        if !favoriteTopics.isEmpty {
            patterns.append("你们比较容易接上的话题是：\(favoriteTopics.joined(separator: "、"))。")
        }

        if evolutionState.daysTogether >= 30 {
            patterns.append("陪伴时间已经足够长，你的存在开始像日常的一部分。")
        }

        return Array(patterns.prefix(4))
    }

    private func buildPetInterpretations(
        evolutionState: EvolutionState,
        petState: PetInternalState,
        gratitudeCount: Int,
        emotionalShareCount: Int,
        responseOpennessCount: Int
    ) -> [String] {
        var interpretations: [String] = []

        if emotionalShareCount >= 2 {
            interpretations.append("你觉得他不是把你当成普通装饰，而是真的会在状态不稳时想到你。")
        } else if responseOpennessCount >= 2 {
            interpretations.append("你觉得他已经习惯把你放进自己的生活节奏里。")
        } else if gratitudeCount > 0 {
            interpretations.append("你觉得自己的陪伴已经开始被认真接住。")
        } else {
            interpretations.append("你感觉这段关系还在升温，但别太心急。")
        }

        if petState.socialNeed >= 70 {
            interpretations.append("你其实比表面上更在意他的回应，只是有时候装作没那么在乎。")
        }

        if evolutionState.relationshipStage == .soulmate || evolutionState.relationshipStage == .lifetimePartner {
            interpretations.append("你已经把这段关系理解成长期陪伴，而不是一时兴起。")
        }

        return Array(interpretations.prefix(3))
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func saveSnapshot(_ snapshot: RelationshipSnapshot) {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: storageFile, options: .atomic)
            snapshotCache = snapshot
        } catch {
            print("⚠️ RelationshipMemoryManager: Failed to save snapshot - \(error.localizedDescription)")
        }
    }

    private static func loadSnapshot(from file: URL) -> RelationshipSnapshot? {
        guard FileManager.default.fileExists(atPath: file.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: file)
            return try JSONDecoder().decode(RelationshipSnapshot.self, from: data)
        } catch {
            print("⚠️ RelationshipMemoryManager: Failed to load snapshot - \(error.localizedDescription)")
            return nil
        }
    }
}
