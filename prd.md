# MacDynamicIslandPet 拟人化与记忆上下文升级 PRD

## 1. 项目背景

当前项目已经具备以下能力：

- 性格参数系统：`PersonalityProfile` / `PersonalityManager`
- 用户情绪追踪：`EmotionTracker`
- 多层记忆雏形：`MemoryArchitecture` / `MemoryManager` / `TimelineMemoryManager`
- 主动气泡与自言自语：`CommentGenerator` / `SelfTalkManager`
- 对话上下文拼接：`ConversationManager`

现阶段的主要问题不是“缺少记忆”，而是“记忆没有被组织成持续的自我与心流”：

- 小人能记录信息，但不够像在持续思考
- 上下文更多是直接拼接，而不是按当前场景做选择性召回
- 只追踪用户情绪，没有完整追踪“小人自己的内部状态”
- 长期关系变化没有被沉淀成稳定的关系认知

本 PRD 目标是把现有系统升级为更拟人化、更连续、更有“自己想法”的小人系统。

## 2. 产品目标

### 2.1 总目标

让桌面小人具备以下特征：

- 像一个持续活着的角色，而不是每轮重新扮演
- 会因为经历形成偏好、挂念、情绪和关系判断
- 能在当前场景下只召回少量但最相关的上下文
- 会表现出“我现在在想什么”“我还惦记着什么”

### 2.2 用户感知目标

用户应明显感受到：

- 小人说话更连续，不跳戏
- 小人会记得关键事，但不会每次都重复流水账
- 小人有自己的情绪、偏好和关注点
- 小人在主动气泡、自言自语、正式对话中的人格一致

## 3. 设计原则

### 3.1 少而准，不堆上下文

每次生成只给模型必要且高命中的信息，不再简单堆叠全文记忆。

### 3.2 先组织，再生成

任何对话、自言自语、主动评论前，都先构建“工作记忆”。

### 3.3 事实、关系、自我解释分层

记忆不只存事实，还要存：

- 关系判断
- 内部感受
- 未完成念头

### 3.4 渐进式改造

优先兼容现有代码，不做一次性推翻重构。

## 4. 范围定义

### 4.1 本期范围

- 新增工作记忆组织层
- 新增小人内部状态层
- 新增长期关系记忆与关系摘要
- 新增结构化记忆卡片
- 重构对话、主动气泡、自言自语的上下文组装方式
- 为每阶段补充基础测试与可观测日志

### 4.2 暂不包含

- 多角色系统
- 云端同步
- 向量数据库或复杂外部检索服务
- 大规模 UI 改版

## 5. 目标架构

建议将上下文系统拆为四层：

### 5.1 Persona Core

稳定人格底座，来自当前：

- `PersonalityProfile`
- `PersonalityManager`

特点：

- 低频变化
- 决定表达风格与行为倾向

### 5.2 Pet Internal State

新增的小人内部状态，表示“小人现在在想什么、感觉如何”。

建议字段：

- `mood`
- `energy`
- `socialNeed`
- `attachmentLevel`
- `frustration`
- `curiosityFocus`
- `currentGoal`
- `unfinishedThought`
- `lastInteractionAt`

### 5.3 Relationship Memory

小人对用户关系的长期理解。

建议内容：

- 用户通常什么时候愿意互动
- 用户偏好的语气
- 哪些话题容易获得回应
- 哪些行为会让小人更靠近或更失落
- 最近关系变化摘要

### 5.4 Working Memory

每次生成前动态组装的“当前心流上下文”。

建议包含：

- 当前身份与关系状态
- 当前内部状态
- 当前观察与环境
- 最近几轮对话
- 召回的 1~3 条高相关记忆
- 1 条未完成念头或挂念事项

## 6. 数据模型规划

### 6.1 新增：PetInternalState

建议新增文件：

- `MacDynamicIslandPet/PetInternalStateManager.swift`

建议结构：

```swift
struct PetInternalState: Codable {
    var mood: String
    var energy: Int
    var socialNeed: Int
    var attachmentLevel: Int
    var frustration: Int
    var curiosityFocus: String?
    var currentGoal: String?
    var unfinishedThought: String?
    var lastInteractionAt: Date?
    var updatedAt: Date
}
```

