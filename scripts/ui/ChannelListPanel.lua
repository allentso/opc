-- ============================================================================
-- ChannelListPanel.lua — 频道列表面板（竖屏全宽，无图标条）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local ChannelManager = require("systems.ChannelManager")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local ChannelListPanel = {}

local channelItems_ = {}
local containerRef_ = nil

--- 创建全宽频道列表
---@return table widget
function ChannelListPanel.Create()
    containerRef_ = UI.Panel {
        id = "channelListPanel",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            -- 频道滚动列表（header 由 MainLayout overlay 包装器提供）
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                showScrollbar = false,
                children = {
                    UI.Panel {
                        id = "channelListContent",
                        width = "100%",
                        flexDirection = "column",
                        paddingBottom = 12,
                        children = {
                            -- 公开频道标题
                            UI.Panel {
                                width = "100%",
                                paddingLeft = 16, paddingRight = 16,
                                paddingTop = 12, paddingBottom = 6,
                                children = {
                                    UI.Label {
                                        text = "公开频道",
                                        fontSize = 12,
                                        fontColor = C.text_muted,
                                        fontWeight = "bold",
                                    },
                                },
                            },

                            -- 公开频道区
                            UI.Panel {
                                id = "publicChannelSection",
                                width = "100%",
                                flexDirection = "column",
                            },

                            -- 分隔区（私下频道）
                            UI.Panel {
                                id = "secretSection",
                                width = "100%",
                                flexDirection = "column",
                                children = {
                                    -- 分割线
                                    UI.Panel {
                                        width = "100%",
                                        height = 1,
                                        backgroundColor = C.divider,
                                        marginTop = 8,
                                        marginBottom = 8,
                                        marginLeft = 16, marginRight = 16,
                                    },
                                    -- 标题
                                    UI.Panel {
                                        width = "100%",
                                        paddingLeft = 16, paddingRight = 16,
                                        paddingBottom = 6,
                                        flexDirection = "row",
                                        alignItems = "center",
                                        gap = 6,
                                        children = {
                                            UI.Label {
                                                text = "👁 私下频道",
                                                fontSize = 12,
                                                fontColor = C.danger,
                                                fontWeight = "bold",
                                            },
                                            UI.Label {
                                                text = "你偷偷看到的",
                                                fontSize = 10,
                                                fontColor = C.text_muted,
                                            },
                                        },
                                    },
                                },
                            },

                            -- 私下频道区
                            UI.Panel {
                                id = "secretChannelSection",
                                width = "100%",
                                flexDirection = "column",
                            },
                        },
                    },
                },
            },
        },
    }

    ChannelListPanel.Refresh()
    return containerRef_
end

--- 列表头部（标题 + 状态指示）
function ChannelListPanel._createHeader()
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 16, paddingRight = 16,
        paddingTop = 12, paddingBottom = 12,
        backgroundColor = C.bg_primary,
        borderBottomWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = {
            UI.Label {
                text = "💬  频道消息",
                fontSize = 16,
                fontColor = C.text_primary,
                fontWeight = "bold",
                flexGrow = 1,
            },
            -- 在线状态
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Panel {
                        width = 6, height = 6,
                        borderRadius = 3,
                        backgroundColor = C.online_green,
                    },
                    UI.Label {
                        text = "在线",
                        fontSize = 11,
                        fontColor = C.text_muted,
                    },
                },
            },
        },
    }
end

--- 刷新频道列表
function ChannelListPanel.Refresh()
    if not containerRef_ then return end

    local publicSection = containerRef_:FindById("publicChannelSection")
    local secretSection = containerRef_:FindById("secretSection")
    local secretChannelSection = containerRef_:FindById("secretChannelSection")
    if not publicSection or not secretChannelSection then return end

    publicSection:ClearChildren()
    secretChannelSection:ClearChildren()
    channelItems_ = {}

    local channels = ChannelManager.GetVisibleChannels()
    local activeId = ChannelManager.GetActiveChannelId()

    for _, ch in ipairs(channels.public) do
        local item = ChannelListPanel._createChannelItem(ch, activeId)
        publicSection:AddChild(item)
        channelItems_[ch.id] = item
    end

    if #channels.secret > 0 then
        secretSection:SetVisible(true)
        for _, ch in ipairs(channels.secret) do
            local item = ChannelListPanel._createChannelItem(ch, activeId)
            secretChannelSection:AddChild(item)
            channelItems_[ch.id] = item
        end
    else
        secretSection:SetVisible(false)
    end
end

