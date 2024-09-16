--!strict

----- Services -----

local Players = game:GetService("Players")

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local Net = require(Resources.RbxUtil.Net)
local Ragdoll = require(script.Parent)

local Remote = Net:RemoteEvent("Ragdoll")

----- Code -----

--Player Added
local function PlayerAdded(Player: Player): ()

	--Build Ragdoll
	local PlayerRagdoll = Ragdoll.new(Player)

	--Trigger on client's request
	Remote.OnServerEvent:Connect(function(Plr: Player)
		if Plr == Player then
			if PlayerRagdoll.State == "Inactive" then --Ragdoll
				PlayerRagdoll:Ragdoll()
			else --Unragdoll
				PlayerRagdoll:Unragdoll()
			end
		end
	end)

	--Let client know if ragdoll changes state
	PlayerRagdoll.StateChanged:Connect(function(Player: Player, State: Ragdoll.RagdollStates)
		Remote:FireClient(Player, State)
	end)
end
Players.PlayerAdded:Connect(PlayerAdded)