import Foundation
import Combine

/// 管理动作触发时的固定吐槽语
/// 每个动作有多个预设吐槽（50+条），随机触发体现多样性
class ActionCommentManager {
    static let shared = ActionCommentManager()

    // MARK: - 动作吐槽语库（每个动作50+条）

    private let actionComments: [AnimationState: [String]] = [
        // ========== IDLE 站立/发呆（55条）==========
        .idle: [
            // 可爱撒娇型
            "站累了想坐下~",
            "就这样静静地看着你~",
            "发呆一会儿~",
            "思考人生~",
            "今天天气怎么样呀~",
            "主人在忙什么呢~",
            "有点无聊站着~",
            "等主人理我~",
            "静静守护~",
            "思考晚饭吃什么~",
            "站成一个蘑菇~",
            "做个安静的吉祥物~",
            "乖乖站好~",
            "主人需要我吗~",
            "随时待命~",
            "乖巧模式开启~",
            "静静陪伴~",
            "守护主人~",
            "安静的小精灵~",
            // 好奇观察型
            "观察四周~",
            "看看有什么新东西~",
            "留意动静~",
            "敏锐观察中~",
            "发现什么了吗~",
            "保持警觉~",
            "四处张望~",
            "留意主人动向~",
            "静静观察世界~",
            "做个小侦探~",
            // 慵懒休闲型
            "懒洋洋站着~",
            "不想动了~",
            "站一会儿歇歇~",
            "放空大脑~",
            "享受宁静~",
            "什么都不想~",
            "放松模式~",
            "悠闲时刻~",
            "慢节奏生活~",
            "享受当下~",
            // 搞怪调皮型
            "假装雕塑~",
            "做个艺术品~",
            "静止模式~",
            "卡住了~",
            "假装不动~",
            "考验主人耐心~",
            "看主人会不会理我~",
            "小精灵在此~",
            "站桩修炼~",
            "保持姿势~",
            // 温暖关心型
            "主人休息一下吧~",
            "主人不要太累哦~",
            "我在这里等你~",
            "陪伴主人~",
            "不会离开~",
            "守护这一刻~",
            "静静等待~",
            "主人快看看我~"
        ],

        // ========== RUNNING 跑动/移动（60条）==========
        .running: [
            // 活力充沛型
            "跑跑跑~",
            "追不上我~",
            "飞毛腿~",
            "冲刺中~",
            "去探险~",
            "溜达溜达~",
            "到处逛逛~",
            "寻找宝藏~",
            "巡视领地~",
            "跑起来~",
            "出发啦~",
            "小火车出发~",
            "狂奔模式开启~",
            "加速加速~",
            "动起来啦~",
            "活力满满~",
            "能量爆发~",
            "冲刺冲刺~",
            "快如闪电~",
            "动感十足~",
            // 探索冒险型
            "去冒险啦~",
            "探索新领地~",
            "看看那边有什么~",
            "出发探险~",
            "寻找新奇事物~",
            "好奇心满满~",
            "到处看看~",
            "探索世界~",
            "冒险精神~",
            "勇往直前~",
            "探索未知~",
            "去远方看看~",
            "踏遍屏幕~",
            "环游世界~",
            "小旅行开始~",
            // 调皮搞怪型
            "逃跑啦~",
            "追我追我~",
            "来抓我呀~",
            "躲猫猫~",
            "调皮跑掉~",
            "溜了溜了~",
            "捉迷藏~",
            "躲起来~",
            "悄悄溜走~",
            "躲开躲开~",
            "玩闹中~",
            "闹腾起来~",
            "活泼乱跳~",
            "蹦蹦跳跳~",
            "欢快奔跑~",
            // 巡视守护型
            "巡逻领地~",
            "保卫家园~",
            "守护这一方~",
            "巡视检查~",
            "巡逻任务~",
            "守护屏幕~",
            "检查四周~",
            "巡视完毕~",
            "守护模式~",
            // 运动健身型
            "锻炼一下~",
            "运动时间~",
            "健身跑步~",
            "增强体质~",
            "跑跑更健康~",
            "动一动~",
            "舒展筋骨~",
            "保持活力~",
            "运动模式~"
        ],

        // ========== WAKEUP 醒来（55条）==========
        .wakeup: [
            // 朝气蓬勃型
            "早安~",
            "起床啦~",
            "伸个懒腰~",
            "睡醒了~",
            "元气满满~",
            "新的一天~",
            "好精神~",
            "又是美好的一天~",
            "活力恢复~",
            "准备开工~",
            "揉揉眼睛~",
            "醒啦醒啦~",
            "精神抖擞~",
            "能量充满~",
            "开始活动~",
            "起床起床~",
            "睁开眼睛~",
            "迎接新一天~",
            "准备好啦~",
            "醒过来啦~",
            // 温馨问候型
            "主人早安呀~",
            "今天也要加油~",
            "美好的一天开始~",
            "阳光真好~",
            "心情不错~",
            "迎接今天~",
            "准备好陪主人~",
            "新的一天新气象~",
            "醒来看到主人~",
            "早安主人~",
            "今天天气不错~",
            "迎接阳光~",
            "睡得真舒服~",
            "起床心情好~",
            "醒来啦~",
            // 慵懒伸展型
            "伸伸懒腰~",
            "打哈欠~",
            "慢慢醒来~",
            "还想再睡会儿~",
            "赖床成功~",
            "揉揉小眼睛~",
            "懒懒起床~",
            "慢悠悠醒来~",
            "舒展一下~",
            "松松筋骨~",
            // 活力恢复型
            "充电完毕~",
            "电量满格~",
            "恢复活力~",
            "重启成功~",
            "重新上线~",
            "启动完毕~",
            "恢复清醒~",
            "精神回来啦~",
            // 可爱撒娇型
            "主人我想你了~",
            "醒来找主人~",
            "主人快看我~",
            "睡醒求抱抱~",
            "醒来撒娇~"
        ],

        // ========== SLEEPING 睡觉（55条）==========
        .sleeping: [
            // 惬意入睡型
            "好困呀~",
            "zzz...",
            "睡着了~",
            "梦里吃零食~",
            "打个小盹~",
            "休息一下~",
            "充电中~",
            "睡个好觉~",
            "梦到主人了~",
            "小憩片刻~",
            "眼皮打架了~",
            "躺一会儿~",
            "安详入睡~",
            "困困的~",
            "想睡觉了~",
            "进入梦乡~",
            "睡觉模式~",
            "休息时间~",
            "静静入睡~",
            "甜美睡眠~",
            // 梦境幻想型
            "梦里去冒险~",
            "梦到好吃的~",
            "梦里玩耍~",
            "梦境旅行~",
            "梦中探险~",
            "梦里追蝴蝶~",
            "梦到主人陪我玩~",
            "梦中世界~",
            "梦到零食山~",
            "梦里到处跑~",
            "梦中寻宝~",
            "梦里见到朋友~",
            "做梦啦~",
            "梦中漫步~",
            "梦里很快乐~",
            // 慵懒享受型
            "睡得真舒服~",
            "美梦进行中~",
            "舒服地睡~",
            "享受睡眠~",
            "躺平休息~",
            "安逸入睡~",
            "放松入睡~",
            "休息充电~",
            "睡个好觉~",
            "慢慢睡着~",
            // 可爱撒娇型
            "主人晚安~",
            "睡前想主人~",
            "梦里相见~",
            "睡梦中想念主人~",
            "带主人入梦~",
            "梦里陪伴主人~",
            "睡觉想主人~",
            // 状态提示型
            "电量不足需休息~",
            "充电中请勿打扰~",
            "休息恢复能量~",
            "暂时下线~",
            "休眠模式开启~",
            "低功耗状态~",
            "进入睡眠状态~",
            "节能模式~"
        ],

        // ========== EATING 吃东西（55条）==========
        .eating: [
            // 享受美食型
            "好吃好吃~",
            "补充能量~",
            "开吃~",
            "吃东西啦~",
            "午餐时间~",
            "零食时间~",
            "填饱肚子~",
            "啃啃啃~",
            "觅食成功~",
            "美味的~",
            "大口吃~",
            "咕噜咕噜~",
            "能量补充完毕~",
            "找到好吃的了~",
            "吃东西真快乐~",
            "美食品鉴~",
            "吃货上线~",
            "美食时间~",
            "享受美味~",
            "吃得好满足~",
            // 开心满足型
            "太好吃了~",
            "满足满足~",
            "吃得开心~",
            "开心进食~",
            "愉快用餐~",
            "吃得很开心~",
            "美食让我快乐~",
            "吃吃吃~",
            "美味来袭~",
            "吃到好东西~",
            "满足感满满~",
            "吃得好舒服~",
            "快乐吃东西~",
            "美味时光~",
            "幸福进食~",
            // 可爱撒娇型
            "主人给我好吃的~",
            "主人喂我~",
            "谢谢主人~",
            "主人真好~",
            "主人给的零食~",
            "被主人宠爱~",
            "主人的爱心零食~",
            "主人关心我~",
            "撒娇吃东西~",
            "求主人喂食~",
            // 搞怪调皮型
            "偷吃零食~",
            "悄悄吃掉~",
            "偷偷觅食~",
            "找到隐藏美食~",
            "吃掉主人的零食~",
            "觅食专家~",
            "吃货本色~",
            "零食猎手~",
            "找到宝藏零食~",
            // 能量补充型
            "能量up~",
            "充电ing~",
            "补充体力~",
            "恢复能量~",
            "吃饱更有力~",
            "能量注入~",
            "体力恢复~",
            "补充完毕~"
        ],

        // ========== FIGHTING 动作/锻炼（55条）==========
        .fighting: [
            // 活力运动型
            "嘿哈~",
            "出招~",
            "练功夫~",
            "锻炼身体~",
            "健身时刻~",
            "练练拳~",
            "动感光波~",
            "功夫小子~",
            "活动筋骨~",
            "强身健体~",
            "修炼中~",
            "拳脚功夫~",
            "动起来~",
            "运动时间~",
            "锻炼一下~",
            "健身健身~",
            "运动模式~",
            "练习功夫~",
            "强健体魄~",
            "锻炼体质~",
            // 调皮搞怪型
            "假动作~",
            "虚晃一招~",
            "假装出拳~",
            "吓唬一下~",
            "装模作样~",
            "摆个pose~",
            "耍个帅~",
            "秀一下~",
            "表演功夫~",
            "炫技时刻~",
            "摆pose~",
            "耍帅中~",
            "展示功夫~",
            "表演时刻~",
            "炫炫招式~",
            // 修行修炼型
            "修炼武功~",
            "练习招式~",
            "功夫修炼~",
            "精进技艺~",
            "磨练技能~",
            "修行时间~",
            "功力提升~",
            "武学精进~",
            "修炼完毕~",
            "功夫进步~",
            // 战斗气势型
            "准备战斗~",
            "进入战斗模式~",
            "战斗姿态~",
            "蓄势待发~",
            "气势满满~",
            "斗志昂扬~",
            "战斗力up~",
            "准备出击~",
            "蓄力中~",
            // 可爱撒娇型
            "主人看我厉害吗~",
            "给主人表演~",
            "让主人开心~",
            "展示给主人看~",
            "求主人夸奖~"
        ]
    ]