建议存储：

- `memory/pet-internal-state.json`

### 6.2 新增：MemoryCard

建议新增文件：

- `MacDynamicIslandPet/MemoryCardManager.swift`

建议结构：

```swift
struct MemoryCard: Codable, Identifiable {
    var id: String
    var createdAt: Date
    var updatedAt: Date
    var type: String
    var summary: String
    var topics: [String]
    var emotionImpact: Int
    var relationshipImpact: Int
    var recallTriggers: [String]
    var sourceIDs: [String]
    var confidence: Double
    var lastReferencedAt: Date?
}
```

记忆卡片类型建议：

- `fact`
- `preference`
- `relationship`
- `event`
- `reflection`
- `unfinished`

### 6.3 新增：RelationshipSnapshot

建议作为关系摘要文件保存，新增文件：

- `MacDynamicIslandPet/RelationshipMemoryManager.swift`

建议结构：

```swift
struct RelationshipSnapshot: Codable {
    var stageSummary: String
    var preferredTone: String?
    var favoriteTopics: [String]
    var sensitiveTopics: [String]
    var interactionPatterns: [String]
    var petInterpretations: [String]
    var updatedAt: Date
}
```

### 6.4 新增：WorkingMemoryContext

建议新增文件：

- `MacDynamicIslandPet/WorkingMemoryManager.swift`

建议结构：

```swift
struct WorkingMemoryContext {
    var identitySummary: String
    var relationshipSummary: String
    var internalStateSummary: String
    var environmentSummary: String
    var recentConversationSummary: String
    var recalledMemories: [String]
    var unfinishedThought: String?
}
```

## 7. 分阶段实施计划

后续执行按以下阶段逐条推进，每个阶段完成后都必须进行验证。

### 当前执行状态

- `Phase 0` 已完成
- `Phase 1` 已完成
- `Phase 2` 已完成
- `Phase 3` 已完成
- `Phase 4` 已完成
- `Phase 5` 已完成
- `Phase 6` 已完成

### Phase 0：建立基线与可观测性

目标：

- 在改造前明确现状行为
- 为后续每一步建立日志与验证入口

改动建议：

- 梳理当前上下文拼接入口：
  - `ConversationManager.buildSystemPrompt()`
  - `CommentGenerator`
  - `SelfTalkManager`
- 补充关键日志：
  - 本次生成使用了哪些上下文
  - 召回了哪些记忆
  - 当前内部状态是什么

涉及文件：

- `MacDynamicIslandPet/ConversationManager.swift`
- `MacDynamicIslandPet/CommentGenerator.swift`
- `MacDynamicIslandPet/SelfTalkManager.swift`

验收标准：

- 能明确看到每次生成用到的上下文来源

测试：

- 手动触发 3 次对话
- 手动触发 3 次自言自语
- 检查日志是否可读

已完成实现：

- 在 `ConversationManager` 中补充了对话上下文日志，记录用户输入、system prompt 规模、历史轮数，以及性格/关系/情绪/知识等上下文片段
- 在 `CommentGenerator` 中补充了自言自语与气泡请求日志，记录触发场景、人格提示、关系提示、主人状态、知识量和最终来源
- 在 `SelfTalkManager` 中补充了触发原因、映射 trigger scene、当前 app、停留时长、冷却状态等观测日志
- 这一步为后续每轮 prompt 裁剪和连续性调优提供了可观测基础

### Phase 1：新增小人内部状态层

目标：

- 让系统不只知道“用户如何”，也知道“小人现在如何”

改动建议：

- 新增 `PetInternalStateManager`
- 增加状态更新规则
- 在以下事件中更新内部状态：
  - 用户主动对话
  - 长时间未互动
  - 被忽略
  - 触发自言自语
  - 收到积极回应

建议初始规则：

- 长时间未互动：`socialNeed` 上升
- 深夜用户还在忙：`concern` 或 `protective` 倾向上升
- 连续被触发但用户未对话：`frustration` 小幅上升
- 用户频繁互动：`attachmentLevel` 上升