--- 创建单个频道条目（v0.4：方形头像 + 名称+预览 + 右侧时间+未读）
function ChannelListPanel._createChannelItem(channel, activeId)
    local isActive = (channel.id == activeId)
    local isSecret = (channel.type == "secret")

    local nameColor = isActive and C.text_primary or C.text_primary
    local bgColor = isActive and C.bg_selected or { 0, 0, 0, 0 }

    -- 头像（与左侧 sidebar 一致：方形彩底）
    local deptId = channel.dept or channel.id
    local iconText, badgeColor
    if isSecret then
        iconText = channel.icon or "🔒"
        badgeColor = C.channel_secret_bg
    elseif deptId == "global" then
        iconText = "📢"; badgeColor = GameConfig.DEPT_BADGE_COLORS.global
    elseif deptId == "workflow" then
        iconText = "🔄"; badgeColor = GameConfig.DEPT_BADGE_COLORS.workflow
    else
        local pure = type(deptId) == "string" and deptId:match("^dept_(.+)$") or deptId
        iconText = GameConfig.DEPT_SHORT[pure] or string.sub(channel.name or "?", 1, 1)
        badgeColor = GameConfig.DEPT_BADGE_COLORS[pure] or C.accent
    end

    -- 最后一条消息预览 + 时间
    local lastMsg = ""
    local lastTime = ""
    if channel.messages and #channel.messages > 0 then
        local msg = channel.messages[#channel.messages]
        local senderPrefix = ""
        if msg.dept then
            local deptName = GameConfig.DEPT_NAMES[msg.dept]
            if deptName then senderPrefix = deptName .. "：" end
        elseif msg.isBoss then
            senderPrefix = "老板："
        end
        lastMsg = senderPrefix .. (msg.text or "")
        if #lastMsg > 36 then
            lastMsg = string.sub(lastMsg, 1, 36) .. "…"
        end
        lastTime = msg.timestamp and os.date("%H:%M", msg.timestamp) or os.date("%H:%M")
    elseif isSecret then
        lastMsg = "👁 " .. (channel.condition or "暗中观察…")
    else
        lastMsg = "暂无消息"
    end

    -- 频道名颜色：私下频道用红色字 + 偷窥角标
    local channelNameColor = isSecret and C.danger or nameColor

    return UI.Panel {
        id = "ch_" .. channel.id,
        width = "100%",
        height = GameConfig.UI.channel_item_height,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 14, paddingRight = 14,
        gap = 10,
        backgroundColor = bgColor,
        cursor = "pointer",
        onClick = function()
            ChannelManager.SwitchChannel(channel.id)
            ChannelListPanel.Refresh()
        end,
        onPointerEnter = function(_, w)
            if channel.id ~= ChannelManager.GetActiveChannelId() then
                w:SetStyle({ backgroundColor = C.bg_hover })
            end
        end,
        onPointerLeave = function(_, w)
            if channel.id ~= ChannelManager.GetActiveChannelId() then
                w:SetStyle({ backgroundColor = { 0, 0, 0, 0 } })
            end
        end,
        children = {
            -- 头像方块
            UI.Panel {
                width = 38, height = 38,
                borderRadius = 9,
                backgroundColor = badgeColor,
                justifyContent = "center", alignItems = "center",
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = iconText or "?",
                        fontSize = 16,
                        fontColor = C.text_white,
                        fontWeight = "bold",
                    },
                },
            },
            -- 名称 + 预览
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = 2,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 5,
                        children = {
                            UI.Label {
                                text = channel.name or "频道",
                                fontSize = 13,
                                fontColor = channelNameColor,
                                fontWeight = isActive and "bold" or "normal",
                            },
                            isSecret and UI.Label {
                                text = "👁",
                                fontSize = 10,
                                fontColor = C.danger,
                            } or UI.Panel { width = 0, height = 0 },
                        },
                    },
                    UI.Label {
                        text = lastMsg,
                        fontSize = 10,
                        fontColor = C.text_muted,
                    },
                },
            },
            -- 右侧：时间 + 未读
            UI.Panel {
                flexDirection = "column",
                alignItems = "flex-end",
                justifyContent = "center",
                gap = 4,
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = lastTime,
                        fontSize = 9,
                        fontColor = C.text_muted,
                    },
                    ChannelListPanel._createUnreadBadge(channel),
                },
            },
        },
    }
end

--- 创建未读标记
function ChannelListPanel._createUnreadBadge(channel)
    if not channel.unread or channel.unread <= 0 then
        return UI.Panel { width = 0, height = 0 }
    end

    return UI.Panel {
        minWidth = 22, height = 22,
        borderRadius = 11,
        backgroundColor = C.danger,
        justifyContent = "center",
        alignItems = "center",
        paddingLeft = 6, paddingRight = 6,
        flexShrink = 0,
        children = {
            UI.Label {
                text = tostring(channel.unread),
                fontSize = 11,
                fontColor = C.text_white,
                fontWeight = "bold",
            },
        },
    }
end

return ChannelListPanel
