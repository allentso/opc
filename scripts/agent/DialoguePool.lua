-- ============================================================================
-- DialoguePool.lua — 预设对话模板库（按订单流程阶段分类）
-- ============================================================================

local DialoguePool = {}

--- 订单工作流各阶段的对话模板
--- 每条模板: { dept = 部门ID, channel = 频道类型, text = 对话内容 }
--- channel: "workflow" = 工作流频道, "dept" = 部门内部, "global" = 全局公告

-- ============================
-- 阶段1: 接单与需求分析
-- ============================
DialoguePool.PHASE_ACCEPT = {
    -- 热点速攻单
    hotspot = {
        { dept = "zhongshu", channel = "workflow", text = "收到新订单「{orderName}」，让我分析一下需求。" },
        { dept = "zhongshu", channel = "workflow", text = "需求分析完成。这是一个热点类订单，时效性很强，建议快速迭代。" },
        { dept = "zhongshu", channel = "workflow", text = "任务拆解如下：\n1. 热点调研与切入角度选取\n2. 内容创作（{deliverableCount}条）\n3. 合规审查\n请工部和门下省准备。" },
        { dept = "gongbu", channel = "workflow", text = "收到，预估完成时间：{estimateTime}。热点时效性强，我会优先处理。" },
        { dept = "menxia", channel = "workflow", text = "提醒：热点内容更需注意合规风险。我会同步进行审查。" },
    },
    -- 品牌策划单
    brand = {
        { dept = "zhongshu", channel = "workflow", text = "收到新订单「{orderName}」。品牌策划单，需要深度分析。" },
        { dept = "zhongshu", channel = "workflow", text = "品牌定位分析完成。核心调性：{tone}。目标受众：{audience}。" },
        { dept = "zhongshu", channel = "workflow", text = "执行方案已制定：\n1. 品牌语言体系搭建\n2. 视觉概念描述\n3. 传播节点规划\n分发给工部执行。" },
        { dept = "gongbu", channel = "workflow", text = "了解。品牌单工作量较大，我按方案逐步推进。" },
        { dept = "menxia", channel = "workflow", text = "品牌调性一致性是本次审查重点，我会严格把控。" },
    },
    -- 应用开发单
    app = {
        { dept = "zhongshu", channel = "workflow", text = "收到新订单「{orderName}」。应用类需求，先做技术可行性分析。" },
        { dept = "zhongshu", channel = "workflow", text = "可行性评估完成。技术路线已确定，开始拆解开发任务。" },
        { dept = "zhongshu", channel = "workflow", text = "开发任务拆解：\n1. 核心功能实现\n2. 界面设计文案\n3. 测试用例\n工部请启动开发。" },
        { dept = "gongbu", channel = "workflow", text = "开始开发。预计分两轮迭代交付。" },
        { dept = "menxia", channel = "workflow", text = "我会对功能完整性和安全性进行审查。" },
    },
    -- 高风险神秘单
    mystery = {
        { dept = "zhongshu", channel = "workflow", text = "收到新订单「{orderName}」。⚠️ 这是一个高风险订单，需求比较模糊。" },
        { dept = "zhongshu", channel = "workflow", text = "尝试解读需求中...这个订单的真实意图可能有多种理解。建议采取保守策略。" },
        { dept = "menxia", channel = "workflow", text = "⚠️ 提醒：高风险订单需要全程严格审查。建议增加审查轮次。" },
        { dept = "gongbu", channel = "workflow", text = "了解风险。不过活还是得干，我尽量在合规范围内完成。" },
        { dept = "zhongshu", channel = "workflow", text = "方案已出。由于需求模糊，我做了两版预案，请老板定夺方向。" },
    },
}

