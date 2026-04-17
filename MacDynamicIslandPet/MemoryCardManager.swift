import Foundation

enum MemoryCardType: String, Codable, CaseIterable {
    case fact
    case preference
    case relationship
    case event
    case reflection
    case unfinished
}

struct MemoryCard: Codable, Identifiable {
    var id: String
    var createdAt: Date
    var updatedAt: Date
    var type: MemoryCardType
    var summary: String
    var topics: [String]
    var emotionImpact: Int
    var relationshipImpact: Int
    var recallTriggers: [String]
    var sourceIDs: [String]
    var confidence: Double
    var lastReferencedAt: Date?
}

struct MemoryCardQuery {
    var text: String?
    var emotion: UserEmotionState?
    var appName: String?
    var limit: Int = 3
}

class MemoryCardManager {
    static let shared = MemoryCardManager()

    private let storageFile = MemoryStoragePath.memoryCardsFile
    private var cardsCache: [MemoryCard] = []
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        MemoryStoragePath.ensureAllDirectoriesExist()
        loadCards()
    }

    // MARK: - Public API

    func ingestConversation(
        userInput: String,
        petResponse: String,
        topics: [ConversationTopic],
        emotions: [EmotionTag],
        importanceScore: Int
    ) {
        let summary = "用户提到：\(trim(userInput, limit: 42))；你回应：\(trim(petResponse, limit: 42))。"
        let cardType = inferConversationCardType(userInput: userInput, topics: topics)
        let triggers = topics.map(\.rawValue) + emotions.map(\.rawValue) + extractTriggers(from: userInput)
        let emotionImpact = min(100, max(importanceScore * 10, emotions.count * 18))
        let relationshipImpact = calculateRelationshipImpact(from: userInput, petResponse: petResponse, importanceScore: importanceScore)

        upsertCard(
            type: cardType,
            summary: summary,
            topics: topics.map(\.rawValue),
            emotionImpact: emotionImpact,
            relationshipImpact: relationshipImpact,
            recallTriggers: triggers,
            sourceIDs: ["conversation:\(userInput.hashValue)", "response:\(petResponse.hashValue)"],
            confidence: 0.72
        )
    }

    func ingestPerception(
        appName: String,
        activityDescription: String,
        screenshotSummary: String?,
        petReaction: String?
    ) {
        var summary = "你看到他在\(appName)里\(trim(activityDescription, limit: 36))。"
        if let petReaction, !petReaction.isEmpty {
            summary += " 当时你说了：\(trim(petReaction, limit: 24))。"
        }

        let appCategory = WindowObserver.shared.getAppCategory(appName)
        let topics = [appName, appCategory.displayName]
        let triggers = topics + extractTriggers(from: activityDescription) + extractTriggers(from: screenshotSummary ?? "")

        upsertCard(
            type: .reflection,
            summary: summary,
            topics: topics,
            emotionImpact: screenshotSummary == nil ? 28 : 42,
            relationshipImpact: petReaction == nil ? 22 : 35,
            recallTriggers: triggers,
            sourceIDs: ["perception:\(appName):\(activityDescription.hashValue)"],
            confidence: screenshotSummary == nil ? 0.58 : 0.75
        )
    }

    func ingestTimelineEvent(_ event: TimelineEvent) {
        let summary = "有一个\(event.type.rawValue)：\(trim(event.description, limit: 42))。"
        let triggers = [event.type.rawValue, event.description]

        upsertCard(
            type: .event,
            summary: summary,
            topics: [event.type.rawValue],
            emotionImpact: min(100, event.importance * 10),
            relationshipImpact: min(100, event.importance * 11),
            recallTriggers: triggers,
            sourceIDs: ["timeline:\(event.id)"],
            confidence: 0.88
        )
    }

    func searchRelevantCards(query: MemoryCardQuery) -> [MemoryCard] {
        guard !cardsCache.isEmpty else { return [] }

        let scored = cardsCache.map { card in
            (card: card, score: score(card: card, query: query))
        }
        .filter { $0.score > 0.12 }
        .sorted {
            if abs($0.score - $1.score) > 0.0001 {
                return $0.score > $1.score
            }
            return $0.card.updatedAt > $1.card.updatedAt
        }

        let selected = Array(scored.prefix(query.limit).map(\.card))
        markReferenced(selected.map(\.id))
        return selected
    }

    func getAllCards() -> [MemoryCard] {
        cardsCache.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Persistence

    private func loadCards() {
        guard FileManager.default.fileExists(atPath: storageFile.path) else {
            cardsCache = []
            saveCards()
            return
        }

        do {
            let data = try Data(contentsOf: storageFile)
            cardsCache = try decoder.decode([MemoryCard].self, from: data)
        } catch {
            print("⚠️ MemoryCardManager: Failed to load cards - \(error.localizedDescription)")
            cardsCache = []
        }
    }

    private func saveCards() {
        do {
            let data = try encoder.encode(cardsCache)
            try data.write(to: storageFile, options: .atomic)
        } catch {
            print("⚠️ MemoryCardManager: Failed to save cards - \(error.localizedDescription)")
        }
    }

    // MARK: - Internal Upsert

    private func upsertCard(
        type: MemoryCardType,
        summary: String,
        topics: [String],
        emotionImpact: Int,
        relationshipImpact: Int,
        recallTriggers: [String],
        sourceIDs: [String],
        confidence: Double
    ) {
        let normalizedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTriggers = normalizeStrings(recallTriggers + topics)
        let normalizedTopics = normalizeStrings(topics)

        if let existingIndex = cardsCache.firstIndex(where: { existing in
            existing.type == type &&
            (existing.summary == normalizedSummary || !Set(existing.sourceIDs).isDisjoint(with: sourceIDs))
        }) {
            cardsCache[existingIndex].updatedAt = Date()
            cardsCache[existingIndex].summary = normalizedSummary
            cardsCache[existingIndex].topics = normalizeStrings(cardsCache[existingIndex].topics + normalizedTopics)
            cardsCache[existingIndex].recallTriggers = normalizeStrings(cardsCache[existingIndex].recallTriggers + normalizedTriggers)
            cardsCache[existingIndex].sourceIDs = normalizeStrings(cardsCache[existingIndex].sourceIDs + sourceIDs)
            cardsCache[existingIndex].emotionImpact = max(cardsCache[existingIndex].emotionImpact, emotionImpact)
            cardsCache[existingIndex].relationshipImpact = max(cardsCache[existingIndex].relationshipImpact, relationshipImpact)
            cardsCache[existingIndex].confidence = max(cardsCache[existingIndex].confidence, confidence)
        } else {
            cardsCache.append(
                MemoryCard(
                    id: UUID().uuidString,
                    createdAt: Date(),
                    updatedAt: Date(),
                    type: type,
                    summary: normalizedSummary,
                    topics: normalizedTopics,
                    emotionImpact: min(100, max(0, emotionImpact)),
                    relationshipImpact: min(100, max(0, relationshipImpact)),
                    recallTriggers: normalizedTriggers,
                    sourceIDs: sourceIDs,
                    confidence: max(0.0, min(1.0, confidence)),
                    lastReferencedAt: nil
                )
            )
        }

        trimCardCount(limit: 300)
        saveCards()
        print("🧠 MemoryCardManager: Upserted \(type.rawValue) card - \(trim(normalizedSummary, limit: 40))")
    }

    private func markReferenced(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let now = Date()
        var changed = false
        for index in cardsCache.indices {
            if ids.contains(cardsCache[index].id) {
                cardsCache[index].lastReferencedAt = now
                changed = true
            }
        }
        if changed {
            saveCards()
        }
    }

    // MARK: - Scoring

    private func score(card: MemoryCard, query: MemoryCardQuery) -> Double {
        var relevance: Double = 0

        if let text = query.text?.lowercased(), !text.isEmpty {
            let keywords = tokenize(text)
            let matched = keywords.filter { keyword in
                card.summary.lowercased().contains(keyword) ||
                card.recallTriggers.contains(where: { $0.lowercased().contains(keyword) }) ||
                card.topics.contains(where: { $0.lowercased().contains(keyword) })
            }.count

            relevance += Double(matched) / Double(max(1, keywords.count))
        }

        if let emotion = query.emotion {
            if card.recallTriggers.contains(where: { $0.contains(emotion.rawValue) }) ||
                card.summary.contains(emotion.rawValue) {
                relevance += 0.7
            }
        }

        if let appName = query.appName, !appName.isEmpty {
            if card.summary.contains(appName) || card.topics.contains(appName) {
                relevance += 0.6
            }
        }

        let hoursSinceUpdate = max(1.0, Date().timeIntervalSince(card.updatedAt) / 3600.0)
        let recency = min(1.0, 24.0 / hoursSinceUpdate)
        let emotional = Double(card.emotionImpact) / 100.0
        let relationship = Double(card.relationshipImpact) / 100.0

        return relevance * 0.5 + recency * 0.2 + emotional * 0.2 + relationship * 0.1
    }

    // MARK: - Helpers

    private func inferConversationCardType(userInput: String, topics: [ConversationTopic]) -> MemoryCardType {
        if userInput.contains("喜欢") || userInput.contains("不喜欢") || userInput.contains("想吃") {
            return .preference
        }

        if userInput.contains("明天") || userInput.contains("下周") || userInput.contains("记得") {
            return .unfinished
        }

        if topics.contains(.relationship) {
            return .relationship
        }

        return .fact
    }

    private func calculateRelationshipImpact(from userInput: String, petResponse: String, importanceScore: Int) -> Int {
        var impact = importanceScore * 8
        if userInput.contains("谢谢") || userInput.contains("陪") || petResponse.contains("陪") {
            impact += 18
        }
        if userInput.contains("喜欢") || userInput.contains("想你") {
            impact += 22
        }
        return min(100, max(15, impact))
    }

    private func extractTriggers(from text: String) -> [String] {
        let keywords = ["工作", "娱乐", "心情", "计划", "日常", "兴趣", "关系", "累", "开心", "压力", "焦虑", "明天", "下周", "Xcode", "Safari", "微信"]
        return keywords.filter { text.contains($0) }
    }

    private func tokenize(_ text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return text.components(separatedBy: separators).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func trimCardCount(limit: Int) {
        guard cardsCache.count > limit else { return }
        cardsCache = cardsCache.sorted { lhs, rhs in
            let lhsScore = (lhs.lastReferencedAt ?? lhs.updatedAt)
            let rhsScore = (rhs.lastReferencedAt ?? rhs.updatedAt)
            return lhsScore > rhsScore
        }
        cardsCache = Array(cardsCache.prefix(limit))
    }

    private func normalizeStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private func trim(_ text: String, limit: Int) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        guard normalized.count > limit else { return normalized }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<endIndex]) + "..."
    }
}
