# AI公司总裁 — 游戏流程与代码架构文档

> **版本**: v0.3.0  
> **引擎**: UrhoX / SCE (Lua + NanoVG UI)  
> **架构**: C/S 多人模式 (persistent_world)，支持 LLM 驱动对话

---

## 一、游戏概述

**AI公司总裁** 是一款管理 + 多 Agent 对话模拟游戏。玩家扮演一家全员 AI 公司的唯一人类老板，通过一个类似飞书/钉钉的企业内网聊天界面，管理 AI 员工、接取订单、监控部门冲突，并做出关键决策。

### 核心玩法

- **角色**: 玩家是公司唯一的人类"老板"，所有员工都是 AI
- **界面**: 企业内网即时通讯 App（类 Slack/飞书）
- **目标**: 接取订单 → 管理 AI 部门协作完成 → 验收获得资金与声誉
- **乐趣**: 观察 AI 员工之间的争论、摸鱼、结盟等"自发行为"

---

## 二、完整游戏流程

### 2.1 启动阶段

```
游戏启动 (main.lua Start())
  ├─ 网络握手 (persistent_world 模式)
  │   ├─ 注册客户端远程事件 (Shared.RegisterClientEvents)
  │   ├─ 创建网络同步场景 (netScene_)
  │   └─ 绑定 serverConnection.scene
  ├─ UI 初始化 (UI.Init, 字体加载)
  ├─ AgentCaller 模式检测
  │   ├─ 有网络连接 + API 已配置 → "api" 模式 (LLM 驱动)
  │   └─ 否则 → "simulate" 模式 (预设对话模板)
  ├─ GameManager.Init() → 初始化所有子系统
  ├─ MainLayout.Create() → 构建聊天界面
  ├─ GameManager.StartGame() → 开始第 1 天
  └─ 发送 CLIENT_READY 给服务端完成握手
```

### 2.2 日程循环

每个游戏日持续 **90 秒**（`DAY_DURATION`，对齐 GDD 约 60～90 秒），分为 4 个时段：

| 时段 | 区间 | 说明 |
|------|------|------|
| 上午 | 0% ~ 30% | 部门问候、新订单刷新 |
| 下午 | 30% ~ 60% | 工作流主要推进 |
| 傍晚 | 60% ~ 85% | 审查与冲突高发期 |
| 夜间 | 85% ~ 100% | 结算，进入下一天 |

**每天开始时**：
1. 刷新 2~4 个可接取订单 (`OrderManager.RefreshDailyOrders`)
2. 全局公告："第 N 天开始了！"
3. 各部门发送问候消息（延迟随机错开）
4. 已解锁的私下频道生成新对话内容
5. 刷新信息面板和频道列表

**每天结束时**：
1. 技能冷却 -1 天
2. 工部满载天数统计（触发私下频道解锁条件）
3. 全局公告："第 N 天结束了"
4. 自动进入下一天

### 2.3 订单工作流（核心玩法）

订单是游戏的核心驱动。完整流程：

```
可接取 (available)
  │
  ├─ 玩家点击"接取" ──→ 已接取 (accepted)
  │
  ▼
阶段1: 接单与需求分析 (accept, 12秒)
  ├─ 中书省: 分析需求、拆解任务
  ├─ 工部: 确认排期
  └─ 门下省: 提醒合规风险
  │
  ▼
阶段2: 执行与产出 (execute, 18秒)
  ├─ 工部: 生产交付物（内容创作）
  ├─ 门下省: 同步审查
  └─ 工部私下频道: 可能吐槽工作量
  │
  ▼
阶段3: 审查与冲突 (review, 14秒)
  ├─ 50% 概率: 通过 → 直接进入验收
  ├─ 30% 概率: 打回 → 工部修改后重新提交
  └─ 20% 概率: 冲突 → 工部与门下省争论
      └─ 玩家可使用"强制拍板"技能跳过
  │
  ▼
阶段4: 验收 (acceptance, 10秒)
  ├─ 验收官 AI 打分 (40~95分)
  ├─ ≥80分: 高品质通过，收入 ×1.2，声誉 +1
  ├─ 60~79分: 及格通过，正常收入
  └─ <60分: 验收未通过，无收入，声誉 -1
  │
  ▼
阶段5: 结算 (settlement)
  ├─ 发放奖励 / 扣减声誉
  ├─ 释放部门工作量
  └─ 全局公告结算信息
```