涉及文件：

- 新增 `MacDynamicIslandPet/PetInternalStateManager.swift`
- 修改 `MacDynamicIslandPet/ConversationManager.swift`
- 修改 `MacDynamicIslandPet/SelfTalkManager.swift`
- 修改 `MacDynamicIslandPet/CommentGenerator.swift`

验收标准：

- 小人内部状态可以持久化
- 不同行为会引起内部状态变化
- 生成文案开始体现“当前心情”

测试：

- 单元测试：状态增减规则
- 手动测试：间隔触发与连续互动触发

已完成实现：

- 新增 `MacDynamicIslandPet/PetInternalStateManager.swift`
- 在 `MemoryArchitecture.swift` 中增加 `pet-internal-state.json` 存储路径
- 内部状态已接入 `ConversationManager`、`SelfTalkManager`、`CommentGenerator`
- 当前已支持 `mood`、`energy`、`socialNeed`、`attachmentLevel`、`frustration`、`curiosityFocus`、`currentGoal`、`unfinishedThought`
- 增加了被动漂移规则，避免每次读取 prompt 时重复累计状态
- 新增 `MacDynamicIslandPet/PetInternalStateTests.swift`，覆盖对话开始、长时间未互动、自言自语触发、低落安慰等核心规则

### Phase 2：新增 Working Memory 组装层

目标：

- 把“原始记忆”转成“本轮真正需要的上下文”

改动建议：

- 新增 `WorkingMemoryManager`
- 为三类入口统一组装上下文：
  - 正式对话
  - 自言自语
  - 主动评论/气泡
- 输出统一格式摘要，而不是全文拼接

上下文选择建议：

- 最近对话：3~5 轮
- 当前观察：1 条
- 用户情绪：1 条摘要
- 内部状态：1 条摘要
- 召回记忆：1~3 条
- 未完成念头：0~1 条

涉及文件：

- 新增 `MacDynamicIslandPet/WorkingMemoryManager.swift`
- 修改 `MacDynamicIslandPet/ConversationManager.swift`
- 修改 `MacDynamicIslandPet/CommentGenerator.swift`

验收标准：

- 三个生成入口都走统一工作记忆组装
- Prompt 长度明显更可控
- 回复的连续性明显提升

测试：

- 比较改造前后 prompt 日志长度
- 连续对话测试
- 切换应用场景测试

已完成实现：

- 新增 `MacDynamicIslandPet/WorkingMemoryManager.swift`
- 对话和自言自语已统一改为先构建 `WorkingMemoryContext`，再进入 prompt
- 当前工作记忆包含：身份、关系、内部状态、环境、最近互动、召回记忆、未完成念头
- `ConversationManager` 与 `CommentGenerator` 已改为使用统一工作记忆，而非各自零散拼接上下文

### Phase 3：引入结构化记忆卡片

目标：

- 从“全文文件记忆”升级为“可检索、可排序、可复用”的记忆对象

改动建议：

- 新增 `MemoryCardManager`
- 从现有来源提炼卡片：
  - 对话
  - 感知记录
  - 时间线事件
  - 知识总结
- 建立简单召回评分

召回排序建议：

- 相关度 0.5
- 新近性 0.2
- 情绪强度 0.2
- 关系重要度 0.1

涉及文件：

- 新增 `MacDynamicIslandPet/MemoryCardManager.swift`
- 修改 `MacDynamicIslandPet/MemoryManager.swift`
- 修改 `MacDynamicIslandPet/PerceptionMemoryManager.swift`
- 修改 `MacDynamicIslandPet/TimelineMemoryManager.swift`
- 修改 `MacDynamicIslandPet/KnowledgeManager.swift`

验收标准：

- 能生成结构化记忆卡片
- 能按条件召回高相关记忆
- 召回内容可供 `WorkingMemoryManager` 使用

测试：

- 单元测试：召回排序逻辑
- 手动测试：不同 app / 不同情绪 / 不同时间段下召回结果是否合理

已完成实现：

