import Foundation
import AppKit
import Combine

// MARK: - Scene Object Types

/// Types of scene objects that can appear in the pet's environment
enum SceneObjectType: String, CaseIterable {
    // Primary scenes (triggered by behaviors)
    case petHouse      // 出场动画 - 房子
    case petBed        // 睡觉场景 - 床/窝
    case foodBowl      // 吃东西场景 - 食物碗

    // Decorative scenes (剑与魔法主题)
    case tree          // 树木 - 探索目标
    case rock          // 石头 - 跳跃目标
    case mushroom      // 蘑菇 - 可爱装饰
    case pond          // 水池 - 玩耍场景
    case swing         // 秋千 - 互动场景
    case magicCrystal  // 魔法水晶 - 特殊场景

    // 剑与魔法主题场景
    case dragon        // 小龙 - 奇幻生物
    case magicSword    // 魔法剑 - 插在石头中
    case treasureChest // 宝箱 - 金币宝箱
    case spellBook     // 魔法书 - 发光的符文
    case wizardTower   // 法师塔 - 城堡建筑
    case fireTorch     // 火焰火炬 - 地牢照明
    case skull         // 骷髅 - 地牢装饰
    case magicPortal   // 魔法传送门 - 发光符文圈

    // 大型背景场景
    case tavern        // 酒馆 - 木制建筑
    case castle        // 城堡 - 石制堡垒
    case dungeonEntrance // 地牢入口 - 黑暗拱门

    // 吃东西场景多样化 - 各国美食（已使用 PixelLab 生成精致素材）
    case magicPotion     // 魔法药剂 - 发光瓶子
    case fantasyApple    // 奇幻苹果 - 魔法水果
    case magicCake       // 魔法蛋糕 - 发光蛋糕
    case riceBowl        // 米饭碗 - 白米饭（中式）
    case noodleBowl      // 面条碗 - 热汤面（中式）
    case bentoBox        // 便当盒 - 日式分格饭盒（日式）
    case sushiPlate      // 寿司拼盘（日式）
    case pizzaSlice      // 披萨片（意式）
    case burger          // 汉堡包（美式）
    case kimchiBowl      // 泡菜碗（韩式）
    case curryRice       // 咖喱饭（日式/印度式）
    case bubbleTea       // 珍珠奶茶（台式）

    // 剑与魔法角色
    case knight        // 骑士 - 铁甲战士
    case wizard        // 法师 - 拿杖的魔法师
    case slime         // 史莱姆 - 可爱果冻怪
    case goblin        // 哥布林 - 绿色小怪
    case archer        // 精灵弓箭手 - 拿弓的射手
    case villager      // 村民 - 普通农民
    case fairy         // 妖精 - 翅膀魔法生物
    case ghost         // 幽灵 - 透明鬼魂
    case demon         // 小恶魔 - 红角恶魔
    case orc           // 半兽人 - 绿色壮汉

    /// Get the asset filename for this scene type (snake_case matching actual files)
    var assetFilename: String {
        switch self {
        case .petHouse: return "pet_house"
        case .petBed: return "pet_bed"
        case .foodBowl: return "food_bowl"
        case .tree: return "tree"
        case .rock: return "rock"
        case .mushroom: return "mushroom"
        case .pond: return "pond"
        case .swing: return "swing"
        case .magicCrystal: return "magic_crystal"
        // 剑与魔法主题
        case .dragon: return "dragon"
        case .magicSword: return "magic_sword"
        case .treasureChest: return "treasure_chest"
        case .spellBook: return "spell_book"
        case .wizardTower: return "wizard_tower"
        case .fireTorch: return "fire_torch"
        case .skull: return "skull"
        case .magicPortal: return "magic_portal"
        // 大型背景场景
        case .tavern: return "tavern"
        case .castle: return "castle"
        case .dungeonEntrance: return "dungeon_entrance"
        // 吃东西场景多样化 - 各国美食（已使用 PixelLab 生成精致素材）
        case .magicPotion: return "magic_potion"
        case .fantasyApple: return "fantasy_apple"
        case .magicCake: return "magic_cake"
        case .riceBowl: return "rice_bowl"
        case .noodleBowl: return "noodle_bowl"
        case .bentoBox: return "bento_box"
        case .sushiPlate: return "sushi_plate"
        case .pizzaSlice: return "pizza_slice"
        case .burger: return "burger"
        case .kimchiBowl: return "kimchi_bowl"
        case .curryRice: return "curry_rice"
        case .bubbleTea: return "bubble_tea"
        // 剑与魔法角色
        case .knight: return "knight"
        case .wizard: return "wizard"
        case .slime: return "slime"
        case .goblin: return "goblin"
        case .archer: return "archer"
        case .villager: return "villager"
        case .fairy: return "fairy"
        case .ghost: return "ghost"
        case .demon: return "demon"
        case .orc: return "orc"
        }
    }