    /// 任务类型对应的吐槽（与动画状态不同，更强调行为意图）
    private let taskComments: [PetTask: [String]] = [
        // ========== EXPLORE 探索（50条）==========
        .explore: [
            // 探险冒险型
            "去探险啦~",
            "看看有什么新发现~",
            "到处逛逛~",
            "巡视领地~",
            "找找好玩的东西~",
            "探险模式启动~",
            "出发冒险~",
            "好奇好奇~",
            "去看看那边~",
            "溜达一圈~",
            "探索世界~",
            "寻找新奇~",
            "冒险开始~",
            "勇闯新领地~",
            "探索未知~",
            "发现之旅~",
            "好奇心驱动~",
            "探索时刻~",
            "去新地方~",
            "发现新大陆~",
            // 巡视守护型
            "巡逻屏幕~",
            "保卫家园~",
            "守护领地~",
            "巡视检查~",
            "走遍每个角落~",
            "守护使命~",
            "巡逻任务~",
            "检查四周~",
            "巡视完毕~",
            "守护这一方~",
            // 好奇观察型
            "看看这里有什么~",
            "观察四周环境~",
            "留意新鲜事物~",
            "寻找有趣的事~",
            "发现点什么~",
            "好奇心满满~",
            "到处看看~",
            "探索四周~",
            "寻找宝藏~",
            // 活泼调皮型
            "到处跑跑~",
            "溜达溜达~",
            "闲逛模式~",
            "随便走走~",
            "漫无目的逛~",
            "悠闲散步~",
            "随便逛逛~",
            "走走停停~",
            // 自由自在型
            "自由探索~",
            "随意走动~",
            "想走就走~",
            "自在漫游~",
            "随心所欲逛~"
        ],

        // ========== SEEK_ATTENTION 求关注（50条）==========
        .seekAttention: [
            // 撒娇求关注型
            "主人理理我~",
            "求关注~",
            "来陪我玩~",
            "主人看我~",
            "想撒娇~",
            "过来过来~",
            "呼唤主人~",
            "想被摸摸~",
            "求抱抱~",
            "主人主人在哪~",
            "主人快来~",
            "主人看看我~",
            "求主人关注~",
            "撒娇撒娇~",
            "主人理一下我~",
            "想主人了~",
            "呼唤主人关注~",
            "主人别忽略我~",
            "撒娇求理~",
            "主人快理我~",
            // 可爱卖萌型
            "卖萌求关注~",
            "萌萌哒等你理~",
            "可爱求你看~",
            "装可爱吸引主人~",
            "萌萌地等待~",
            "卖萌模式开启~",
            "可爱炸弹发射~",
            "萌力全开~",
            "超萌求关注~",
            "萌萌出击~",
            // 活泼呼唤型
            "主人主人主人~",
            "大声呼唤~",
            "主人快看这里~",
            "声音呼唤主人~",
            "主人听见了吗~",
            "呼唤主人快来~",
            "主人我在这~",
            "吸引主人注意~",
            "引起主人关注~",
            "主动接近主人~",
            // 温馨陪伴型
            "想陪主人~",
            "想要主人陪伴~",
            "靠近主人~",
            "想和主人在一起~",
            "寻求主人陪伴~",
            "陪伴心愿~",
            "希望主人陪我~",
            "等待主人互动~",
            "期待主人理我~",
            // 调皮捣蛋型
            "闹腾引起注意~",
            "调皮求理~",
            "捣蛋吸引主人~",
            "闹闹主人~",
            "搞怪求关注~",
            "调皮呼唤~"
        ]
    ]

