--[[
   改良版チャットスパイ for Rayfield UI
   プライベートチャットを確実に検出する強化版
   "/spy"で有効/無効を切り替え
--]]

-- Rayfield UIの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- メインウィンドウの作成
local Window = Rayfield:CreateWindow({
   Name = "チャットスパイ v3.0",
   LoadingTitle = "チャットスパイシステム",
   LoadingSubtitle = "プライベートチャット検出対応版",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "ChatSpyConfig",
      FileName = "設定"
   },
   KeySystem = false,
})

-- 設定タブの作成
local 設定タブ = Window:CreateTab("スパイ設定", 4483362458)

-- メイン設定セクション
local メイン設定 = 設定タブ:CreateSection("基本設定")

local 有効化トグル = 設定タブ:CreateToggle({
   Name = "チャットスパイを有効化",
   CurrentValue = true,
   Flag = "SpyEnabled",
   Callback = function(状態)
      設定.有効 = 状態
      ステータス表示更新()
   end,
})

local 自分監視トグル = 設定タブ:CreateToggle({
   Name = "自分のチャットも監視",
   CurrentValue = false,
   Flag = "SpySelf",
   Callback = function(状態)
      設定.自分を監視 = 状態
   end,
})

local 公開モードトグル = 設定タブ:CreateToggle({
   Name = "公開モード（全員に見える）",
   CurrentValue = false,
   Flag = "PublicMode",
   Callback = function(状態)
      設定.公開 = 状態
   end,
})

-- 表示設定セクション
local 表示設定 = 設定タブ:CreateSection("表示設定")

local 色選択 = 設定タブ:CreateColorPicker({
   Name = "メッセージ色",
   Color = Color3.fromRGB(0, 255, 255),
   Flag = "MessageColor",
   Callback = function(色)
      表示設定.色 = 色
   end
})

local 文字サイズスライダー = 設定タブ:CreateSlider({
   Name = "文字サイズ",
   Range = {14, 22},
   Increment = 1,
   Suffix = "px",
   CurrentValue = 18,
   Flag = "TextSize",
   Callback = function(サイズ)
      表示設定.文字サイズ = サイズ
   end,
})

-- アクションセクション
local アクション設定 = 設定タブ:CreateSection("アクション")

local 再起動ボタン = 設定タブ:CreateButton({
   Name = "スパイシステム再起動",
   Callback = function()
      システム再起動()
   end,
})

-- グローバル変数
local サービス = {
   スタートGUI = game:GetService("StarterGui"),
   プレイヤー = game:GetService("Players"),
   レプリケートストレージ = game:GetService("ReplicatedStorage")
}

local ローカルプレイヤー = サービス.プレイヤー.LocalPlayer
local チャットイベント = サービス.レプリケートストレージ:WaitForChild("DefaultChatSystemChatEvents")
local 発言リクエスト = チャットイベント:WaitForChild("SayMessageRequest")
local メッセージフィルター = チャットイベント:WaitForChild("OnMessageDoneFiltering")

-- 設定
local 設定 = {
   有効 = true,
   自分を監視 = false,
   公開 = false
}

-- 表示設定
local 表示設定 = {
   色 = Color3.fromRGB(0, 255, 255),
   文字サイズ = 18
}

-- システム変数
local システムインスタンス = (_G.チャットスパイインスタンス or 0) + 1
_G.チャットスパイインスタンス = システムインスタンス
local アクティブ接続 = {}

-- 安全な関数実行
local function 安全実行(関数, ...)
    local 成功, 結果 = pcall(関数, ...)
    if not 成功 then
        warn("スパイシステムエラー:", 結果)
        return nil
    end
    return 結果
end

-- ステータス表示更新
local function ステータス表示更新()
    local ステータス = 設定.有効 and "有効" or "無効"
    local メッセージプロパティ = {
        Color = 表示設定.色,
        Font = Enum.Font.SourceSansBold,
        TextSize = 表示設定.文字サイズ,
        Text = "【スパイシステム】 " .. ステータス
    }
    安全実行(function()
        サービス.スタートGUI:SetCore("ChatMakeSystemMessage", メッセージプロパティ)
    end)
end

-- システムメッセージ表示
local function システムメッセージ表示(テキスト)
    local メッセージプロパティ = {
        Color = 表示設定.色,
        Font = Enum.Font.SourceSansBold,
        TextSize = 表示設定.文字サイズ,
        Text = テキスト
    }
    安全実行(function()
        サービス.スタートGUI:SetCore("ChatMakeSystemMessage", メッセージプロパティ)
    end)
end