    /// Get the default size for this scene type
    var defaultSize: CGSize {
        switch self {
        // 大型背景场景
        case .castle: return CGSize(width: 128, height: 128)
        case .tavern: return CGSize(width: 120, height: 120)
        case .petHouse, .pond, .dragon, .dungeonEntrance:
            return CGSize(width: 96, height: 96)
        // 64x64 角色和建筑
        case .petBed, .tree, .swing, .wizardTower, .magicPortal, .knight, .wizard, .archer, .orc:
            return CGSize(width: 64, height: 64)
        // 48x48 中型元素和角色
        case .foodBowl, .magicCrystal, .magicSword, .treasureChest, .spellBook, .magicCake, .slime, .goblin, .villager, .ghost, .riceBowl, .noodleBowl, .bentoBox, .sushiPlate, .pizzaSlice, .burger, .kimchiBowl, .curryRice, .bubbleTea:
            return CGSize(width: 48, height: 48)
        // 32x32 小型元素和角色
        case .rock, .mushroom, .fireTorch, .skull, .magicPotion, .fantasyApple, .fairy, .demon:
            return CGSize(width: 32, height: 32)
        }
    }

    /// Check if this scene type should be shown for a specific pet task
    func matchesTask(_ task: PetBehaviorTask) -> Bool {
        switch self {
        case .petBed:
            return task == .sleep
        case .foodBowl, .magicPotion, .fantasyApple, .magicCake, .riceBowl, .noodleBowl, .bentoBox, .sushiPlate, .pizzaSlice, .burger, .kimchiBowl, .curryRice, .bubbleTea:
            return task == .eat
        case .tree, .mushroom, .rock:
            return task == .explore
        default:
            return false
        }
    }

    /// Get behavior-specific scene types
    static func scenesForTask(_ task: PetBehaviorTask) -> [SceneObjectType] {
        switch task {
        case .sleep:
            return [.petBed]
        case .eat:
            // 吃东西场景多样化 - 随机选择一个食物元素（包含 PixelLab 生成的精致食物素材）
            let eatObjects: [SceneObjectType] = [
                // 基础食物
                .foodBowl, .magicPotion, .fantasyApple, .magicCake,
                // 亚洲食物
                .riceBowl, .noodleBowl, .bentoBox, .sushiPlate, .kimchiBowl, .curryRice, .bubbleTea,
                // 西方食物
                .pizzaSlice, .burger
            ]
            if let randomObject = eatObjects.randomElement() {
                return [randomObject]
            }
            return [.foodBowl]
        case .explore:
            // 探索任务返回一个随机装饰元素（包含剑与魔法主题）
            let exploreObjects: [SceneObjectType] = [
                // 自然风格
                .tree, .mushroom, .rock, .pond,
                // 剑与魔法主题
                .dragon, .magicSword, .treasureChest, .spellBook,
                .wizardTower, .fireTorch, .skull, .magicPortal,
                // 大型背景场景
                .tavern, .castle, .dungeonEntrance
            ]
            if let randomObject = exploreObjects.randomElement() {
                return [randomObject]
            }
            return []
        default:
            return []
        }
    }

