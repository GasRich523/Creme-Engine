--strict

--[[
Game's server-side collectible system.

Should work with additional collectibles/data as long as you add them to the data template
following it's structure.

Example:
Bucks have the currency type, which means they are generated dynamically as picked inside
Data.Collectibles in their respective level, using their rounded CFrame as identifier (they
require a counter and cooldown so they can be picked up again). On the other side, Crusts/Brews
are staticly written inside the database's template, and in the case of brews contain information
inside the database.

So yeah, you get it, to modify or add more collectibles just follow the template and provide the
folders/assets/UI required (make sure to edit the types to fit as well), once that's done
you're all set.
--]]

----- Service -----

local Players = game:GetService("Players")

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Server = Code:WaitForChild("Server")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local GameplayFolder = workspace:WaitForChild("Gameplay")
local CollectiblesFolder = GameplayFolder:WaitForChild("Collectibles")

local Database = require(Server.Database)
local Net = require(Resources.RbxUtil.Net)

local Remote = Net:RemoteEvent("Collectibles")

local CollectCooldown: number = 0.1
local WipeCooldown: number = 10
local CollectOnCooldown: boolean = false
local WipeOnCooldown: boolean = false

----- Code -----

--- CFrame Formatting ---

--[[
Converts CFrames to Strings and Rounds them to avoid floating point errors
--]]

local function FormatNumber(Num: number, DecimalPlaces: number): string
	local FormatString = string.format("%%.%df", DecimalPlaces)
	return string.format(FormatString, Num)
end

local function CFrameToString(CF: CFrame): string
	local DecimalPlaces: number = 3
	local Components = {CF:GetComponents()}
	for i, Component: number in ipairs(Components) do
		Components[i] = FormatNumber(Component, DecimalPlaces)
	end
	return table.concat(Components, ", ")
end

--- Find Level ---

--[[
Each level is attached to a PlaceId, this gets the level from that
--]]

local function FindLevel(PlaceId: number, Data: Database.Data): string?
	for Level: string, Place: number in pairs(Data.Places) do
		if PlaceId == Place then
			return Level
		end
	end
	return nil
end

--- Award Collectible ---

--[[
Awards or takes away collectible from the player
--]]

local function AwardCollectible(Player: Player, Give: boolean, Collectible: BasePart, Data: Database.Data): ()
	
	--Data
	local Level: string? = FindLevel(game.PlaceId, Data); assert(Level); assert(Collectible.Parent)
	local CollectibleData = not Data[Collectible.Parent.Name.."Count"] and Data.Collectibles[Level :: Database.PlaceNames][Collectible.Parent.Name][Collectible.Name] or Data.Collectibles[Level :: Database.PlaceNames][Collectible.Parent.Name][CFrameToString(Collectible.CFrame)]
	
	--Award
	if CollectibleData then
		CollectibleData.Obtained = Give
		CollectibleData.ObtainDate = Give and os.time() or nil
	end
	
	--Counter
	if Data[Collectible.Parent.Name.."Count"] then
		Data[Collectible.Parent.Name.."Count"] += 1
	end
	
	--Leaderboard Count
	local Leaderstats: Folder? = Player:FindFirstChild("leaderstats") :: Folder
	local Value: IntValue? = Leaderstats and Leaderstats:FindFirstChild(Collectible.Parent.Name) :: IntValue
	if Value then
		Value.Value += 1
	end
end

--- Setup Leaderstats ---

--[[
Sets up the collectible's leaderstats
--]]

local function SetupLeaderstats(Player: Player, Data: Database.Data): ()
	
	--Setup Leaderstats
	local Leaderstats = Instance.new("Folder")
	Leaderstats.Name = "leaderstats"
	Leaderstats.Parent = Player
	
	--Store Collectibles for Remote
	local Stored = {
		Enable = {} :: {BasePart?},
		Disable = {} :: {BasePart?}
	}
	
	--Setup Leaderstat values
	for _, CollectibleType: Folder in CollectiblesFolder:GetChildren() :: {any} do
		
		--IntValue
		local Value: IntValue = Instance.new("IntValue")
		Value.Name = CollectibleType.Name
		Value.Parent = Leaderstats
		
		--If this is a currency, use the stored Count
		local Count: number? = Data[CollectibleType.Name.."Count"]
		if Count then
			Value.Value = Count

			--Look for Cooldowns
			local Level = FindLevel(game.PlaceId, Data)
			local Type: {[string]: Database.Currency} = Data.Collectibles[Level][CollectibleType.Name]

			--Look for Stored & Non-Stored Currency
			for _, Collectible: BasePart in CollectibleType:GetChildren() :: any do

				--Stored
				local CollectibleData = Type[CFrameToString(Collectible.CFrame)]
				if CollectibleData and CollectibleData.Obtained then

					--If cooldown ended
					if CollectibleData.ObtainDate and (os.time() - CollectibleData.ObtainDate >= Data.BucksCooldown) then
						CollectibleData.Obtained = false
						CollectibleData.ObtainDate = nil
						table.insert(Stored.Enable, Collectible)
						
					else --If cooldown isn't over
						CollectibleData.ObtainDate = CollectibleData.ObtainDate or os.time() --If the date didn't save for some reason
						table.insert(Stored.Disable, Collectible)
					end

				else --Non-Stored/Uncollected, Enable
					table.insert(Stored.Enable, Collectible)
				end
			end
		else --Otherwise, get obtained collectibles dynamically
			for Level: string, _ in Data.Collectibles :: any do
				local Type: {[string]: Database.Secondary} = Data.Collectibles[Level :: Database.PlaceNames][CollectibleType.Name]
				for CollectibleName: string, CollectibleData: Database.Secondary in Type do
					local Collectible = CollectibleType:FindFirstChild(CollectibleName) :: BasePart
					if CollectibleData.Obtained then --Obtained
						
						--Raise Count
						Value.Value += 1
						
						--Disable
						table.insert(Stored.Disable, Collectible)
					else --Not obtained
						
						--Enable
						table.insert(Stored.Enable, Collectible)
					end
				end
			end 
		end
	end
	
	--Tell Client to Enable/Disable collectibles
	Remote:FireClient(Player, "Collected", false, Stored)