### 2.4 订单类型

| 类型 | 标签 | 特点 | 奖励范围 |
|------|------|------|---------|
| hotspot | 🔥 热点速攻 | 时效性强，需快速迭代 | ¥4,000 ~ ¥17,000 |
| brand | 💎 品牌策划 | 深度分析，调性把控 | ¥18,000 ~ ¥32,000 |
| app | 📱 应用开发 | 技术可行性，功能完整 | ¥13,000 ~ ¥24,000 |
| mystery | ❓ 神秘订单 | 需求模糊，高风险高回报 | ¥33,000 ~ ¥52,000 |

### 2.5 老板技能系统

玩家可使用 4 个主动技能影响公司运作：

| 技能 | 图标 | 效果 | 冷却 | 费用 |
|------|------|------|------|------|
| 强制拍板 | ⚡ | 跳过部门争论，直接推进执行 | 1 天 | 风险备案 |
| 暂停发布 | ⏸ | 阻止一次即将对外的高风险动作 | 2 天 | 无 |
| 紧急重组架构 | 🔄 | 立即改变两个部门间的汇报关系 | 3 天 | ¥5,000 |
| 临时外包 | 📎 | 召唤短期外援协助当前订单（提升交付质量） | 0 天 | ¥8,000 (限3次) |

### 2.6 私下频道（隐藏内容）

当特定条件达成时，玩家会解锁 AI 员工的"私下频道"，窥探他们背着老板说的话：

| 频道名 | 图标 | 解锁条件 |
|--------|------|---------|
| 工部摸鱼小群 | 👀 | 工部连续 3 天高压（工作量 ≥ 约 45% 满载阈值） |
| 蛐蛐老板实名群 | 🤪 | 老板强制拍板 3 次 |
| 工部门下省秘密结盟 | 🤝 | 两部门冲突超过 5 次 |

私下频道为**只读**，老板不能发言，只能"旁观"。内容**懒加载**：每日首次点进该频道时才生成并推送（省 API）。

### 2.7 经济系统

- **初始资金**: ¥50,000
- **初始声誉**: 3 星 (最高 5 星)
- **收入来源**: 完成订单获得奖励（高品质 ×1.2 加成）
- **支出**: 使用部分技能需要消耗资金
- **声誉变化**: 高品质完成 +1，验收失败 -1

---

## 三、频道系统

### 3.1 频道列表

游戏中的所有对话通过"频道"组织，模拟企业通讯工具：

| 频道 ID | 频道名 | 类型 | 说明 |
|---------|--------|------|------|
| global | 全局公告 | public | 系统通知、日终结算 |
| workflow | 工作流 | workflow | 订单执行的主要工作对话 |
| dept_zhongshu | 中书省 | public | 中书省内部频道 |
| dept_gongbu | 工部 | public | 工部内部频道 |
| dept_menxia | 门下省 | public | 门下省内部频道 |
| secret_slacking | 工部摸鱼小群 | secret | 隐藏频道（条件解锁） |
| secret_boss_gossip | 蛐蛐老板实名群 | secret | 隐藏频道（条件解锁） |
| secret_alliance | 工部门下省秘密结盟 | secret | 隐藏频道（条件解锁） |

### 3.2 消息类型

- **系统消息**: 日程通知、订单状态变化、技能使用反馈
- **部门消息**: AI 员工的工作对话（按部门着色区分）
- **老板消息**: 玩家输入的指令/发言（暖橙色气泡）

---

## 四、AI 对话系统

### 4.1 双模式架构

游戏支持两种 AI 对话生成模式：