-- メッセージクリーニング
local function メッセージクリーニング(メッセージ)
    return メッセージ:gsub("[\n\r]", ""):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- メッセージ検出処理
local function メッセージ検出処理(送信者, メッセージ)
    if _G.チャットスパイインスタンス ~= システムインスタンス then return end
    
    -- スパイコマンド処理
    if 送信者 == ローカルプレイヤー and メッセージ:lower():sub(1,4) == "/spy" then
        設定.有効 = not 設定.有効
        有効化トグル:Set(設定.有効)
        task.wait(0.5)
        ステータス表示更新()
        return
    end
    
    -- スパイ条件チェック
    if not 設定.有効 then return end
    if not 設定.自分を監視 and 送信者 == ローカルプレイヤー then return end
    
    local 清潔メッセージ = メッセージクリーニング(メッセージ)
    if 清潔メッセージ == "" then return end
    
    -- プライベートチャット検出
    local 検出済み = false
    local 接続
    
    接続 = メッセージフィルター.OnClientEvent:Connect(function(パケット, チャンネル)
        if パケット.SpeakerUserId == 送信者.UserId then
            if パケット.Message:find(清潔メッセージ, 1, true) or 清潔メッセージ:find(パケット.Message, 1, true) then
                検出済み = true
                if 接続 then
                    接続:Disconnect()
                end
            end
        end
    end)
    
    -- 2秒待機して検出を確認
    local 開始時間 = tick()
    while tick() - 開始時間 < 2 and not 検出済み do
        task.wait(0.1)
    end
    
    if 接続 then
        接続:Disconnect()
    end
    
    -- 検出されなかった場合（プライベートチャット）
    if not 検出済み then
        if 設定.公開 then
            安全実行(function()
                発言リクエスト:FireServer("/me 【スパイ】 [" .. 送信者.Name .. "]: " .. 清潔メッセージ, "All")
            end)
        else
            システムメッセージ表示("【スパイ】 [" .. 送信者.Name .. "]: " .. 清潔メッセージ)
        end
    end
end

-- プレイヤー接続設定
local function プレイヤー接続設定(プレイヤー)
    if プレイヤー == ローカルプレイヤー then return end
    
    local 接続 = プレイヤー.Chatted:Connect(function(メッセージ)
        メッセージ検出処理(プレイヤー, メッセージ)
    end)
    table.insert(アクティブ接続, 接続)
end

-- システム再起動
local function システム再起動()
    -- 既存接続をクリーンアップ
    for _, 接続 in pairs(アクティブ接続) do
        if 接続 then
            接続:Disconnect()
        end
    end
    アクティブ接続 = {}
    
    -- 新しいインスタンスを作成
    _G.チャットスパイインスタンス = (_G.チャットスパイインスタンス or 0) + 1
    システムインスタンス = _G.チャットスパイインスタンス
    
    -- プレイヤー接続を再設定
    for _, プレイヤー in ipairs(サービス.プレイヤー:GetPlayers()) do
        プレイヤー接続設定(プレイヤー)
    end
    
    システムメッセージ表示("【スパイシステム】 再起動完了")
end

-- 初期化処理
local function システム初期化()
    -- 既存プレイヤーに接続
    for _, プレイヤー in ipairs(サービス.プレイヤー:GetPlayers()) do
        プレイヤー接続設定(プレイヤー)
    end
    
    -- 新規プレイヤー接続処理
    local 新規プレイヤー接続 = サービス.プレイヤー.PlayerAdded:Connect(function(プレイヤー)
        プレイヤー接続設定(プレイヤー)
    end)
    table.insert(アクティブ接続, 新規プレイヤー接続)
    
    -- プレイヤー退出処理
    local プレイヤー退出接続 = サービス.プレイヤー.PlayerRemoving:Connect(function(プレイヤー)
        -- 接続のクリーンアップ
        for i = #アクティブ接続, 1, -1 do
            if not アクティブ接続[i].Connected then
                table.remove(アクティブ接続, i)
            end
        end
    end)
    table.insert(アクティブ接続, プレイヤー退出接続)
    
    -- 初期ステータス表示
    ステータス表示更新()
    
    システムメッセージ表示("【スパイシステム】 起動完了 - /spy で切り替え")
end

-- システム開始
システム初期化()

-- Rayfield設定読み込み
Rayfield:LoadConfiguration()

print("=== チャットスパイシステム v3.0 ===")
print("機能: プライベートチャット検出")
print("操作方法: チャットで「/spy」入力 or UI操作")
print("設定: Rayfield UIからカスタマイズ可能")
