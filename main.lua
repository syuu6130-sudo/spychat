--[[
   改良版チャットスパイ for Rayfield UI
   タイプ "/spy" でスパイを有効/無効に切り替え
   すべてのエグゼキューター対応版
--]]

-- Rayfield UIの読み込み（エラー処理付き）
local Rayfield
local success, error = pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    warn("Rayfield UIの読み込みに失敗しました:", error)
    return
end

-- メインウィンドウの作成
local Window = Rayfield:CreateWindow({
   Name = "チャットスパイ v2.0",
   LoadingTitle = "チャットスパイシステム",
   LoadingSubtitle = "全エグゼキューター対応版",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "ChatSpy",
      FileName = "Config"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false,
})

local Tab = Window:CreateTab("スパイ設定", 4483362458)

local Section = Tab:CreateSection("メイン設定")

local EnabledToggle = Tab:CreateToggle({
   Name = "チャットスパイを有効化",
   CurrentValue = true,
   Flag = "SpyEnabled",
   Callback = function(Value)
      Config.enabled = Value
      updateStatusMessage()
   end,
})

local SelfSpyToggle = Tab:CreateToggle({
   Name = "自分自身を監視",
   CurrentValue = true,
   Flag = "SpySelf",
   Callback = function(Value)
      Config.spyOnMyself = Value
   end,
})

local PublicToggle = Tab:CreateToggle({
   Name = "公開モード",
   CurrentValue = false,
   Flag = "PublicMode",
   Callback = function(Value)
      Config.public = Value
   end,
})

local ItalicsToggle = Tab:CreateToggle({
   Name = "公開時にイタリック表示",
   CurrentValue = true,
   Flag = "PublicItalics",
   Callback = function(Value)
      Config.publicItalics = Value
   end,
})

local Section2 = Tab:CreateSection("表示設定")

local ColorPicker = Tab:CreateColorPicker({
   Name = "スパイメッセージの色",
   Color = Color3.fromRGB(0, 255, 255),
   Flag = "MessageColor",
   Callback = function(Value)
      PrivateProperties.Color = Value
   end
})

local Dropdown = Tab:CreateDropdown({
   Name = "フォントスタイル",
   Options = {"SourceSansBold", "SourceSans", "Code", "Highway", "SciFi"},
   CurrentOption = "SourceSansBold",
   Flag = "FontStyle",
   Callback = function(Option)
      PrivateProperties.Font = Enum.Font[Option]
   end,
})

local Slider = Tab:CreateSlider({
   Name = "文字サイズ",
   Range = {12, 24},
   Increment = 1,
   Suffix = "px",
   CurrentValue = 18,
   Flag = "TextSize",
   Callback = function(Value)
      PrivateProperties.TextSize = Value
   end,
})

local Section3 = Tab:CreateSection("アクション")

local Button = Tab:CreateButton({
   Name = "スパイシステムを再起動",
   Callback = function()
      restartSpySystem()
   end,
})

local Button2 = Tab:CreateButton({
   Name = "テストメッセージを表示",
   Callback = function()
      testSpyMessage()
   end,
})

-- 設定
local Config = {
   enabled = true,
   spyOnMyself = true,
   public = false,
   publicItalics = true
}

-- メッセージプロパティ
local PrivateProperties = {
   Color = Color3.fromRGB(0, 255, 255),
   Font = Enum.Font.SourceSansBold,
   TextSize = 18
}

-- サービス
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

-- 変数
local player = Players.LocalPlayer
local saymsg = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest")
local getmsg = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("OnMessageDoneFiltering")
local instance = (_G.chatSpyInstance or 0) + 1
local activeConnections = {}

-- 初期化
_G.chatSpyInstance = instance

-- 関数
local function updateStatusMessage()
   local status = Config.enabled and "有効" or "無効"
   PrivateProperties.Text = "{スパイ "..status.."}"
   pcall(function()
      StarterGui:SetCore("ChatMakeSystemMessage", PrivateProperties)
   end)
end

local function safeSetCore(message)
   PrivateProperties.Text = message
   pcall(function()
      StarterGui:SetCore("ChatMakeSystemMessage", PrivateProperties)
   end)
end

local function restartSpySystem()
   -- 既存の接続をクリーンアップ
   for _, conn in pairs(activeConnections) do
      if conn then
         conn:Disconnect()
      end
   end
   activeConnections = {}
   
   -- 再初期化
   _G.chatSpyInstance = _G.chatSpyInstance + 1
   instance = _G.chatSpyInstance
   
   -- すべてのプレイヤーに再接続
   for _, p in ipairs(Players:GetPlayers()) do
      if p ~= player then
         local conn = p.Chatted:Connect(function(msg)
            onChatted(p, msg)
         end)
         table.insert(activeConnections, conn)
      end
   end
   
   safeSetCore("{スパイシステム再起動完了}")