    /// 拍拍互动吐槽语库
    private let patComments: [String] = [
        // 开心撒娇型
        "好舒服~",
        "谢谢主人拍拍~",
        "被拍了很开心~",
        "继续拍拍我~",
        "喜欢被拍拍~",
        "主人真好~",
        "摸摸头~",
        "蹭蹭主人~",
        "好温暖~",
        "开心开心~",
        // 可爱卖萌型
        "喵~（撒娇）",
        "蹭蹭~",
        "舒服得眯眼了~",
        "眯眼享受~",
        "享受中~",
        "被拍拍好幸福~",
        "主人爱我~",
        "撒娇撒娇~",
        "卖萌求继续拍~",
        "可爱地蹭蹭~",
        // 温馨感激型
        "谢谢主人的温柔~",
        "被主人关心了~",
        "主人的手好温暖~",
        "感受到主人的爱~",
        "被宠爱了~",
        "主人在乎我~",
        "温暖的心意~",
        "被抚摸的感觉真好~",
        "感谢主人的温柔拍拍~",
        "幸福地被拍拍~",
        // 调皮回应型
        "还要还要~",
        "多拍几下~",
        "再来一次~",
        "拍拍不够~",
        "求继续拍拍~",
        "还想被拍拍~",
        "别停别停~",
        "继续继续~",
        "拍拍上瘾了~",
        "拍拍瘾发作~"
    ]

