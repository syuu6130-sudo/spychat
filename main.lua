--[[
    Chat Spy with Rayfield UI
    Modern GUI interface for monitoring player chats
--]]

-- Rayfield UIライブラリの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 設定
local Config = {
    enabled = true,
    spyOnMyself = true,
    public = false,
    publicItalics = true,
    logToConsole = true
}

-- サービスの取得
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- チャットイベントの取得
local saymsg = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest")
local getmsg = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("OnMessageDoneFiltering")

-- ログプロパティ
local PrivateProperties = {
    Color = Color3.fromRGB(0, 255, 255),
    Font = Enum.Font.SourceSansBold,
    TextSize = 18
}

-- インスタンス管理
local instance = (_G.chatSpyInstance or 0) + 1
_G.chatSpyInstance = instance

-- チャットログ保存用
local chatLogs = {}
local maxLogs = 100

-- Rayfield ウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "Chat Spy | v2.0",
    LoadingTitle = "Chat Spy Loading...",
    LoadingSubtitle = "by Rayfield UI",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChatSpyConfig",
        FileName = "ChatSpySettings"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

-- メインタブ
local MainTab = Window:CreateTab("🏠 Main", 4483362458)
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
local LogsTab = Window:CreateTab("📝 Logs", 4483362458)

-- メインセクション
local MainSection = MainTab:CreateSection("Chat Spy Controls")

-- スパイ有効/無効トグル
local SpyToggle = MainTab:CreateToggle({
    Name = "Enable Chat Spy",
    CurrentValue = Config.enabled,
    Flag = "SpyEnabled",
    Callback = function(Value)
        Config.enabled = Value
        local status = Value and "ENABLED" or "DISABLED"
        PrivateProperties.Text = "{SPY " .. status .. "}"
        StarterGui:SetCore("ChatMakeSystemMessage", PrivateProperties)
        
        if Config.logToConsole then
            print("[Chat Spy] " .. status)
        end
        
        Rayfield:Notify({
            Title = "Chat Spy",
            Content = "Chat Spy " .. status,
            Duration = 3,
            Image = 4483362458
        })
    end
})

-- ステータス表示
local StatusLabel = MainTab:CreateLabel("Status: " .. (Config.enabled and "🟢 Active" or "🔴 Inactive"))

-- 設定セクション
local ConfigSection = SettingsTab:CreateSection("Spy Settings")

-- 自分のチャットを監視
SettingsTab:CreateToggle({
    Name = "Spy On Myself",
    CurrentValue = Config.spyOnMyself,
    Flag = "SpyOnMyself",
    Callback = function(Value)
        Config.spyOnMyself = Value
    end
})

-- 公開モード
SettingsTab:CreateToggle({
    Name = "Public Mode",
    CurrentValue = Config.public,
    Flag = "PublicMode",
    Callback = function(Value)
        Config.public = Value
    end
})

-- イタリック体
SettingsTab:CreateToggle({
    Name = "Public Italics",
    CurrentValue = Config.publicItalics,
    Flag = "PublicItalics",
    Callback = function(Value)
        Config.publicItalics = Value
    end
})

-- コンソールログ
SettingsTab:CreateToggle({
    Name = "Log to Console",
    CurrentValue = Config.logToConsole,
    Flag = "LogToConsole",
    Callback = function(Value)
        Config.logToConsole = Value
    end
})

-- ログセクション
local LogsSection = LogsTab:CreateSection("Recent Chat Logs")

local LogsParagraph = LogsTab:CreateParagraph({
    Title = "Chat Logs",
    Content = "No messages logged yet..."
})