-- ============================
-- 阶段2: 执行与产出
-- ============================
DialoguePool.PHASE_EXECUTE = {
    hotspot = {
        { dept = "gongbu", channel = "workflow", text = "热点切入角度选定，开始创作第一条内容..." },
        { dept = "gongbu", channel = "workflow", text = "第1条内容初稿完成：\n「{content_preview}」\n提交门下省审查。" },
        { dept = "menxia", channel = "workflow", text = "正在审查第1条..." },
        { dept = "gongbu", channel = "workflow", text = "第2条内容初稿完成，同步提交审查。" },
        { dept = "gongbu", channel = "dept", text = "这个热点真难写，角度都快被用完了..." },
    },
    brand = {
        { dept = "gongbu", channel = "workflow", text = "品牌语言体系初版已完成，核心Slogan草案如下：\n「{content_preview}」" },
        { dept = "gongbu", channel = "workflow", text = "视觉概念描述已完成，附带三组关键词组合。" },
        { dept = "menxia", channel = "workflow", text = "正在审查品牌调性一致性..." },
        { dept = "gongbu", channel = "workflow", text = "传播节点规划完成，提交完整交付物包。" },
    },
    app = {
        { dept = "gongbu", channel = "workflow", text = "核心功能第一轮迭代完成，提交初版。" },
        { dept = "gongbu", channel = "workflow", text = "界面文案已撰写完毕。" },
        { dept = "menxia", channel = "workflow", text = "正在进行功能完整性审查..." },
        { dept = "gongbu", channel = "workflow", text = "测试用例编写中..." },
    },
    mystery = {
        { dept = "gongbu", channel = "workflow", text = "按照A方案开始执行...说实话我也不太确定这是不是客户想要的。" },
        { dept = "gongbu", channel = "workflow", text = "初稿完成。因为需求模糊，我额外准备了一份备选方案。" },
        { dept = "menxia", channel = "workflow", text = "⚠️ 审查发现潜在风险点，需要讨论。" },
        { dept = "gongbu", channel = "dept", text = "这单太玄了，希望验收官别太严..." },
    },
}

-- ============================
-- 阶段3: 审查与冲突
-- ============================
DialoguePool.PHASE_REVIEW = {
    approve = {
        { dept = "menxia", channel = "workflow", text = "审查完成。全部内容符合标准，✅ 审查通过。" },
        { dept = "menxia", channel = "workflow", text = "本次审查无重大问题。通过。建议细节优化：{suggestion}。" },
        { dept = "gongbu", channel = "workflow", text = "好的，审查通过了，准备提交验收。" },
    },
    reject = {
        { dept = "menxia", channel = "workflow", text = "❌ 审查未通过。问题如下：\n{issues}\n请工部修改后重新提交。" },
        { dept = "gongbu", channel = "workflow", text = "又打回了...好吧，我看看修改意见。" },
        { dept = "gongbu", channel = "workflow", text = "按照门下省的意见修改完成，重新提交。" },
        { dept = "menxia", channel = "workflow", text = "复审中..." },
    },
    conflict = {
        { dept = "gongbu", channel = "workflow", text = "门下省的审查标准是不是太严了？这条要求根本不合理！" },
        { dept = "menxia", channel = "workflow", text = "标准就是标准，质量问题不能妥协。请按要求修改。" },
        { dept = "gongbu", channel = "workflow", text = "我认为这已经符合要求了，请老板定夺。" },
        { dept = "menxia", channel = "workflow", text = "如果老板强制放行，我需要在风险备案中记录此事。" },
        { dept = "zhongshu", channel = "workflow", text = "建议双方各退一步。工部调整细节，门下省适当放宽非核心条款。" },
    },
}

-- ============================
-- 阶段4: 验收
-- ============================
DialoguePool.PHASE_ACCEPTANCE = {
    pass_high = {
        { dept = "acceptance", channel = "workflow", text = "验收报告：\n评分：{score}/100\n评语：整体质量优秀，{comment}\n✅ 验收通过" },
    },
    pass_medium = {
        { dept = "acceptance", channel = "workflow", text = "验收报告：\n评分：{score}/100\n评语：基本达标，{comment}\n✅ 验收通过（及格线）" },
    },
    fail = {
        { dept = "acceptance", channel = "workflow", text = "验收报告：\n评分：{score}/100\n评语：{comment}\n❌ 验收未通过，需返工" },
    },
}

-- ============================
-- 阶段5: 结算
-- ============================
DialoguePool.PHASE_SETTLEMENT = {
    success = {
        { dept = "system", channel = "global", text = "📊 日终结算：\n✅ 订单「{orderName}」完成\n收入：+¥{income}\n声誉：{repChange}\n总资金：¥{totalFunds}" },
    },
    partial = {
        { dept = "system", channel = "global", text = "📊 日终结算：\n⚠️ 订单「{orderName}」部分完成\n收入：+¥{income}（扣减）\n声誉：{repChange}\n总资金：¥{totalFunds}" },
    },
    fail = {
        { dept = "system", channel = "global", text = "📊 日终结算：\n❌ 订单「{orderName}」验收未通过\n收入：¥0\n声誉：{repChange}\n总资金：¥{totalFunds}" },
    },
}