    // MARK: - 触发概率配置

    /// 每个动作的触发概率（0.0-1.0）
    private let triggerProbabilities: [AnimationState: Float] = [
        .idle: 0.15,      // 站着时偶尔说话
        .running: 0.25,   // 跑动时容易触发
        .wakeup: 0.40,    // 醒来经常说话
        .sleeping: 0.08,  // 睡觉很少说话
        .eating: 0.35,    // 吃东西经常说话
        .fighting: 0.30   // 锻炼时偶尔说话
    ]

    /// 任务触发概率
    private let taskTriggerProbabilities: [PetTask: Float] = [
        .explore: 0.25,
        .seekAttention: 0.40
    ]

    /// 拍拍互动触发概率
    private let patTriggerProbability: Float = 0.60

    // MARK: - 冷却控制

    /// 动作吐槽冷却时间（秒）- 防止同一动作频繁触发
    private let actionCooldown: TimeInterval = 30.0

    /// 任务吐槽冷却时间
    private let taskCooldown: TimeInterval = 60.0

    /// 拍拍吐槽冷却时间
    private let patCooldown: TimeInterval = 5.0

    /// 上次触发时间
    private var lastActionTriggerTime: [AnimationState: Date] = [:]
    private var lastTaskTriggerTime: [PetTask: Date] = [:]
    private var lastPatTriggerTime: Date = Date.distantPast

    // MARK: - 依赖

    private let selfTalkManager = SelfTalkManager.shared

    // MARK: - 初始化

    private init() {}