- 新增 `MacDynamicIslandPet/MemoryCardManager.swift`
- 在 `MemoryArchitecture.swift` 中增加 `memory-cards.json` 存储路径
- 已从 `MemoryManager`、`PerceptionMemoryManager`、`TimelineMemoryManager` 三个入口提炼结构化卡片
- `WorkingMemoryManager` 已优先按 `query + emotion + appName` 检索记忆卡片，命不中时才退回规则式 fallback
- 新增 `MacDynamicIslandPet/MemoryCardTests.swift`，覆盖对话建卡与感知检索

### Phase 4：新增关系记忆与关系摘要

目标：

- 让小人形成“我和这个人现在是什么关系”的长期理解

改动建议：

- 新增 `RelationshipMemoryManager`
- 定期从近期对话与互动中提炼：
  - 用户偏好语气
  - 容易回应的话题
  - 容易沉默的话题
  - 关系是亲近、试探、依赖还是疏离
- 支持 `ConversationManager` 和 `CommentGenerator` 引用关系摘要

涉及文件：

- 新增 `MacDynamicIslandPet/RelationshipMemoryManager.swift`
- 修改 `MacDynamicIslandPet/ConversationAnalysisManager.swift`
- 修改 `MacDynamicIslandPet/ConversationManager.swift`

验收标准：

- 关系摘要会随互动积累更新
- 小人的称呼、语气、靠近程度更稳定

测试：

- 模拟多轮互动后检查关系摘要是否变化
- 验证长期语气是否更一致

已完成实现：

- 新增 `MacDynamicIslandPet/RelationshipMemoryManager.swift`
- 在 `MemoryArchitecture.swift` 中增加 `relationship-summary.json` 存储路径
- 已从近期对话、关系阶段、性格和内部状态中提炼 `stageSummary`、`preferredTone`、`favoriteTopics`、`sensitiveTopics`、`interactionPatterns`、`petInterpretations`
- `WorkingMemoryManager` 现已优先使用关系摘要作为 prompt 中的关系部分
- `ConversationAnalysisManager` 已在对话窗口关闭时刷新关系快照，而不是只服务知识分析
- 新增 `MacDynamicIslandPet/RelationshipMemoryTests.swift`，覆盖关系快照刷新与情绪型关系摘要

### Phase 5：增加“未完成念头”机制

目标：

- 让小人像是一直在惦记某件事，而不是每轮都清空状态

改动建议：

- 在内部状态或记忆卡片中增加 `unfinishedThought`
- 来源可以是：
  - 今天未聊完的话题
  - 用户的重要安排
  - 小人最近特别在意的点
- 仅在合适时机轻量提及，避免复读

涉及文件：

- `MacDynamicIslandPet/PetInternalStateManager.swift`
- `MacDynamicIslandPet/WorkingMemoryManager.swift`
- `MacDynamicIslandPet/CommentGenerator.swift`
- `MacDynamicIslandPet/ConversationManager.swift`

验收标准：

- 小人偶尔会自然续上前面的念头
- 不会频繁重复同一句挂念

测试：

- 手动测试跨时段连续性
- 验证去重逻辑

已完成实现：

- `PetInternalStateManager` 中的 `unfinishedThought` 已升级为带类型、更新时间、上次提及时间、提及次数的挂念机制
- 当前支持三类挂念：`plan`、`comfort`、`followUp`
- 已增加挂念冷却、衰减和上下文相关性判断，避免连续复读
- `WorkingMemoryManager` 已在对话和自言自语入口按场景“消费”挂念，而不是每轮直接塞进 prompt
- `ConversationManager` 与 `CommentGenerator` 的 prompt 已增加“轻轻带一下，不要反复提”的约束
- `PetInternalStateTests` 已补充“会形成挂念”“有冷却不连续复读”两条测试

### Phase 6：统一测试与行为回归

目标：

- 验证改造后没有破坏现有基础功能

测试范围：

- 对话窗口回复
- 自言自语触发
- 主动评论触发
- 记忆落盘与读取
- 今日事件提醒
- 情绪跟踪兼容性

建议补充测试文件：

