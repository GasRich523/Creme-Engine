--!strict

----- Services -----

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

----- Code -----

--Setup collision groups
PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

--PlayerAdded
local function PlayerAdded(Player: Player): ()
	Player.CharacterAdded:Connect(function(Character: Model)
		for _, Char in Character:GetDescendants() do
			if Char:IsA("BasePart") then
				Char.CollisionGroup = "Players"
			end
		end
	end)
end
Players.PlayerAdded:Connect(PlayerAdded)
for _, Player: Player in Players:GetPlayers() do
	PlayerAdded(Player)
end