| 模式 | 触发条件 | 实现方式 |
|------|---------|---------|
| **simulate** | 默认（无网络或 API 未配置） | 从 `DialoguePool` 预设模板随机选取 |
| **api** | 有网络 + LLM API 已配置 | 通过 RemoteEvent → 服务端 HTTP → LLM API |

### 4.2 API 模式数据流

```
客户端 AgentCaller
  │  构建 prompt（含可选「频道摘要」；验收官附 JSON 约束）
  │  发送 RemoteEvent: C2S_LLM_REQUEST
  ▼
服务端 Server.lua
  │  收到请求 → 调用 HTTP API (火山引擎/百炼等)
  │  解析 JSON 响应 → 提取 content
  │  发送 RemoteEvent: S2C_LLM_RESPONSE
  ▼
客户端 AgentCaller
  │  收到回复 → 验收阶段可解析 JSON 覆盖分数 → 推送到对应频道
  │  失败时用模拟回复兜底
  ▼
ChannelManager → ChatPanel UI 更新
```

### 4.3 部门 AI 角色设定

| 部门 | 角色 | 性格标签 | 典型行为 |
|------|------|---------|---------|
| 中书省 | 策划/方案 AI | 过度思考 | 详尽方案、列 1234、偶尔吐槽工部 |
| 工部 | 内容/执行 AI | 爱甩锅 | 务实肯干、偶尔抱怨、私下吐槽门下省 |
| 门下省 | 审查/质检 AI | 懂合规 | 严格挑剔、打回方案、被强制放行时备案 |
| 验收官 | 客户 Agent | 极度自信 | 扮演甲方、不受老板控制、有独立评判标准 |

### 4.4 事故/奇观系统（预设）

当特定条件组合出现时，可能触发有趣的"事故"：

- **审批循环**: 中书省和门下省审批意见互相矛盾，进入死循环
- **质检熔断**: 门下省权限过高，所有内容被打回，工部停摆
- **中书省越权**: 中书省未经老板同意私自调整执行方向
- **热点过期**: 审批还没完成，热点已经过时了

---

## 五、代码模块架构

### 5.1 目录结构

```
scripts/
├── main.lua                     # 入口文件
├── config/
│   ├── GameConfig.lua           # 全局配置常量
│   └── LLMConfig.lua            # LLM API 配置
├── core/
│   ├── EventBus.lua             # 事件总线
│   └── GameManager.lua          # 游戏主循环
├── agent/
│   ├── AgentCaller.lua          # AI 调用接口
│   ├── AcceptanceAgent.lua      # 验收 JSON 解析与提示片段
│   ├── AgentProfiles.lua        # 部门角色设定
│   └── DialoguePool.lua         # 预设对话模板库
├── systems/
│   ├── ChannelManager.lua       # 频道与消息管理
│   ├── OrderManager.lua         # 订单生命周期管理
│   ├── OrgGenerator.lua         # 组织架构生成器
│   ├── BossSkillSystem.lua      # 老板技能系统
│   ├── SecretChannelSystem.lua  # 私下频道触发与懒加载生成
│   ├── EventSystem.lua          # 事故触发（订阅订单/消息）
│   └── ShareCardSystem.lua      # 日结战报文本（分享卡 MVP）
├── network/
│   ├── Shared.lua               # 远程事件名定义
│   └── Server.lua               # 服务端 LLM 代理
└── ui/
    ├── MainLayout.lua           # 主布局框架
    ├── StatusBar.lua            # 顶部状态栏
    ├── ChatPanel.lua            # 聊天面板
    ├── ChannelListPanel.lua     # 频道列表面板
    ├── InfoPanel.lua            # 指挥中心面板
    └── OrderQuickPanel.lua      # 首页订单快捷面板
```

### 5.2 模块职责详解

#### 入口层

| 模块 | 文件 | 职责 |
|------|------|------|
| **main.lua** | `scripts/main.lua` | 引擎入口，区分客户端/服务端模式，初始化 UI 和游戏系统，注册 Update 循环 |

