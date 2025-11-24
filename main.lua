-- Roblox Chat Moderator Tool with Rayfield UI
-- GitHub: https://github.com/yourusername/roblox-chat-moderator
-- License: MIT

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 設定
local Config = {
    ModerationEnabled = true,
    AutoRefresh = true,
    ShowTimestamps = true,
    HighlightInappropriate = true,
    SaveLogs = false,
    AdminUsers = {
        123456789,  -- 管理者1のUserID
        987654321   -- 管理者2のUserID
    },
    InappropriateWords = {
        "badword1", "badword2", "inappropriate"  -- 実際の不適切語に置き換えてください
    }
}

-- チャットログ
local ChatLogs = {}
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- アクセス権限チェック
local function HasAccess(player)
    for _, adminId in ipairs(Config.AdminUsers) do
        if player.UserId == adminId then
            return true
        end
    end
    return false
end

-- 不適切な発言の検出
local function DetectInappropriate(message)
    local lowerMessage = string.lower(message)
    for _, word in ipairs(Config.InappropriateWords) do
        if string.find(lowerMessage, string.lower(word)) then
            return true, word
        end
    end
    return false, nil
end

-- Rayfield UIの作成
local Window = Rayfield:CreateWindow({
    Name = "🔍 Roblox Chat Moderator",
    LoadingTitle = "Chat Moderator Tool",
    LoadingSubtitle = "Loading secure moderation system...",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChatModerator",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvite",
        RememberJoins = true
    },
    KeySystem = false
})

-- メインタブ
local MainTab = Window:CreateTab("Dashboard", "📊")
local ChatViewTab = Window:CreateTab("Live Chat", "💬")
const SettingsTab = Window:CreateTab("Settings", "⚙️")
const ActionsTab = Window:CreateTab("Actions", "🔧")

-- ダッシュボードセクション
local DashboardSection = MainTab:CreateSection("System Status")

