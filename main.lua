--[[
	Enhanced Chat Spy for Rayfield UI
	Type "/spy" to enable or disable the chat spy
	Fixed and optimized version with better reliability
--]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Chat Spy v2.0",
   LoadingTitle = "Chat Spy System",
   LoadingSubtitle = "by Enhanced Version",
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

local Tab = Window:CreateTab("Spy Settings", 4483362458)

local Section = Tab:CreateSection("Main Configuration")

local EnabledToggle = Tab:CreateToggle({
   Name = "Enable Chat Spy",
   CurrentValue = true,
   Flag = "SpyEnabled",
   Callback = function(Value)
      Config.enabled = Value
      updateStatusMessage()
   end,
})

local SelfSpyToggle = Tab:CreateToggle({
   Name = "Spy On Yourself",
   CurrentValue = true,
   Flag = "SpySelf",
   Callback = function(Value)
      Config.spyOnMyself = Value
   end,
})

local PublicToggle = Tab:CreateToggle({
   Name = "Public Mode",
   CurrentValue = false,
   Flag = "PublicMode",
   Callback = function(Value)
      Config.public = Value
   end,
})

local ItalicsToggle = Tab:CreateToggle({
   Name = "Public Italics",
   CurrentValue = true,
   Flag = "PublicItalics",
   Callback = function(Value)
      Config.publicItalics = Value
   end,
})

local Section2 = Tab:CreateSection("Appearance")

local ColorPicker = Tab:CreateColorPicker({
   Name = "Spy Message Color",
   Color = Color3.fromRGB(0, 255, 255),
   Flag = "MessageColor",
   Callback = function(Value)
      PrivateProperties.Color = Value
   end
})

local Dropdown = Tab:CreateDropdown({
   Name = "Font Style",
   Options = {"SourceSansBold", "SourceSans", "Code", "Highway", "SciFi"},
   CurrentOption = "SourceSansBold",
   Flag = "FontStyle",
   Callback = function(Option)
      PrivateProperties.Font = Enum.Font[Option]
   end,
})

local Slider = Tab:CreateSlider({
   Name = "Text Size",
   Range = {12, 24},
   Increment = 1,
   Suffix = "px",
   CurrentValue = 18,
   Flag = "TextSize",
   Callback = function(Value)
      PrivateProperties.TextSize = Value
   end,
})

local Section3 = Tab:CreateSection("Actions")

local Button = Tab:CreateButton({
   Name = "Refresh Spy System",
   Callback = function()
      restartSpySystem()
   end,
})

local Button2 = Tab:CreateButton({
   Name = "Test Spy Message",
   Callback = function()
      testSpyMessage()
   end,
})

-- Configuration
local Config = {
   enabled = true,
   spyOnMyself = true,
   public = false,
   publicItalics = true
}

-- Message Properties
local PrivateProperties = {
   Color = Color3.fromRGB(0, 255, 255),
   Font = Enum.Font.SourceSansBold,
   TextSize = 18
}

-- Services
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

-- Variables
local player = Players.LocalPlayer
local saymsg = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest")
local getmsg = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("OnMessageDoneFiltering")
local instance = (_G.chatSpyInstance or 0) + 1
local activeConnections = {}

-- Initialize
_G.chatSpyInstance = instance

-- Functions
local function updateStatusMessage()
   local status = Config.enabled and "ENABLED" or "DISABLED"
   PrivateProperties.Text = "{SPY "..status.."}"
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
   -- Clean up existing connections
   for _, conn in pairs(activeConnections) do
      if conn then
         conn:Disconnect()
      end
   end
   activeConnections = {}
   
   -- Reinitialize
   _G.chatSpyInstance = _G.chatSpyInstance + 1
   instance = _G.chatSpyInstance
   
   -- Reconnect to all players
   for _, p in ipairs(Players:GetPlayers()) do
      if p ~= player then
         local conn = p.Chatted:Connect(function(msg)
            onChatted(p, msg)
         end)
         table.insert(activeConnections, conn)
      end
   end
   
   safeSetCore("{SPY SYSTEM RESTARTED}")
end

local function testSpyMessage()
   safeSetCore("{SPY TEST} This is a test message from the spy system")
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
   
   -- Wait for message to be processed
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
   -- Check if this instance is still active
   if _G.chatSpyInstance ~= instance then return end
   
   -- Handle spy command
   if p == player and msg:lower():sub(1,4) == "/spy" then
      Config.enabled = not Config.enabled
      EnabledToggle:Set(Config.enabled)
      task.wait(0.3)
      updateStatusMessage()
      return
   end
   
   -- Process spy functionality
   if Config.enabled and (Config.spyOnMyself or p ~= player) then
      -- Clean the message
      local cleanMsg = msg:gsub("[\n\r]", ''):gsub("\t", ' '):gsub("%s+", ' '):gsub("^%s+", ""):gsub("%s+$", "")
      
      -- Skip empty messages
      if cleanMsg == "" then return end
      
      -- Check if message is filtered (not shown in public chat)
      if isMessageFiltered(p, cleanMsg) then
         if Config.public then
            local spyMsg = (Config.publicItalics and "/me " or '') .. "{SPY} [" .. p.Name .. "]: " .. cleanMsg
            pcall(function()
               saymsg:FireServer(spyMsg, "All")
            end)
         else
            safeSetCore("{SPY} [" .. p.Name .. "]: " .. cleanMsg)
         end
      end
   end
end

-- Setup player connections
local function setupPlayer(p)
   if p == player then return end
   
   local conn = p.Chatted:Connect(function(msg)
      onChatted(p, msg)
   end)
   table.insert(activeConnections, conn)
end

-- Initialize connections for existing players
for _, p in ipairs(Players:GetPlayers()) do
   setupPlayer(p)
end

-- Handle new players
local playerAddedConn
playerAddedConn = Players.PlayerAdded:Connect(function(p)
   setupPlayer(p)
end)
table.insert(activeConnections, playerAddedConn)

-- Handle player leaving
local playerRemovingConn
playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
   -- Clean up any connections related to this player
   for i, conn in ipairs(activeConnections) do
      if not conn.Connected then
         table.remove(activeConnections, i)
         break
      end
   end
end)
table.insert(activeConnections, playerRemovingConn)

-- Adjust chat UI safely
pcall(function()
   local success, chatFrame = pcall(function()
      return player.PlayerGui:WaitForChild("Chat", 10).Frame
   end)
   
   if success and chatFrame then
      chatFrame.ChatChannelParentFrame.Visible = true
      chatFrame.ChatBarParentFrame.Position = chatFrame.ChatChannelParentFrame.Position + UDim2.new(UDim.new(), chatFrame.ChatChannelParentFrame.Size.Y)
   end
end)

-- Initial status message
updateStatusMessage()

Rayfield:LoadConfiguration()

-- Cleanup when script is destroyed
local function cleanup()
   for _, conn in pairs(activeConnections) do
      if conn then
         conn:Disconnect()
      end
   end
   activeConnections = {}
end

-- Auto cleanup
game:GetService("UserInputService").WindowFocused:Connect(function()
   if _G.chatSpyInstance ~= instance then
      cleanup()
   end
end)

print("-- Enhanced Chat Spy Loaded --")
print("Type \"/spy\" in chat or use the Rayfield UI to control the spy")
print("Features: Color customization, font settings, public/private modes")