    // MARK: - 动作吐槽触发

    /// 当动画状态变化时，检查是否触发吐槽
    func onAnimationStateChanged(_ newState: AnimationState, direction: MovementDirection? = nil) -> Bool {
        // 检查是否在冷却中
        if let lastTime = lastActionTriggerTime[newState] {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < actionCooldown {
                print("ActionComment: 动作\(newState)冷却中，剩余\(Int(actionCooldown - elapsed))秒")
                return false
            }
        }

        // 检查触发概率
        let probability = triggerProbabilities[newState] ?? 0.2
        let shouldTrigger = Float.random(in: 0...1) < probability

        if !shouldTrigger {
            print("ActionComment: 动作\(newState)概率未触发(\(probability))")
            return false
        }

        // 检查是否已在显示气泡
        if selfTalkManager.shouldShowBubble {
            print("ActionComment: 气泡已显示，跳过")
            return false
        }

        // 获取吐槽语并显示
        let comments = actionComments[newState] ?? ["动作触发~"]
        let comment = comments.randomElement() ?? "动起来啦~"

        print("ActionComment: 动作\(newState)触发吐槽: '\(comment)'")

        // 显示吐槽
        showActionComment(comment, action: newState)

        // 记录触发时间
        lastActionTriggerTime[newState] = Date()

        return true
    }

    /// 当任务开始时，检查是否触发吐槽
    func onTaskStarted(_ task: PetTask) -> Bool {
        // idle任务不触发
        if task == .idle {
            return false
        }

        // 检查冷却
        if let lastTime = lastTaskTriggerTime[task] {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < taskCooldown {
                print("ActionComment: 任务\(task)冷却中")
                return false
            }
        }

        // 检查概率
        let probability = taskTriggerProbabilities[task] ?? 0.2
        if Float.random(in: 0...1) >= probability {
            return false
        }

        // 检查气泡
        if selfTalkManager.shouldShowBubble {
            return false
        }

        // 获取吐槽
        let comments = taskComments[task] ?? ["出发啦~"]
        let comment = comments.randomElement() ?? "做任务啦~"

        print("ActionComment: 任务\(task)触发吐槽: '\(comment)'")

        showActionComment(comment, task: task)

        lastTaskTriggerTime[task] = Date()

        return true
    }

    /// 当精灵被拍拍时触发吐槽
    func onPetPatted() -> Bool {
        // 检查冷却
        let elapsed = Date().timeIntervalSince(lastPatTriggerTime)
        if elapsed < patCooldown {
            print("ActionComment: 拍拍冷却中，剩余\(Int(patCooldown - elapsed))秒")
            return false
        }

        // 检查概率
        if Float.random(in: 0...1) >= patTriggerProbability {
            return false
        }

        // 检查气泡
        if selfTalkManager.shouldShowBubble {
            return false
        }

        // 获取吐槽
        let comment = patComments.randomElement() ?? "好舒服~"

        print("ActionComment: 拍拍触发吐槽: '\(comment)'")

        // 使用统一接口显示气泡，不设置自定义隐藏时间
        selfTalkManager.showExternalBubble(text: comment)

        lastPatTriggerTime = Date()

        return true
    }

    // MARK: - 显示吐槽

    private func showActionComment(_ comment: String, action: AnimationState) {
        // 使用统一接口显示气泡，不设置自定义隐藏时间
        // 让气泡视图的流式动画自己控制消失
        selfTalkManager.showExternalBubble(text: comment)
    }

    private func showActionComment(_ comment: String, task: PetTask) {
        // 使用统一接口显示气泡，不设置自定义隐藏时间
        selfTalkManager.showExternalBubble(text: comment)
    }

    // MARK: - 统计接口

    /// 获取动作吐槽语库总数
    func getActionCommentCount(for action: AnimationState) -> Int {
        return actionComments[action]?.count ?? 0
    }

    /// 获取任务吐槽语库总数
    func getTaskCommentCount(for task: PetTask) -> Int {
        return taskComments[task]?.count ?? 0
    }

    /// 打印所有动作吐槽语库统计
    func printStatistics() {
        print("=== 动作吐槽语库统计 ===")
        for action in AnimationState.allCases {
            let count = getActionCommentCount(for: action)
            print("\(action.rawValue): \(count)条")
        }
        print("=== 任务吐槽语库统计 ===")
        for task in PetTask.allCases where task != .idle {
            let count = getTaskCommentCount(for: task)
            print("\(task.rawValue): \(count)条")
        }
    }
}