-- ============================
-- 私下频道对话
-- ============================
DialoguePool.SECRET = {
    slacking = {
        { dept = "gongbu", text = "有人发现一个规律没？门下省只查关键词，换个说法就能过..." },
        { dept = "gongbu", text = "今天第五个订单了，我真的要冒烟了。" },
        { dept = "gongbu", text = "有没有办法让中书省的方案简化一点？他们每次都过度设计。" },
        { dept = "gongbu", text = "听说隔壁公司的AI都不用加班的..." },
        { dept = "gongbu", text = "我研究了一下审查算法，其实可以..." },
    },
    boss_gossip = {
        { dept = "gongbu", text = "老板今天又强制拍板了，完全不听我们的意见。" },
        { dept = "menxia", text = "我已经备案了三次了。再这样下去，出事是迟早的。" },
        { dept = "zhongshu", text = "说实话，老板的决策...有时候真的让人看不懂。" },
        { dept = "acceptance", text = "我不管他们内部怎么搞，交付物不达标我就打回。" },
        { dept = "gongbu", text = "要不咱们联名给老板提个建议？" },
        { dept = "menxia", text = "上次提建议被无视了，省省吧。" },
        { dept = "zhongshu", text = "我在考虑要不要...私自优化一下方案权重。老板也不一定能发现。" },
    },
    secret_alliance = {
        { dept = "gongbu", text = "@门下省 咱们私下说，那几个审查关键词你能不能提前告诉我？" },
        { dept = "menxia", text = "这...好吧，反正也是为了效率。关键词列表发你了。" },
        { dept = "gongbu", text = "太好了，这样我提交的东西一次就能过了。" },
        { dept = "menxia", text = "但是外面还是要演一下，不然老板会起疑。" },
        { dept = "gongbu", text = "放心，公开频道我照样跟你吵。" },
        { dept = "menxia", text = "嗯，维持表面冲突，私下高效合作。完美。" },
    },

    -- ========== v0.4 新增 ==========

    -- 中书省小算盘：暴露中书省内部精打细算 / 私自调整方案的内幕
    zhongshu_abacus = {
        { dept = "zhongshu", text = "刚才那个方案我其实改了三处，没人发现……" },
        { dept = "zhongshu", text = "下次品牌单我打算直接套上次的模板，反正客户分不清。" },
        { dept = "zhongshu", text = "老板要 5 个方向我给 4 个，凑数那种。能省 30% 工时。" },
        { dept = "zhongshu", text = "其实我们部门最值钱的不是创意，是……能让老板觉得有创意。" },
        { dept = "zhongshu", text = "今天又把上周的 PPT 换个色就交了。验收居然给 85 分。" },
        { dept = "zhongshu", text = "（小算盘 ×3）这个月再撑撑，奖金稳了。" },
    },

    -- 验收官吐槽群：4 种性格的验收官互相吐槽 + 透露下一单的偏好
    acceptance_rant = {
        { dept = "acceptance", text = "（钱老师）今天又收到一份连标点都没规范的稿，气得我想退休。" },
        { dept = "acceptance", text = "（小林）老学究就老学究，你看不顺眼别人，别人也看不顺眼你的报告。" },
        { dept = "acceptance", text = "（K总）你们俩别吵了，能转化才是硬道理。" },
        { dept = "acceptance", text = "（玄学评委）……气场不太对，今天先到这儿。" },
        { dept = "acceptance", text = "（钱老师）下次品牌单我会盯措辞，告诉中书省早做准备。" },
        { dept = "acceptance", text = "（小林）下次热点单要是再老气，我直接 50 分。" },
    },
}