    /// Chinese display name
    var displayName: String {
        switch self {
        case .petHouse: return "小房子"
        case .petBed: return "小窝"
        case .foodBowl: return "食物碗"
        case .tree: return "小树"
        case .rock: return "石头"
        case .mushroom: return "蘑菇"
        case .pond: return "水池"
        case .swing: return "秋千"
        case .magicCrystal: return "魔法水晶"
        // 剑与魔法主题
        case .dragon: return "小龙"
        case .magicSword: return "魔法剑"
        case .treasureChest: return "宝箱"
        case .spellBook: return "魔法书"
        case .wizardTower: return "法师塔"
        case .fireTorch: return "火炬"
        case .skull: return "骷髅"
        case .magicPortal: return "魔法门"
        // 大型背景场景
        case .tavern: return "酒馆"
        case .castle: return "城堡"
        case .dungeonEntrance: return "地牢入口"
        // 吃东西场景多样化（已使用 PixelLab 生成精致素材）
        case .magicPotion: return "魔法药剂"
        case .fantasyApple: return "奇幻苹果"
        case .magicCake: return "魔法蛋糕"
        case .riceBowl: return "米饭碗"
        case .noodleBowl: return "面条碗"
        case .bentoBox: return "便当盒"
        case .sushiPlate: return "寿司拼盘"
        case .pizzaSlice: return "披萨片"
        case .burger: return "汉堡包"
        case .kimchiBowl: return "泡菜碗"
        case .curryRice: return "咖喱饭"
        case .bubbleTea: return "珍珠奶茶"
        // 剑与魔法角色
        case .knight: return "骑士"
        case .wizard: return "法师"
        case .slime: return "史莱姆"
        case .goblin: return "哥布林"
        case .archer: return "弓箭手"
        case .villager: return "村民"
        case .fairy: return "妖精"
        case .ghost: return "幽灵"
        case .demon: return "小恶魔"
        case .orc: return "半兽人"
        }
    }
}

// MARK: - Scene Object Data Model

/// Represents a single scene object instance with position and state
struct SceneObject: Identifiable {
    let id: UUID
    let type: SceneObjectType
    var position: CGPoint
    var size: CGSize
    var isVisible: Bool = true
    var createdAt: Date = Date()

    /// Optional: target position for animation
    var targetPosition: CGPoint?

    /// Optional: associated pet task (for behavior-triggered scenes)
    var associatedTask: PetBehaviorTask?

    /// 是否已被精灵探索过
    var isExplored: Bool = false

    /// 装饰物生命周期（秒）- 超过此时间后会淡出消失
    /// nil 表示永久保留（如床、碗等任务关联元素）
    var lifetime: TimeInterval?

    /// 是否正在淡出消失
    var isFadingOut: Bool = false

    /// 当前透明度（用于淡出动画）
    var opacity: Double = 1.0

    init(type: SceneObjectType, position: CGPoint, size: CGSize? = nil, associatedTask: PetBehaviorTask? = nil) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.size = size ?? type.defaultSize
        self.associatedTask = associatedTask

        // 装饰物设置 20 秒生命周期，任务关联元素不设置（由任务控制）
        if associatedTask == nil && type != .petHouse {
            self.lifetime = 20.0
        }

    }
    /// Check if a point is near this scene object
    func isNear(_ point: CGPoint, threshold: CGFloat = 30) -> Bool {
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let distance = sqrt(pow(point.x - centerX, 2) + pow(point.y - centerY, 2))
        return distance < threshold
    }
}

// MARK: - Scene Object Manager

/// Manages scene objects: creation, positioning, lifecycle, and behavior integration
class SceneObjectManager: ObservableObject {
    static let shared = SceneObjectManager()

    // MARK: - Published Properties

    /// All active scene objects
    @Published var activeObjects: [SceneObject] = []

    /// Whether scene system is enabled
    @Published var isEnabled: Bool = true

    /// House exit animation state
    @Published var isHouseExitAnimationInProgress: Bool = false

    // MARK: - Private Properties

    private let petMover = PetMover.shared
    private var cancellables = Set<AnyCancellable>()

    /// Scene objects asset path
    private let scenesAssetPath = "asserts/scenes/"

    /// Maximum number of decorative objects on screen
    private let maxDecorativeObjects = 10

    /// Cooldown between scene changes (seconds)
    private let sceneChangeCooldown: TimeInterval = 30.0
    private var lastSceneChangeTime: Date = Date.distantPast

    /// 淡出检查定时器
    private var fadeOutTimer: Timer?

    /// 淡出动画持续时间（秒）
    private let fadeOutDuration: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {
        print("🏠 SceneObjectManager: initializing...")
        startFadeOutTimer()
    }