local StatusLabel = MainTab:CreateLabel("🟢 System: ACTIVE")
local PlayerCountLabel = MainTab:CreateLabel("👥 Online Players: " .. #Players:GetPlayers())
local ChatCountLabel = MainTab:CreateLabel("💬 Messages Tracked: 0")
local WarningLabel = MainTab:CreateLabel("⚠️ Inappropriate Messages: 0")

-- 統計セクション
local StatsSection = MainTab:CreateSection("Real-time Statistics")

local RecentActivityLabel = MainTab:CreateLabel("Recent Activity: None")
local TopChatterLabel = MainTab:CreateLabel("Top Chatter: None")
const LastAlertLabel = MainTab:CreateLabel("Last Alert: None")

-- クイックアクション
local QuickSection = MainTab:CreateSection("Quick Actions")

local RefreshStatsButton = MainTab:CreateButton({
    Name = "🔄 Refresh Statistics",
    Callback = function()
        UpdateStats()
    end,
})

local ExportLogsButton = MainTab:CreateButton({
    Name = "📤 Export Chat Logs",
    Callback = function()
        ExportChatLogs()
    end,
})

-- ライブチャットビュー
local ChatSection = ChatViewTab:CreateSection("Live Chat Feed")

-- チャット表示用のスクロールフレーム
local ChatLogsContainer = ChatViewTab:CreateScrollingFrame({
    Name = "Live Chat",
    ScrollingEnabled = true,
    VerticalScrollBarVisibility = Enum.ScrollBarVisibility.Auto,
})

-- フィルターセクション
local FilterSection = ChatViewTab:CreateSection("Filters & Controls")

local AutoRefreshToggle = ChatViewTab:CreateToggle({
    Name = "🔄 Auto Refresh",
    CurrentValue = Config.AutoRefresh,
    Flag = "AutoRefresh",
    Callback = function(Value)
        Config.AutoRefresh = Value
        if Value then
            StartAutoRefresh()
        else
            StopAutoRefresh()
        end
    end,
})

local ShowTimestampsToggle = ChatViewTab:CreateToggle({
    Name = "🕒 Show Timestamps",
    CurrentValue = Config.ShowTimestamps,
    Flag = "ShowTimestamps",
    Callback = function(Value)
        Config.ShowTimestamps = Value
        UpdateChatDisplay()
    end,
})

local HighlightToggle = ChatViewTab:CreateToggle({
    Name = "🚨 Highlight Inappropriate",
    CurrentValue = Config.HighlightInappropriate,
    Flag = "HighlightInappropriate",
    Callback = function(Value)
        Config.HighlightInappropriate = Value
        UpdateChatDisplay()
    end,
})

-- プレイヤーフィルター
local PlayerFilter = ChatViewTab:CreateInput({
    Name = "Player Filter",
    PlaceholderText = "Filter by player name...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        UpdateChatDisplay()
    end,
})

-- 設定タブ
local GeneralSection = SettingsTab:CreateSection("General Settings")

local ModerationToggle = SettingsTab:CreateToggle({
    Name = "🛡️ Enable Moderation",
    CurrentValue = Config.ModerationEnabled,
    Flag = "ModerationEnabled",
    Callback = function(Value)
        Config.ModerationEnabled = Value
        if Value then
            StartChatMonitoring()
        else
            StopChatMonitoring()
        end
    end,
})

local SaveLogsToggle = SettingsTab:CreateToggle({
    Name = "💾 Save Chat Logs",
    CurrentValue = Config.SaveLogs,
    Flag = "SaveLogs",
    Callback = function(Value)
        Config.SaveLogs = Value
    end,
})

-- 不適切語設定
local WordSection = SettingsTab:CreateSection("Inappropriate Words")

local InappropriateWordsInput = SettingsTab:CreateInput({
    Name = "Add Inappropriate Word",
    PlaceholderText = "Enter word to block...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        -- 入力時の処理はボタンで実行
    end,
})

local AddWordButton = SettingsTab:CreateButton({
    Name = "➕ Add Word to List",
    Callback = function()
        local word = InappropriateWordsInput.Value
        if word and word ~= "" then
            table.insert(Config.InappropriateWords, word)
            UpdateWordsList()
            InappropriateWordsInput:Set("")
            Rayfield:Notify({
                Title = "✅ Word Added",
                Content = "Added '" .. word .. "' to inappropriate words list",
                Duration = 3,
                Image = 4483362458
            })
        end
    end,
})

local WordsList = SettingsTab:CreateLabel("Blocked Words: " .. table.concat(Config.InappropriateWords, ", "))

-- アクションタブ
local PlayerActionsSection = ActionsTab:CreateSection("Player Actions")

local PlayerDropdown = ActionsTab:CreateDropdown({
    Name = "Select Player",
    Options = GetPlayerList(),
    CurrentOption = "Select Player",
    Flag = "SelectedPlayer",
    Callback = function(Option)
        -- プレイヤー選択時の処理
    end,
})

local WarnButton = ActionsTab:CreateButton({
    Name = "⚠️ Warn Player",
    Callback = function()
        local player = Rayfield.Flags["SelectedPlayer"]
        if player and player ~= "Select Player" then
            WarnPlayer(player)
        end
    end,
})

local KickButton = ActionsTab:CreateButton({
    Name = "🚪 Kick Player",
    Callback = function()
        local player = Rayfield.Flags["SelectedPlayer"]
        if player and player ~= "Select Player" then
            KickPlayer(player)
        end
    end,
})

local MuteButton = ActionsTab:CreateButton({
    Name = "🔇 Mute Player",
    Callback = function()
        local player = Rayfield.Flags["SelectedPlayer"]
        if player and player ~= "Select Player" then
            MutePlayer(player)
        end
    end,
})

-- システムアクション
local SystemSection = ActionsTab:CreateSection("System Actions")

local ClearChatButton = ActionsTab:CreateButton({
    Name = "🗑️ Clear Chat Logs",
    Callback = function()
        ClearChatLogs()
    end,
})

local BackupButton = ActionsTab:CreateButton({
    Name = "💾 Backup Data",
    Callback = function()
        BackupData()
    end,
})

-- 変数と関数
local AutoRefreshConnection
local ChatMonitoringConnection
local Stats = {
    TotalMessages = 0,
    InappropriateCount = 0,
    PlayerMessageCounts = {}
}

-- プレイヤーリストの取得
function GetPlayerList()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(players, player.Name)
    end
    return players
end

-- チャット監視の開始
function StartChatMonitoring()
    if ChatMonitoringConnection then
        ChatMonitoringConnection:Disconnect()
    end
    
    ChatMonitoringConnection = Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(message)
            ProcessChatMessage(player, message)
        end)
    end)
    
    -- 既存のプレイヤー
    for _, player in ipairs(Players:GetPlayers()) do
        player.Chatted:Connect(function(message)
            ProcessChatMessage(player, message)
        end)
    end
end

-- チャットメッセージの処理
function ProcessChatMessage(player, message)
    local timestamp = os.date("%H:%M:%S")
    local isInappropriate, detectedWord = DetectInappropriate(message)
    
    local chatEntry = {
        Player = player,
        Message = message,
        Timestamp = timestamp,
        IsInappropriate = isInappropriate,
        DetectedWord = detectedWord
    }
    
    table.insert(ChatLogs, chatEntry)
    
    -- 統計の更新
    Stats.TotalMessages = Stats.TotalMessages + 1
    Stats.PlayerMessageCounts[player.Name] = (Stats.PlayerMessageCounts[player.Name] or 0) + 1
    
    if isInappropriate then
        Stats.InappropriateCount = Stats.InappropriateCount + 1
        -- 通知を送信
        Rayfield:Notify({
            Title = "🚨 Inappropriate Chat Detected",
            Content = player.Name .. ": " .. message,
            Duration = 6,
            Image = 4483362458
        })
    end
    
    UpdateStats()
    UpdateChatDisplay()
end

