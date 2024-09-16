--!strict

----- Services -----

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")
local Goodies = Shared:WaitForChild("Goodies")

local Database = require(script.Parent)
local ProfileService = require(Resources.ProfileService)
local TableChanged = require(Goodies.Utils.TableChanged.Server)

----- Code -----

--- Setup ---

--Setup ProfileStore
local ProfileStore: Database.ProfileStore = ProfileService.GetProfileStore(
	Database.Name,
	Database.Template
)
Database.ProfileStore = ProfileStore

--Ignore progression during studio sessions
if RunService:IsStudio() and not Database.SaveOnPlaytests then
	ProfileStore = ProfileStore.Mock
end

--- Player Added ---

local function PlayerAdded(Player: Player): ()
	
	--Setup
	local Profile = ProfileStore:LoadProfileAsync(Database.ProfileName..Player.UserId)
	if Profile then --Loaded Sucessfully
		
		--GDPR compliance
		Profile:AddUserId(Player.UserId)
		
		--Fill in missing variables from Template
		Profile:Reconcile()
		
		--Data Released
		Profile:ListenToRelease(function()
			Database.Profiles[Player] = nil --Remove Profile
			TableChanged:Disconnect(Player, Profile.Data) --Disconnect
			Player:Kick() --The profile could've been loaded on another Roblox server
		end)
		
		--Data Loaded
		if Player:IsDescendantOf(Players) then
			Database.Profiles[Player] = Profile --Add Profile
			TableChanged:Connect(Player, Profile.Data, Database.DataChanged, 0.5) --Connect
			Database.DataLoaded:Fire(Player, Profile.Data) --Loaded Event
				
		--Player left before their data was loaded
		else
			Profile:Release()
		end
		
	else --Failed to Load
		Player:Kick("We couldn't load your data, please try rejoining and report this if the issue persists.")
	end
end
Players.PlayerAdded:Connect(PlayerAdded)

--In case Players have joined the server earlier than this script ran
for _, Player: Player in Players:GetPlayers() do
	task.spawn(PlayerAdded, Player)
end

--- Player Removing ---

local function PlayerRemoving(Player: Player): ()
	local Profile = Database.Profiles[Player]
	if Profile then
		Profile:Release()
	end
end
Players.PlayerRemoving:Connect(PlayerRemoving)