-- ログクリアボタン
LogsTab:CreateButton({
    Name = "Clear Logs",
    Callback = function()
        chatLogs = {}
        LogsParagraph:Set({Title = "Chat Logs", Content = "Logs cleared!"})
        Rayfield:Notify({
            Title = "Chat Spy",
            Content = "Logs cleared successfully",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- ログを更新する関数
local function updateLogsDisplay()
    if #chatLogs == 0 then
        LogsParagraph:Set({Title = "Chat Logs", Content = "No messages logged yet..."})
        return
    end
    
    local logText = ""
    local displayCount = math.min(#chatLogs, 20)
    
    for i = #chatLogs - displayCount + 1, #chatLogs do
        if chatLogs[i] then
            logText = logText .. chatLogs[i] .. "\n"
        end
    end
    
    LogsParagraph:Set({Title = "Chat Logs (" .. #chatLogs .. " total)", Content = logText})
end

-- チャット監視関数
local function onChatted(p, msg)
    if _G.chatSpyInstance ~= instance then return end
    
    -- /spyコマンドの処理
    if p == player and msg:lower():sub(1, 4) == "/spy" then
        Config.enabled = not Config.enabled
        SpyToggle:Set(Config.enabled)
        StatusLabel:Set("Status: " .. (Config.enabled and "🟢 Active" or "🔴 Inactive"))
        return
    end
    
    -- スパイが無効、または自分のメッセージを除外
    if not Config.enabled then return end
    if not Config.spyOnMyself and p == player then return end
    
    -- メッセージのクリーンアップ
    msg = msg:gsub("[\n\r]", ''):gsub("\t", ' '):gsub("[ ]+", ' ')
    
    local hidden = true
    local conn = getmsg.OnClientEvent:Connect(function(packet, channel)
        if packet.SpeakerUserId == p.UserId and 
           packet.Message == msg:sub(#msg - #packet.Message + 1) and 
           (channel == "All" or (channel == "Team" and not Config.public and 
            Players[packet.FromSpeaker].Team == player.Team)) then
            hidden = false
        end
    end)
    
    wait(1)
    conn:Disconnect()
    
    if hidden and Config.enabled then
        local timestamp = os.date("%H:%M:%S")
        local logMessage = string.format("[%s] %s: %s", timestamp, p.Name, msg)
        
        -- ログに追加
        table.insert(chatLogs, logMessage)
        if #chatLogs > maxLogs then
            table.remove(chatLogs, 1)
        end
        
        -- UIを更新
        updateLogsDisplay()
        
        -- コンソールにログ
        if Config.logToConsole then
            print("[Chat Spy] " .. logMessage)
        end
        
        -- チャットに表示
        if Config.public then
            local prefix = Config.publicItalics and "/me " or ""
            saymsg:FireServer(prefix .. "{SPY} [" .. p.Name .. "]: " .. msg, "All")
        else
            PrivateProperties.Text = "{SPY} [" .. p.Name .. "]: " .. msg
            StarterGui:SetCore("ChatMakeSystemMessage", PrivateProperties)
        end
    end
end

-- 既存プレイヤーのチャットを監視
for _, p in ipairs(Players:GetPlayers()) do
    p.Chatted:Connect(function(msg)
        onChatted(p, msg)
    end)
end

-- 新規プレイヤーのチャットを監視
Players.PlayerAdded:Connect(function(p)
    p.Chatted:Connect(function(msg)
        onChatted(p, msg)
    end)
end)

-- 初期化メッセージ
PrivateProperties.Text = "{SPY " .. (Config.enabled and "ENABLED" or "DISABLED") .. "}"
StarterGui:SetCore("ChatMakeSystemMessage", PrivateProperties)

-- チャットフレームの調整
local chatFrame = player.PlayerGui.Chat.Frame
chatFrame.ChatChannelParentFrame.Visible = true
chatFrame.ChatBarParentFrame.Position = chatFrame.ChatChannelParentFrame.Position + 
    UDim2.new(UDim.new(), chatFrame.ChatChannelParentFrame.Size.Y)

-- 起動通知
Rayfield:Notify({
    Title = "Chat Spy Loaded",
    Content = "Chat Spy is now active!",
    Duration = 5,
    Image = 4483362458
})

print("-- Chat Spy with Rayfield UI Loaded --")
print("Press RightShift to toggle UI")
print("Type '/spy' in chat to toggle spy mode")