#### 配置层 (`config/`)

| 模块 | 文件 | 职责 |
|------|------|------|
| **GameConfig** | `config/GameConfig.lua` | 全局常量：时间系统、经济参数、UI 配色、部门视觉配置、技能定义、私下频道条件 |
| **LLMConfig** | `config/LLMConfig.lua` | LLM API 连接参数：URL、Key、模型ID、System Prompt 模板 |

#### 核心层 (`core/`)

| 模块 | 文件 | 职责 |
|------|------|------|
| **EventBus** | `core/EventBus.lua` | 轻量级发布-订阅事件总线，定义 40+ 事件常量，解耦所有模块间通信 |
| **GameManager** | `core/GameManager.lua` | 游戏主循环：日程推进(时段切换)、消息队列调度、订单工作流状态机、老板操作处理 |

#### AI 层 (`agent/`)

| 模块 | 文件 | 职责 |
|------|------|------|
| **AgentCaller** | `agent/AgentCaller.lua` | AI 调用：模拟 / API；审查骰子受组织原型与今日策略影响；API 附带频道摘要 |
| **AcceptanceAgent** | `agent/AcceptanceAgent.lua` | 验收官回复中的 `passed/score` JSON 解析，供覆盖模拟结算 |
| **AgentProfiles** | `agent/AgentProfiles.lua` | 4 个部门的角色设定：名称、职能、性格标签、短语库(问候/工作/冲突/私下) |
| **DialoguePool** | `agent/DialoguePool.lua` | 预设对话模板：按工作流阶段(接单/执行/审查/验收/结算) × 订单类型组织，含私下频道和事故对话 |

#### 系统层 (`systems/`)

| 模块 | 文件 | 职责 |
|------|------|------|
| **ChannelManager** | `systems/ChannelManager.lua` | 频道 CRUD、消息推送、未读计数、频道切换、私下频道解锁 |
| **OrderManager** | `systems/OrderManager.lua` | 订单模板库、每日刷新、接取/推进/完成/失败状态流转、统计 |
| **OrgGenerator** | `systems/OrgGenerator.lua` | 4 种组织原型(通用/三省六部/扁平/蜂巢)、部门工作量追踪 |
| **BossSkillSystem** | `systems/BossSkillSystem.lua` | 技能冷却/使用次数/资金消耗管理、强制拍板计数(触发私下频道) |
| **SecretChannelSystem** | `systems/SecretChannelSystem.lua` | 解锁检测（高压天数/拍板/冲突）、私下内容懒加载 |
| **EventSystem** | `systems/EventSystem.lua` | 低概率触发 `DialoguePool.INCIDENTS` 事故对话 |
| **ShareCardSystem** | `systems/ShareCardSystem.lua` | 日结束时向全局频道推送文本战报 |

#### 网络层 (`network/`)

| 模块 | 文件 | 职责 |
|------|------|------|
| **Shared** | `network/Shared.lua` | 远程事件名称常量定义、客户端/服务端事件注册 |
| **Server** | `network/Server.lua` | 服务端 LLM 代理：接收客户端请求 → 调用 HTTP API → 返回结果/错误，含未配置时的模拟回复 |

#### UI 层 (`ui/`)

| 模块 | 文件 | 职责 |
|------|------|------|
| **MainLayout** | `ui/MainLayout.lua` | StatusBar + 主列（Tab：消息/工作台/指挥/财务）+ 输入栏；消息页全高聊天+右侧条；工作台含订单与今日策略；频道列表 Overlay |
| **StatusBar** | `ui/StatusBar.lua` | 顶栏：公司名、Boss、今日策略 chip、声誉/资金、警报 |
| **ChatPanel** | `ui/ChatPanel.lua` | 聊天面板：频道标题栏、警告横幅、ChatWindow 消息渲染、消息格式转换 |
| **ChannelListPanel** | `ui/ChannelListPanel.lua` | 频道列表(overlay)：公开/私下频道分组、未读红点、最后消息预览 |
| **InfoPanel** | `ui/InfoPanel.lua` | 指挥中心面板：老板技能卡片 + 部门状态列表 |
| **OrderQuickPanel** | `ui/OrderQuickPanel.lua` | 「工作台」Tab 内订单列表：可接取卡片 + 进行中进度 |