end

--- Setup Collectibles ---

--[[
Handles the collectibles
--]]

local function SetupCollectibles(Player: Player, Container: Folder, Data: Database.Data): ()
	for _, Collectible: Instance in Container:GetChildren() do
		if Collectible:IsA("BasePart") then
			
			--Data
			local Level: string? = FindLevel(game.PlaceId, Data); assert(Level)
			local CollectibleData: Database.Secondary = Data.Collectibles[Level :: Database.PlaceNames][Container.Name][Collectible.Name]
			
			--Create Data if not existent (currency)
			if (not CollectibleData) and (Data and Data[Container.Name.."Count"]) then --Right way to do this would be to compare the type, but of course roblox doesn't support custom type comparisions
				if not Data.Collectibles[Level :: Database.PlaceNames][Container.Name][CFrameToString(Collectible.CFrame)] then
					Data.Collectibles[Level :: Database.PlaceNames][Container.Name][CFrameToString(Collectible.CFrame)] = {Obtained = false, ObtainDate = nil} :: Database.Currency
				end
				CollectibleData = Data.Collectibles[Level :: Database.PlaceNames][Container.Name][CFrameToString(Collectible.CFrame)]
			end
			
			--Touched
			local function Touched(Hit: BasePart)
				if Player.Character and Hit.Parent == Player.Character and not CollectibleData.Obtained and not CollectOnCooldown then
					CollectOnCooldown = true					

					--Award
					AwardCollectible(Player, true, Collectible, Data)
					
					--Tell Client
					Remote:FireClient(Player, "Collected", true, Collectible, CollectibleData)
					
					--Cooldown
					task.delay(CollectCooldown, function(): ()
						CollectOnCooldown = false
					end)
				end
			end
			Collectible.Touched:Connect(Touched) --It's not that hard to support models but it'd make the effect code messy
		end
	end
end

--- Wipe Data ---

--[[
Player requested their data to be reset
]]--

local function WipeData(Player: Player, Data: Database.Data): ()
	if not WipeOnCooldown then
		WipeOnCooldown = true
		
		--Wipe
		local ProfileStore: Database.ProfileStore? = Database:GetProfileStore()
		if ProfileStore then
			ProfileStore:WipeProfileAsync(Database.ProfileName..Player.UserId)
		else
			warn("Couldn't erase "..Player.DisplayName.."'s data, their profile wasn't found.")
		end
		
		--Cooldown
		task.delay(WipeCooldown, function(): ()
			WipeOnCooldown = false
		end)
	end
end

--- Data Loaded ---

--[[
Waits for player's data to load
--]]

local function DataLoaded(Player: Player, Data: Database.Data): ()
	
	--Prevents errors on unpublished places
	local Level = FindLevel(game.PlaceId, Data)
	if not Level then
		warn("Level not found in the database, make sure you are working with a pulished place!")
		return
	end

	--Setup Leaderstats
	SetupLeaderstats(Player, Data)
	
	--Setup Collectibles
	for _, Collectible: Folder in CollectiblesFolder:GetChildren() do
		SetupCollectibles(Player, Collectible, Data)
	end
	
	--Remote
	Remote.OnServerEvent:Connect(function(PassedPlayer: Player, Command: string, ...): ()
		if Player == PassedPlayer then --If it's the same player
			
			--Wipe Data
			if Command == "WipeData" then
				WipeData(Player, Data)
			end
		end
	end)
end

--- Player Added ---

--[[
Self Explanatory
--]]

local function PlayerAdded(Player: Player): ()
	
	--Data Loaded
	local Data: Database.Data? = Database:GetData(Player)
	if Data then
		DataLoaded(Player, Data)
	else
		Database.DataLoaded:Once(function(Plr: Player, Data: Database.Data)
			if Plr == Player then
				DataLoaded(Player, Data)
			end
		end)
	end
end
Players.PlayerAdded:Connect(PlayerAdded)