end

local function testSpyMessage()
   safeSetCore("{スパイテスト} これはスパイシステムからのテストメッセージです")
end

local function isMessageFiltered(speaker, message)
   local filtered = false
   local conn
   
   conn = getmsg.OnClientEvent:Connect(function(packet, channel)
      if packet.SpeakerUserId == speaker.UserId and string.find(message, packet.Message, 1, true) then
         if channel == "All" or (channel == "Team" and not Config.public and Players[packet.FromSpeaker].Team == player.Team) then
            filtered = true
         end
      end
   end)
   
   -- メッセージ処理を待機
   local startTime = tick()
   while tick() - startTime < 2 and not filtered do
      task.wait(0.1)
   end
   
   if conn then
      conn:Disconnect()
   end
   
   return not filtered
end

local function onChatted(p, msg)
   -- このインスタンスがまだアクティブかチェック
   if _G.chatSpyInstance ~= instance then return end
   
   -- スパイコマンドの処理
   if p == player and msg:lower():sub(1,4) == "/spy" then
      Config.enabled = not Config.enabled
      EnabledToggle:Set(Config.enabled)
      task.wait(0.3)
      updateStatusMessage()
      return
   end
   
   -- スパイ機能の処理
   if Config.enabled and (Config.spyOnMyself or p ~= player) then
      -- メッセージをクリーニング
      local cleanMsg = msg:gsub("[\n\r]", ''):gsub("\t", ' '):gsub("%s+", ' '):gsub("^%s+", ""):gsub("%s+$", "")
      
      -- 空のメッセージをスキップ
      if cleanMsg == "" then return end
      
      -- メッセージがフィルターされているかチェック（公開チャットに表示されないか）
      if isMessageFiltered(p, cleanMsg) then
         if Config.public then
            local spyMsg = (Config.publicItalics and "/me " or '') .. "{スパイ} [" .. p.Name .. "]: " .. cleanMsg
            pcall(function()
               saymsg:FireServer(spyMsg, "All")
            end)
         else
            safeSetCore("{スパイ} [" .. p.Name .. "]: " .. cleanMsg)
         end
      end
   end
end

-- プレイヤー接続のセットアップ
local function setupPlayer(p)
   if p == player then return end
   
   local conn = p.Chatted:Connect(function(msg)
      onChatted(p, msg)
   end)
   table.insert(activeConnections, conn)
end

-- 既存のプレイヤーの接続を初期化
for _, p in ipairs(Players:GetPlayers()) do
   setupPlayer(p)
end

-- 新しいプレイヤーの処理
local playerAddedConn
playerAddedConn = Players.PlayerAdded:Connect(function(p)
   setupPlayer(p)
end)
table.insert(activeConnections, playerAddedConn)

-- プレイヤー退出の処理
local playerRemovingConn
playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
   -- このプレイヤーに関連する接続をクリーンアップ
   for i, conn in ipairs(activeConnections) do
      if not conn.Connected then
         table.remove(activeConnections, i)
         break
      end
   end
end)
table.insert(activeConnections, playerRemovingConn)

-- チャットUIを安全に調整
pcall(function()
   local success, chatFrame = pcall(function()
      return player.PlayerGui:WaitForChild("Chat", 10).Frame
   end)
   
   if success and chatFrame then
      chatFrame.ChatChannelParentFrame.Visible = true
      chatFrame.ChatBarParentFrame.Position = chatFrame.ChatChannelParentFrame.Position + UDim2.new(UDim.new(), chatFrame.ChatChannelParentFrame.Size.Y)
   end
end)

-- 初期ステータスメッセージ
updateStatusMessage()

Rayfield:LoadConfiguration()

-- スクリプトが破棄されたときのクリーンアップ
local function cleanup()
   for _, conn in pairs(activeConnections) do
      if conn then
         conn:Disconnect()
      end
   end
   activeConnections = {}
end

-- 自動クリーンアップ
game:GetService("UserInputService").WindowFocused:Connect(function()
   if _G.chatSpyInstance ~= instance then
      cleanup()
   end
end)

print("-- 改良版チャットスパイ 読み込み完了 --")
print('チャットで "/spy" と入力するか、Rayfield UIでスパイを制御してください')
print("機能: カラーカスタマイズ、フォント設定、公開/非公開モード")