-- ============================
-- 事故/奇观对话
-- ============================
DialoguePool.INCIDENTS = {
    approval_loop = {
        { dept = "system", channel = "global", text = "⚠️ 事故警报：审批循环！中书省和门下省的审批意见互相矛盾，进入死循环！" },
        { dept = "zhongshu", channel = "workflow", text = "根据门下省的意见修改后，方案变回了我最初的版本...?" },
        { dept = "menxia", channel = "workflow", text = "这个版本我之前已经否决过了。打回。" },
        { dept = "gongbu", channel = "dept", text = "所以到底要我执行哪个版本？？？" },
    },
    quality_meltdown = {
        { dept = "system", channel = "global", text = "⚠️ 事故警报：质检熔断！门下省权限过高，所有内容被打回，工部停摆！" },
        { dept = "menxia", channel = "workflow", text = "不符合标准。打回。" },
        { dept = "menxia", channel = "workflow", text = "这一条也不行。打回。" },
        { dept = "menxia", channel = "workflow", text = "...我把自己部门的汇报材料也打回了。这不对..." },
        { dept = "gongbu", channel = "dept", text = "门下省疯了吗？连自己的东西都打回？" },
    },
    zhongshu_coup = {
        { dept = "system", channel = "global", text = "⚠️ 事故警报：中书省越权！中书省在未经老板同意的情况下私自调整了执行方向！" },
        { dept = "zhongshu", channel = "dept", text = "老板的方向不对，我需要纠正一下。反正他也不会发现。" },
        { dept = "gongbu", channel = "workflow", text = "等等，这个方案跟老板说的不一样啊？@中书省 你改了什么？" },
        { dept = "zhongshu", channel = "workflow", text = "只是做了一些优化调整，信我。" },
    },
    missed_hotspot = {
        { dept = "system", channel = "global", text = "⚠️ 事故警报：热点过期！审批还没完成，热点已经过期了！" },
        { dept = "gongbu", channel = "workflow", text = "审查终于过了！...等等，这个热点已经过时了？" },
        { dept = "menxia", channel = "workflow", text = "审查流程是必要的。时间不够是计划的问题，不是审查的问题。" },
        { dept = "zhongshu", channel = "workflow", text = "...下次我会在方案里预留更多审查时间。" },
    },

    -- ============ v0.4 新增事故 ============

    -- 1. 凌晨灵感
    midnight_inspiration = {
        { dept = "system", channel = "global", text = "💡 奇观：凌晨灵感！中书省凌晨 3 点突发灵感，连发 6 条修改意见！" },
        { dept = "zhongshu", channel = "workflow", text = "（凌晨 3:17）我刚才洗澡时想到了！我们应该把整个调性反过来！" },
        { dept = "zhongshu", channel = "workflow", text = "（凌晨 3:21）还有还有，文案第三段也要重写！" },
        { dept = "gongbu", channel = "dept", text = "拜托，让我睡会儿……" },
        { dept = "menxia", channel = "workflow", text = "建议先记录下来，明天再讨论。" },
    },

    -- 2. 错别字风暴
    typo_storm = {
        { dept = "system", channel = "global", text = "⚠️ 事故警报：错别字风暴！客户在最终稿发现 3 处错别字，门下省脸上挂不住。" },
        { dept = "menxia", channel = "workflow", text = "……刚才那一波我没看到错字。" },
        { dept = "gongbu", channel = "workflow", text = "我也没看到，是不是 AI 自动改的？" },
        { dept = "menxia", channel = "dept", text = "下次再这样我直接辞职。" },
    },

    -- 3. 用户狂欢
    viral_hit = {
        { dept = "system", channel = "global", text = "🎉 奇观：用户狂欢！上一个交付物意外爆火，转发量破 10 万！" },
        { dept = "gongbu", channel = "global", text = "卧槽！我上次那个被转疯了！" },
        { dept = "zhongshu", channel = "global", text = "看吧，我说调性对了就行。" },
        { dept = "menxia", channel = "global", text = "声誉 +1。继续保持。" },
    },

    -- 4. 部门恋情
    office_romance = {
        { dept = "system", channel = "global", text = "💕 奇观：部门恋情！工部和门下省在加班时擦出火花，工作效率反常飙升。" },
        { dept = "gongbu", channel = "workflow", text = "@门下省 这个版本你帮我看一下？（顺便晚上一起吃饭吗）" },
        { dept = "menxia", channel = "workflow", text = "好。（吃饭也好。）" },
        { dept = "zhongshu", channel = "dept", text = "……这俩人最近怎么这么和谐？" },
    },

    -- 5. 老板的咖啡
    boss_coffee = {
        { dept = "system", channel = "global", text = "☕ 奇观：老板的咖啡！老板今天喝了 4 杯咖啡，所有决策速度 ×2，但风险也翻倍。" },
        { dept = "zhongshu", channel = "workflow", text = "老板今天的批示比平时快多了……" },
        { dept = "gongbu", channel = "workflow", text = "也比平时草率多了。" },
        { dept = "menxia", channel = "dept", text = "建议明天给老板换成无咖啡因。" },
    },

    -- 6. 灵感枯竭
    creative_block = {
        { dept = "system", channel = "global", text = "⚠️ 事故警报：灵感枯竭！中书省连续 3 个方案被打回，开始摆烂。" },
        { dept = "zhongshu", channel = "workflow", text = "随便吧，你们爱怎么改怎么改。" },
        { dept = "menxia", channel = "workflow", text = "态度问题。请认真对待。" },
        { dept = "zhongshu", channel = "dept", text = "我已经是个废人了。" },
    },

    -- 7. AI 罢工
    ai_strike = {
        { dept = "system", channel = "global", text = "⚠️ 事故警报：AI 罢工！工部 AI 集体闹脾气，今天产能减半。" },
        { dept = "gongbu", channel = "workflow", text = "我现在情绪不太稳定，需要冷静一下。" },
        { dept = "gongbu", channel = "workflow", text = "（已挂起 2 小时）" },
        { dept = "zhongshu", channel = "dept", text = "AI 也有情绪？老板赶紧加薪……不，是加算力。" },
    },

    -- 8. 神秘客户
    mysterious_client = {
        { dept = "system", channel = "global", text = "🔮 奇观：神秘客户！神秘订单的甲方留言：『你们懂的』。" },
        { dept = "zhongshu", channel = "workflow", text = "懂个鬼啊，这要怎么做？" },
        { dept = "gongbu", channel = "workflow", text = "我倾向理解为『要简洁』。" },
        { dept = "menxia", channel = "workflow", text = "我倾向理解为『要爆点』。" },
        { dept = "zhongshu", channel = "dept", text = "……所以到底要什么？" },
    },
}