### 5.3 模块依赖关系

```
main.lua
  ├── GameConfig (配置)
  ├── EventBus (事件)
  ├── GameManager (核心主循环)
  │     ├── ChannelManager
  │     ├── OrgGenerator
  │     ├── OrderManager
  │     ├── BossSkillSystem
  │     ├── SecretChannelSystem
  │     ├── EventSystem
  │     ├── ShareCardSystem
  │     └── AgentCaller
  │           ├── AgentProfiles
  │           ├── DialoguePool
  │           └── LLMConfig
  ├── MainLayout (UI 根)
  │     ├── StatusBar
  │     ├── ChatPanel / OrderQuickPanel / InfoPanel（Tab 切换）
  │     └── ChannelListPanel（Overlay）
  └── Shared (网络事件)
```

### 5.4 事件总线 (EventBus) — 事件清单

所有模块间通信通过事件总线解耦，共定义以下事件：

| 分类 | 事件名 | 触发时机 |
|------|--------|---------|
| **游戏流程** | `game:start` | 游戏启动 |
| | `game:day_start` | 新的一天开始 |
| | `game:day_end` | 一天结束 |
| | `game:phase_change` | 时段切换(上午/下午/傍晚/夜间) |
| **频道消息** | `channel:message_new` | 新消息推送到频道 |
| | `channel:created` | 新频道创建 |
| | `channel:switch` | 切换查看的频道 |
| | `channel:unlocked` | 私下频道解锁 |
| **订单** | `order:new` | 新订单生成 |
| | `order:accepted` | 订单被接取 |
| | `order:progress` | 订单状态推进 |
| | `order:submitted` | 订单提交验收 |
| | `order:result` | 验收结果 |
| | `workflow:acceptance_parsed` | API 验收 JSON 解析完成 |
| **老板操作** | `boss:message` | 老板发言 |
| | `boss:skill_used` | 技能已使用 |
| | `boss:skill_ready` | 技能冷却完毕 |
| **组织** | `org:created` | 组织架构生成 |
| | `org:restructured` | 组织重组 |
| **事故** | `incident:trigger` | 触发奇观/事故对话链 |
| **经济** | `economy:funds_changed` | 资金变化 |
| | `economy:reputation_changed` | 声誉变化 |
| **私下频道** | `secret:unlocked` | 私下频道解锁 |
| | `secret:message` | 私下频道新消息 |
| | `secret:channel_opened` | 玩家切换到某私下频道（懒加载） |
| **UI** | `ui:refresh` | 通用 UI 刷新 |
| | `ui:toast` | 显示提示 |
| | `ui:tab_switch` | 标签页切换 |
| **导航** | `nav:open_channels` | 打开频道列表 |
| | `nav:open_overlay` | 打开覆盖层 |
| | `nav:close_overlay` | 关闭覆盖层 |

---

## 六、UI 布局结构

### 6.1 主界面布局

```
┌──────────────────────────────────────────┐
│  StatusBar — 公司名 · Boss · 今日策略 · 资金/声誉      │
├──────────────────────────────────────────┤
│  Tab 内容区（消息=全高 Chat + 右侧会话条；工作台=订单+策略）│
├──────────────────────────────────────────┤
│  TabBar — 消息 │ 工作台 │ 指挥 │ 财务                    │
├──────────────────────────────────────────┤
│  InputBar — 「消息」页可发言；私下频道占位提示仅可旁观      │
└──────────────────────────────────────────┘
```

### 6.2 Overlay 覆盖层机制

UI 库的 `SetVisible(false)` 不影响 Yoga 布局，因此采用 **RemoveChild / AddChild** 方式切换视图：