- `MacDynamicIslandPet/WorkingMemoryTests.swift`
- `MacDynamicIslandPet/PetInternalStateTests.swift`
- `MacDynamicIslandPet/MemoryCardTests.swift`
- `MacDynamicIslandPet/RelationshipMemoryTests.swift`

验收标准：

- 核心功能不回退
- 新增上下文组织层稳定工作
- 生成内容更有连续性和拟人感

已完成实现：

- 新增 `MacDynamicIslandPet/WorkingMemoryTests.swift`
- 新增 `MacDynamicIslandPet/BehaviorRegressionTests.swift`
- `WorkingMemoryTests` 当前覆盖：结构块完整性、对话连续性、自言自语时的记忆裁剪
- `BehaviorRegressionTests` 已将 `PetInternalStateTests`、`MemoryCardTests`、`RelationshipMemoryTests`、`WorkingMemoryTests` 串为统一回归入口
- 所有阶段完成后均已重新执行 `xcodebuild -project /Users/wangzehua/Project/MacDynamicIslandPet/MacDynamicIslandPet.xcodeproj -scheme MacDynamicIslandPet -configuration Debug -sdk macosx build`
- 当前构建状态为 `BUILD SUCCEEDED`

## 8. 关键接入点

### 8.1 ConversationManager

当前问题：

- `buildSystemPrompt()` 负责太多内容拼接
- 对话历史依赖 `KnowledgeManager.getRecentConversations()`，缺少相关性选择

目标改造：

- 改为调用 `WorkingMemoryManager.buildConversationContext(...)`

### 8.2 CommentGenerator

当前问题：

- 气泡有类型，但心流来源不统一
- 多数内容仍偏事件驱动，不够“内心驱动”

目标改造：

- 每次气泡生成前先拉取内部状态与工作记忆

### 8.3 SelfTalkManager

当前问题：

- 自言自语更像“定时评论”
- 缺少持续挂念或内在动机

目标改造：

- 触发时基于 `PetInternalState + WorkingMemory + unfinishedThought`

### 8.4 ConversationAnalysisManager

当前问题：

- 目前主要服务知识提炼

目标改造：

- 增加关系摘要与记忆卡片提炼入口

## 9. Prompt 组织原则

后续 prompt 统一建议结构：

```text
你是这个桌面小人。

[身份]
你是谁，你和用户关系如何。

[当前内心]
你现在的情绪、关注点、未完成念头。

[当前观察]
用户此刻状态、时间、环境。

[被唤起的记忆]
1~3 条相关记忆。

[说话要求]
简短、自然、像是你正在继续活着。
```

约束：

- 不要一次塞过多历史全文
- 不要机械重复同一条记忆
- 不要强行引用无关事件

## 10. 风险与对策

### 风险 1：上下文变多导致回复更乱

对策：

- 强制工作记忆裁剪
- 每次最多召回 3 条高相关记忆

### 风险 2：小人“太戏精”或过度拟人

对策：

- 内部状态影响语气，但不能压过用户意图
- 正式对话时仍以用户输入为主

### 风险 3：挂念机制变成复读

对策：

- 给 `unfinishedThought` 增加冷却与衰减
- 引用后记录 `lastReferencedAt`

### 风险 4：结构化记忆生成质量不稳定

对策：

- 初期优先规则生成，少依赖复杂自动抽取
- 先建立卡片框架，再逐步升级提炼质量

## 11. 执行方式

后续按本文件逐条推进，推荐流程：

1. 读取一个 Phase 的目标和验收标准
2. 只修改该 Phase 范围内的代码
3. 完成后做对应测试
4. 通过后再进入下一条

## 12. 第一优先级建议

建议修改顺序如下：

1. `Phase 1：新增小人内部状态层`
2. `Phase 2：新增 Working Memory 组装层`
3. `Phase 3：引入结构化记忆卡片`
4. `Phase 4：新增关系记忆与关系摘要`
5. `Phase 5：增加未完成念头机制`
6. `Phase 6：统一测试与行为回归`

如果后续逐步施工，本 PRD 将作为唯一执行主线，不额外分叉。