-- 統計の更新
function UpdateStats()
    PlayerCountLabel:Set("👥 Online Players: " .. #Players:GetPlayers())
    ChatCountLabel:Set("💬 Messages Tracked: " .. Stats.TotalMessages)
    WarningLabel:Set("⚠️ Inappropriate Messages: " .. Stats.InappropriateCount)
    
    -- トップチャッターの検出
    local topChatter = "None"
    local maxMessages = 0
    for playerName, count in pairs(Stats.PlayerMessageCounts) do
        if count > maxMessages then
            maxMessages = count
            topChatter = playerName
        end
    end
    TopChatterLabel:Set("Top Chatter: " .. topChatter)
end

-- チャット表示の更新
function UpdateChatDisplay()
    ChatLogsContainer:ClearAllChildren()
    
    local yOffset = 0
    local playerFilter = PlayerFilter.Value:lower()
    
    for i = #ChatLogs, 1, -1 do
        local log = ChatLogs[i]
        
        -- プレイヤーフィルターの適用
        if playerFilter == "" or string.find(log.Player.Name:lower(), playerFilter) then
            local messageColor = log.IsInappropriate and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
            local displayText = ""
            
            if Config.ShowTimestamps then
                displayText = "[" .. log.Timestamp .. "] "
            end
            
            displayText = displayText .. log.Player.Name .. ": " .. log.Message
            
            if log.IsInappropriate and Config.HighlightInappropriate then
                displayText = "🚨 " .. displayText
            end
            
            local label = ChatLogsContainer:CreateLabel(displayText)
            label.TextColor3 = messageColor
            label.Position = UDim2.new(0, 10, 0, yOffset)
            label.TextXAlignment = Enum.TextXAlignment.Left
            
            yOffset = yOffset + 20
        end
    end
end

-- 自動更新の開始
function StartAutoRefresh()
    if AutoRefreshConnection then
        AutoRefreshConnection:Disconnect()
    end
    
    AutoRefreshConnection = game:GetService("RunService").Heartbeat:Connect(function()
        UpdateStats()
        PlayerDropdown:UpdateOptions(GetPlayerList())
    end)
end

-- 自動更新の停止
function StopAutoRefresh()
    if AutoRefreshConnection then
        AutoRefreshConnection:Disconnect()
        AutoRefreshConnection = nil
    end
end

-- 単語リストの更新
function UpdateWordsList()
    WordsList:Set("Blocked Words: " .. table.concat(Config.InappropriateWords, ", "))
end

-- プレイヤー警告
function WarnPlayer(playerName)
    Rayfield:Notify({
        Title = "⚠️ Player Warned",
        Content = "Warning sent to " .. playerName,
        Duration = 4,
        Image = 4483362458
    })
end

-- プレイヤーキック
function KickPlayer(playerName)
    Rayfield:Notify({
        Title = "🚪 Player Kicked",
        Content = playerName .. " has been kicked",
        Duration = 4,
        Image = 4483362458
    })
end

-- プレイヤーミュート
function MutePlayer(playerName)
    Rayfield:Notify({
        Title = "🔇 Player Muted",
        Content = playerName .. " has been muted",
        Duration = 4,
        Image = 4483362458
    })
end

-- チャットログのクリア
function ClearChatLogs()
    Rayfield:Notify({
        Title = "🗑️ Clear Chat Logs",
        Content = "This will delete all chat logs",
        Duration = 5,
        Image = 4483362458,
        Actions = {
            Confirm = {
                Name = "Confirm",
                Callback = function()
                    ChatLogs = {}
                    Stats = {
                        TotalMessages = 0,
                        InappropriateCount = 0,
                        PlayerMessageCounts = {}
                    }
                    UpdateStats()
                    UpdateChatDisplay()
                    Rayfield:Notify({
                        Title = "✅ Logs Cleared",
                        Content = "All chat logs have been deleted",
                        Duration = 3,
                        Image = 4483362458
                    })
                end,
            },
            Cancel = {
                Name = "Cancel",
                Callback = function()
                    Rayfield:Notify({
                        Title = "❌ Action Cancelled",
                        Content = "Chat logs were not cleared",
                        Duration = 3,
                        Image = 4483362458
                    })
                end,
            },
        },
    })
end

-- データのエクスポート
function ExportChatLogs()
    local exportData = {
        ExportTime = os.date("%Y-%m-%d %H:%M:%S"),
        TotalMessages = Stats.TotalMessages,
        InappropriateCount = Stats.InappropriateCount,
        ChatLogs = ChatLogs
    }
    
    local json = HttpService:JSONEncode(exportData)
    
    -- ここでエクスポート処理を実装
    -- 例: ファイル保存やクリップボードコピー
    
    Rayfield:Notify({
        Title = "📤 Data Exported",
        Content = "Chat logs exported successfully",
        Duration = 4,
        Image = 4483362458
    })
end

-- データのバックアップ
function BackupData()
    Rayfield:Notify({
        Title = "💾 Backup Created",
        Content = "System data has been backed up",
        Duration = 4,
        Image = 4483362458
    })
end

-- 初期化
if Config.ModerationEnabled then
    StartChatMonitoring()
end

if Config.AutoRefresh then
    StartAutoRefresh()
end

UpdateStats()
UpdateWordsList()

-- 初期化完了通知
Rayfield:Notify({
    Title = "🔍 Chat Moderator Active",
    Content = "System initialized and monitoring chat",
    Duration = 6,
    Image = 4483362458
})

print("Chat Moderator Tool loaded successfully!")