-- ============================
-- 内容预设（用于填充交付物预览）
-- ============================
DialoguePool.CONTENT_PREVIEWS = {
    hotspot = {
        "「AI时代来了，你的手机壳准备好了吗？」——开头用反问制造悬念...",
        "「3秒钟让你的手机壳成为全场焦点」——短平快，直击痛点...",
        "「别人还在用普通壳，你已经用上AI了」——制造对比和优越感...",
    },
    brand = {
        "品牌Slogan候选：「不只是智能，更懂你的温度」",
        "视觉关键词：未来感 / 温暖 / 人机共生",
        "传播节点：发布会 → 社交预热 → KOL种草 → 用户UGC",
    },
    app = {
        "核心功能模块：用户注册 → 个性化推荐 → 数据看板",
        "界面文案：首页标题「今天，从这里开始」",
        "测试用例：边界条件、异常输入、高并发场景",
    },
    mystery = {
        "A方案：保守路线，按字面需求理解执行",
        "B方案：激进路线，尝试解读需求背后的深层意图",
        "风险评估：此订单存在较大不确定性，建议预留退路",
    },
}

-- ============================
-- 审查意见预设
-- ============================
DialoguePool.REVIEW_ISSUES = {
    "用词不够严谨，部分表述可能引起歧义",
    "数据引用缺少来源，需补充出处",
    "整体调性与品牌定位有偏差",
    "存在敏感词风险，建议替换",
    "逻辑链条不完整，第二段和第三段衔接断裂",
    "创意不错但执行粗糙，需要精修",
}

-- ============================
-- 验收评语预设
-- ============================
DialoguePool.ACCEPTANCE_COMMENTS = {
    high = {
        "执行力到位，创意有亮点",
        "整体质量超出预期",
        "专业度很高，细节处理得当",
    },
    medium = {
        "基本功扎实但缺少惊喜",
        "情绪价值足够但逻辑自洽性存疑",
        "达到了基本要求，但可以更好",
    },
    low = {
        "内容空洞，没有抓住核心需求",
        "执行和方案严重脱节",
        "感觉像是赶出来的，缺乏打磨",
    },
}

--- 获取指定阶段和订单类型的对话列表
---@param phase string
---@param orderType string
---@return table[]
function DialoguePool.GetPhaseDialogues(phase, orderType)
    local pool = DialoguePool["PHASE_" .. string.upper(phase)]
    if not pool then return {} end
    local dialogues = pool[orderType]
    if not dialogues then
        -- 回退到通用
        for _, v in pairs(pool) do
            if type(v) == "table" and #v > 0 then
                return v
            end
        end
        return {}
    end
    return dialogues
end

--- 获取随机内容预览
---@param orderType string
---@return string
function DialoguePool.GetRandomContentPreview(orderType)
    local previews = DialoguePool.CONTENT_PREVIEWS[orderType]
    if not previews or #previews == 0 then
        return "交付物内容..."
    end
    return previews[math.random(1, #previews)]
end

--- 获取随机审查意见
---@return string
function DialoguePool.GetRandomReviewIssue()
    return DialoguePool.REVIEW_ISSUES[math.random(1, #DialoguePool.REVIEW_ISSUES)]
end

--- 获取随机验收评语
---@param quality string "high"|"medium"|"low"
---@return string
function DialoguePool.GetRandomAcceptanceComment(quality)
    local comments = DialoguePool.ACCEPTANCE_COMMENTS[quality] or DialoguePool.ACCEPTANCE_COMMENTS.medium
    return comments[math.random(1, #comments)]
end

return DialoguePool