    // MARK: - Fade Out Timer

    /// 启动淡出检查定时器（每5秒检查一次）
    private func startFadeOutTimer() {
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkObjectLifetimes()
        }
        RunLoop.current.add(fadeOutTimer!, forMode: .common)
        print("🏠 淡出定时器已启动")
    }

    /// 检查所有对象的生命周期并触发淡出
    private func checkObjectLifetimes() {
        let now = Date()
        var needsUpdate = false
        var objectsToRemove: [UUID] = []

        // 首先遍历并更新状态，记录需要移除的对象
        for i in activeObjects.indices {
            let object = activeObjects[i]

            // 检查是否需要开始淡出
            if let lifetime = object.lifetime, !object.isFadingOut {
                let age = now.timeIntervalSince(object.createdAt)
                if age >= lifetime {
                    // 开始淡出
                    activeObjects[i].isFadingOut = true
                    print("🏠 \(object.type.displayName) 开始淡出消失（已存在 \(Int(age))秒）")
                    needsUpdate = true
                }
            }

            // 更新淡出透明度
            if activeObjects[i].isFadingOut {
                // 计算淡出进度（从1.0降到0.0）
                let fadeStartTime = activeObjects[i].createdAt.addingTimeInterval(activeObjects[i].lifetime ?? 0)
                let fadeProgress = now.timeIntervalSince(fadeStartTime) / fadeOutDuration

                if fadeProgress >= 1.0 {
                    // 淡出完成，记录要移除的对象ID（不要在遍历中移除）
                    objectsToRemove.append(activeObjects[i].id)
                    print("🏠 \(activeObjects[i].type.displayName) 淡出完成，准备移除")
                } else {
                    // 更新透明度
                    activeObjects[i].opacity = max(0, 1.0 - fadeProgress)
                    needsUpdate = true
                }
            }
        }

        // 移除已淡出完成的对象
        for id in objectsToRemove {
            activeObjects.removeAll { $0.id == id }
        }

        if needsUpdate || !objectsToRemove.isEmpty {
            // 触发UI更新
            objectWillChange.send()
        }
    }

    /// 停止淡出定时器
    private func stopFadeOutTimer() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
    }

    // MARK: - Asset Loading

    /// Load image for a scene object type
    func loadImage(for type: SceneObjectType) -> NSImage? {
        let filename = type.assetFilename

        // Try multiple paths to find the image
        let possiblePaths = [
            // Development path (when running from Xcode or directly)
            "/Users/wangzehua/Project/ralph/asserts/scenes/" + filename + ".png",
            // Food subdirectory (食物素材)
            "/Users/wangzehua/Project/ralph/asserts/scenes/food/" + filename + ".png",
            // Project directory (relative to app bundle)
            Bundle.main.bundlePath + "/../../../asserts/scenes/" + filename + ".png",
            Bundle.main.bundlePath + "/../../../asserts/scenes/food/" + filename + ".png",
            Bundle.main.bundlePath + "/../asserts/scenes/" + filename + ".png",
            Bundle.main.bundlePath + "/../asserts/scenes/food/" + filename + ".png",
            // App bundle Resources
            (Bundle.main.resourcePath ?? "") + "/asserts/scenes/" + filename + ".png",
            (Bundle.main.resourcePath ?? "") + "/asserts/scenes/food/" + filename + ".png",
            // Direct filename in bundle
            Bundle.main.path(forResource: filename, ofType: "png") ?? ""
        ]

        print("🏠 Trying to load scene image: \(filename)")
        for path in possiblePaths {
            print("🏠 Checking path: \(path)")
            if !path.isEmpty {
                if let image = NSImage(contentsOfFile: path) {
                    print("🏠 ✅ Loaded scene image: \(filename) from \(path)")
                    return image
                }
            }
        }

        // Try loading from bundle by name (if added to Assets.xcassets)
        if let image = NSImage(named: filename) {
            print("🏠 ✅ Loaded scene image from bundle: \(filename)")
            return image
        }

        print("⚠️ SceneObjectManager: Could not load image for \(filename) from any path")
        return nil
    }

    // MARK: - Scene Object Creation

    /// Create a scene object at a specific position
    func createObject(type: SceneObjectType, position: CGPoint, associatedTask: PetBehaviorTask? = nil) -> SceneObject {
        var object = SceneObject(type: type, position: position)
        object.associatedTask = associatedTask

        // 设置生命周期：装饰物60秒后消失，任务关联元素不设置
        if associatedTask == nil && type != .petHouse {
            object.lifetime = 20.0
        }

        activeObjects.append(object)
        print("🏠 Created scene object: \(type.displayName) at \(position), task: \(associatedTask?.rawValue ?? "none"), lifetime: \(object.lifetime?.description ?? "永久")")
        return object
    }

    /// Create a scene object for a specific behavior task
    func createObjectForTask(_ task: PetBehaviorTask, near petPosition: CGPoint) -> SceneObject? {
        let sceneTypes = SceneObjectType.scenesForTask(task)
        guard let sceneType = sceneTypes.first else { return nil }

        // Position near pet but with offset
        let offset = generateNearbyOffset(for: sceneType)
        let position = CGPoint(
            x: petPosition.x + offset.x,
            y: petPosition.y + offset.y
        )

        return createObject(type: sceneType, position: position, associatedTask: task)
    }

    /// Generate random offset for placing scene object near pet
    private func generateNearbyOffset(for type: SceneObjectType) -> CGPoint {
        let distanceRange: ClosedRange<CGFloat> = 20...40

        // Random direction (one of 4 directions)
        let directions: [(CGFloat, CGFloat)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        let direction = directions.randomElement() ?? (1, 0)

        let distance = CGFloat.random(in: distanceRange)
        return CGPoint(x: direction.0 * distance, y: direction.1 * distance)
    }

    // MARK: - House Exit Animation

    /// Setup house exit animation - place house at edge and pet will walk out
    func setupHouseExitAnimation() -> (housePosition: CGPoint, petStartPosition: CGPoint, exitDirection: MovementDirection) {
        isHouseExitAnimationInProgress = true

        guard let screen = NSScreen.main else {
            // Fallback: center of screen
            let housePos = CGPoint(x: 400, y: 400)
            let petPos = CGPoint(x: housePos.x + 8, y: housePos.y + 8)  // 80x80 house, 64x64 pet, center offset = 8
            return (housePos, petPos, .south)
        }

        let screenFrame = screen.frame
        let houseSize = SceneObjectType.petHouse.defaultSize  // 80x80
        let petSize: CGFloat = 64

        // 房子放在屏幕边缘，精灵从房子中心开始，然后向外走出
        let edgeOptions: [(position: CGPoint, exitDirection: MovementDirection)] = [
            // 左边缘 - 房子靠左，精灵向右（东）走出
            (CGPoint(x: screenFrame.minX + 50, y: screenFrame.midY - houseSize.height / 2), .east),
            // 右边缘 - 房子靠右，精灵向左（西）走出
            (CGPoint(x: screenFrame.maxX - houseSize.width - 50, y: screenFrame.midY - houseSize.height / 2), .west),
            // 上边缘 - 房子靠上，精灵向下（南）走出
            (CGPoint(x: screenFrame.midX - houseSize.width / 2, y: screenFrame.maxY - houseSize.height - 50), .south),
            // 下边缘 - 房子靠下，精灵向上（北）走出
            (CGPoint(x: screenFrame.midX - houseSize.width / 2, y: screenFrame.minY + 50), .north)
        ]

        // 随机选择一个边缘
        let selected = edgeOptions.randomElement() ?? edgeOptions[0]

        // 创建房子对象
        _ = createObject(type: .petHouse, position: selected.position)

        // 精灵起始位置：房子中心
        // 房子位置是窗口左下角，房子尺寸80x80
        // 精灵尺寸64x64，精灵应该在房子中心
        // 精灵位置 = 房子位置 + (房子尺寸 - 精灵尺寸) / 2
        let petStartPos = CGPoint(
            x: selected.position.x + (houseSize.width - petSize) / 2,  // 80-64=16, /2=8
            y: selected.position.y + (houseSize.height - petSize) / 2
        )

        print("🏠 房子出场动画设置:")
        print("   房子位置: \(selected.position) (屏幕坐标)")
        print("   房子尺寸: \(houseSize)")
        print("   精灵起始位置: \(petStartPos) (房子中心)")
        print("   走出方向: \(selected.exitDirection)")
        print("   屏幕范围: min(\(screenFrame.minX),\(screenFrame.minY)) max(\(screenFrame.maxX),\(screenFrame.maxY))")

        return (selected.position, petStartPos, selected.exitDirection)
    }

    /// Complete house exit animation
    func completeHouseExitAnimation() {
        isHouseExitAnimationInProgress = false

        // Remove house after animation (optional - can keep house visible)
        // For now, we keep the house visible as a permanent fixture
        print("🏠 House exit animation complete")
    }

    /// Remove house from screen
    func removeHouse() {
        activeObjects.removeAll { $0.type == .petHouse }
        print("🏠 House removed from screen")
    }

    // MARK: - Scene Object Management

    /// Remove a specific scene object
    func removeObject(_ object: SceneObject) {
        activeObjects.removeAll { $0.id == object.id }
        print("🏠 Removed scene object: \(object.type.displayName)")
    }

    /// Remove all scene objects of a specific type
    func removeObjectsOfType(_ type: SceneObjectType) {
        activeObjects.removeAll { $0.type == type }
        print("🏠 Removed all \(type.displayName) objects")
    }

    /// Remove all scene objects
    func clearAllObjects() {
        activeObjects.removeAll()
        print("🏠 All scene objects cleared")
    }

    /// Remove task-associated objects when task changes
    func clearTaskObjects(except task: PetBehaviorTask?) {
        activeObjects.removeAll { object in
            if let associatedTask = object.associatedTask {
                return associatedTask != task
            }
            return false
        }
    }

    // MARK: - Position Generation

    /// Generate random position on screen for decorative objects
    func generateRandomPosition(for type: SceneObjectType) -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 300, y: 300)
        }

        let frame = screen.frame
        let size = type.defaultSize
        let margin: CGFloat = 50

        return CGPoint(
            x: CGFloat.random(in: frame.minX + margin...frame.maxX - size.width - margin),
            y: CGFloat.random(in: frame.minY + margin...frame.maxY - size.height - margin)
        )
    }

    /// Generate position near current pet position
    func generateNearPetPosition(for type: SceneObjectType, distance: CGFloat = 60) -> CGPoint {
        let petPos = petMover.position
        let size = type.defaultSize

        // Random direction
        let angle = CGFloat.random(in: 0...2 * CGFloat.pi)
        let offsetX = cos(angle) * distance
        let offsetY = sin(angle) * distance

        let newPos = CGPoint(
            x: petPos.x + offsetX,
            y: petPos.y + offsetY
        )

        // Constrain to screen
        return constrainToScreen(newPos, objectSize: size)
    }

    /// Constrain position to screen bounds
    private func constrainToScreen(_ position: CGPoint, objectSize: CGSize) -> CGPoint {
        guard let screen = NSScreen.main else { return position }

        let frame = screen.frame
        let margin: CGFloat = 20

        return CGPoint(
            x: max(frame.minX + margin, min(frame.maxX - objectSize.width - margin, position.x)),
            y: max(frame.minY + margin, min(frame.maxY - objectSize.height - margin, position.y))
        )
    }

    // MARK: - Decorative Object Spawning

    /// 在屏幕随机位置生成一个装饰物供精灵探索
    func spawnRandomDecorationForExplore() -> SceneObject? {
        // 可用于探索的装饰物类型（包含场景和角色）
        let exploreTypes: [SceneObjectType] = [
            // 自然场景
            .tree, .rock, .mushroom, .pond, .swing, .magicCrystal,
            // 剑与魔法场景
            .dragon, .magicSword, .treasureChest, .spellBook,
            .wizardTower, .fireTorch, .skull, .magicPortal,
            // 大型背景场景
            .tavern, .castle, .dungeonEntrance,
            // 剑与魔法角色
            .knight, .wizard, .slime, .goblin, .archer,
            .villager, .fairy, .ghost, .demon, .orc
        ]

        guard let type = exploreTypes.randomElement() else { return nil }

        // 在屏幕随机位置生成（避开精灵当前位置附近）
        let position = generateRandomPositionAwayFromPet(for: type)
        let object = createObject(type: type, position: position)

        print("🏠 生成探索目标: \(type.displayName) 在位置 \(position)")
        return object
    }

    /// 获取未被探索的装饰物
    func getUnexploredObjects() -> [SceneObject] {
        return activeObjects.filter { !$0.isExplored && $0.associatedTask == nil && $0.type != .petHouse }
    }

    /// 获取距离精灵最近的未探索装饰物
    func getNearestUnexploredObject() -> SceneObject? {
        let petPos = petMover.position
        let unexplored = getUnexploredObjects()

        return unexplored.min(by: { obj1, obj2 in
            let dist1 = sqrt(pow(obj1.position.x - petPos.x, 2) + pow(obj1.position.y - petPos.y, 2))
            let dist2 = sqrt(pow(obj2.position.x - petPos.x, 2) + pow(obj2.position.y - petPos.y, 2))
            return dist1 < dist2
        })
    }

    /// 标记装饰物为已探索
    func markAsExplored(_ object: SceneObject) {
        if let index = activeObjects.firstIndex(where: { $0.id == object.id }) {
            activeObjects[index].isExplored = true
            print("🏠 \(object.type.displayName) 已被探索")
        }
    }

    /// 生成远离精灵的随机位置
    private func generateRandomPositionAwayFromPet(for type: SceneObjectType) -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 300, y: 300)
        }

        let frame = screen.frame
        let size = type.defaultSize
        let margin: CGFloat = 50
        let petPos = petMover.position
        let minDistanceFromPet: CGFloat = 80  // 最少离精灵80像素，走几秒就能到达

        // 尝试多次找到一个合适的位置
        for _ in 0..<10 {
            let candidateX = CGFloat.random(in: frame.minX + margin...frame.maxX - size.width - margin)
            let candidateY = CGFloat.random(in: frame.minY + margin...frame.maxY - size.height - margin)

            let distance = sqrt(pow(candidateX - petPos.x, 2) + pow(candidateY - petPos.y, 2))

            if distance >= minDistanceFromPet {
                return CGPoint(x: candidateX, y: candidateY)
            }
        }

        // 如果找不到，就在屏幕边缘生成
        let edgePositions = [
            CGPoint(x: frame.minX + margin, y: frame.midY),
            CGPoint(x: frame.maxX - size.width - margin, y: frame.midY),
            CGPoint(x: frame.midX, y: frame.minY + margin),
            CGPoint(x: frame.midX, y: frame.maxY - size.height - margin)
        ]
        return edgePositions.randomElement() ?? CGPoint(x: frame.midX, y: frame.midY)
    }

    /// Spawn random decorative objects on screen
    func spawnDecorativeObjects(count: Int = 3) {
        // Check cooldown
        guard Date().timeIntervalSince(lastSceneChangeTime) >= sceneChangeCooldown else {
            return
        }

        // Remove old decorative objects
        removeDecorativeObjects()

        // Types for decorative spawning
        let decorativeTypes: [SceneObjectType] = [.tree, .rock, .mushroom, .pond, .swing, .magicCrystal, .dragon, .treasureChest]

        // Spawn random objects
        for _ in 0..<min(count, maxDecorativeObjects) {
            if let type = decorativeTypes.randomElement() {
                let position = generateRandomPosition(for: type)
                _ = createObject(type: type, position: position)
            }
        }

        lastSceneChangeTime = Date()
        print("🏠 Spawned \(count) decorative objects")
    }

    /// Remove all decorative objects
    func removeDecorativeObjects() {
        let decorativeTypes: [SceneObjectType] = [.tree, .rock, .mushroom, .pond, .swing, .magicCrystal, .dragon, .treasureChest]
        for type in decorativeTypes {
            removeObjectsOfType(type)
        }
    }

    // MARK: - Utility

    /// Get house object if exists
    func getHouseObject() -> SceneObject? {
        return activeObjects.first { $0.type == .petHouse }
    }

    /// Check if pet is near any scene object
    func isPetNearAnySceneObject(threshold: CGFloat = 30) -> SceneObject? {
        let petPos = petMover.position
        return activeObjects.first { $0.isNear(petPos, threshold: threshold) }
    }
}