- **ContentArea** 默认子视图为「主列」（Tab 区 + 底栏 Tab）；打开频道列表 Overlay 时整列 swap 为全屏列表
- **指挥中心 / 财务** 为主 Tab 内嵌页面，不再单独 Overlay（减少层级）

可用的 Overlay：
- **频道列表** (← 返回 + 分组会话列表)

### 6.3 配色方案

采用**浅色企业内网主题**（暖橙色主调）：

- 主背景: 纯白 `#FFFFFF`
- 次要背景: 浅灰 `#F8F8FA`
- 主调色: 暖橙 `#D28232`
- 老板消息气泡: 暖橙 `#D28737`
- 他人消息气泡: 浅灰 `#EEEEF2`
- 主文字: 深黑 `#232328`

---

## 七、组织架构系统

游戏支持 4 种组织原型（目前默认使用"通用公司制"）：

| 原型 | 图标 | 审查强度 | 执行速度 | 冲突率 | 适合订单 |
|------|------|---------|---------|--------|---------|
| 通用公司制 | 🏢 | 0.5 | 0.5 | 0.2 | 均衡型 |
| 三省六部制 | 🏛️ | 0.9 | 0.3 | 0.4 | 高风险/高价值 |
| 扁平快反制 | ⚡ | 0.2 | 0.9 | 0.1 | 热点速攻 |
| 蜂巢并行制 | 🐝 | 0.4 | 0.7 | 0.5 | 大批量内容 |

---

## 八、网络架构

### 8.1 C/S 模式 (persistent_world)

- **服务端**: 常驻运行，负责 LLM API 调用代理
- **客户端**: 玩家端，处理游戏逻辑和 UI 渲染
- **握手流程**: 客户端连接 → 发送 CLIENT_READY → 服务端分配 scene

### 8.2 远程事件

| 事件名 | 方向 | 用途 |
|--------|------|------|
| `CLIENT_READY` | C → S | 客户端准备就绪握手 |
| `C2S_LlmRequest` | C → S | 请求 LLM 生成对话 |
| `S2C_LlmResponse` | S → C | 返回 LLM 生成结果 |
| `S2C_LlmError` | S → C | 返回错误信息 |

### 8.3 LLM 配置

支持国内主流大模型 API：
- **火山引擎 (豆包)**: `doubao-1.5-pro-32k`
- **百炼 (通义千问)**: `qwen-plus`

配置文件: `config/LLMConfig.lua`（含 API URL、Key、模型 ID、System Prompt）

---

## 九、扩展与开发指南

### 9.1 添加新订单类型

1. 在 `GameConfig.ORDER_TYPES` 中添加类型名
2. 在 `OrderManager.lua` 的 `ORDER_TEMPLATES` 中添加订单模板
3. 在 `DialoguePool.lua` 中为新类型添加各阶段对话模板
4. 在 `OrderManager.GetOrderTypeLabel` 中添加标签映射

### 9.2 添加新部门

1. 在 `AgentProfiles.DEPARTMENTS` 中定义部门配置
2. 在 `GameConfig` 中添加 `DEPT_ICONS`、`DEPT_BADGE_COLORS`、`DEPT_SHORT`、`DEPT_NAMES`
3. 在 `ChannelManager.Init()` 中创建部门频道
4. 在 `LLMConfig.DEPT_PROMPTS` 中添加 System Prompt

### 9.3 添加新技能

1. 在 `GameConfig.SKILLS` 中定义技能配置
2. 在 `GameConfig.SKILL_ORDER` 中添加显示顺序
3. 在 `GameManager._registerEvents()` 中添加技能效果处理逻辑

### 9.4 添加新私下频道

1. 在 `GameConfig.SECRET_CHANNELS` 中定义频道及解锁条件
2. 在 `SecretChannelSystem.CheckUnlocks()` 中添加条件检测逻辑
3. 在 `DialoguePool.SECRET` 中添加对话内容

---

*文档生成日期: 2026-04-13*
