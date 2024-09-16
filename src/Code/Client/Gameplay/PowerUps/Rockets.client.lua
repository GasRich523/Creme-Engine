--!strict

----- Services -----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local RootPart = Humanoid.RootPart :: BasePart

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets.Sounds
local Effects = Assets.Effects

local GameplayFolder = workspace:WaitForChild("Gameplay")
local PowerUpsFolder = GameplayFolder:WaitForChild("PowerUps")
local RocketsFolder = PowerUpsFolder:WaitForChild("Rockets")

local PowerUps = require(script.Parent)

local Effect: BasePart
local Force: Attachment
local Run: RBXScriptConnection

----- Code -----

--- Setup ---

local RocketsPowerup = PowerUps.new(Player, {
	Type = "Rockets",
	Icon = "rbxassetid://15397348565",
	Container = RocketsFolder,
	Duration = 12
})

--- Toggled ---

local function StateChanged(State: PowerUps.PowerupStates, RocketModel: Instance): ()
	
	--Attributes
	local PowerupDuration = RocketModel:GetAttribute("PowerupDuration") or 1
	local Power = RocketModel:GetAttribute("Power") or 30
	
	--Inactive
	if State ~= "Active" then
		
		--Completed
		if State == "Completed" then
			
			--Sound
			Sounds.PowerUps.Rocket:Play()
			
			--Effect
			if Effect then Effect:Destroy() end
			Effect = Effects.PowerUps.Fire:Clone(); Effect.Parent = RootPart; Effect.CFrame = RootPart.CFrame
			local M6D = Instance.new("Motor6D"); M6D.Parent = Effect; M6D.Part0 = Effect; M6D.Part1 = RootPart
			M6D.C1 = (M6D.C1 - Vector3.new(0, RootPart.Size.Y, 0)) * CFrame.Angles(0, 0, math.rad(180))
			
			--Trigger Rocket
			if Force then Force:Destroy() end
			Force = Instance.new("Attachment"); Force.Parent = RootPart; Force.Name = "RocketForce"
			local F = Instance.new("LinearVelocity"); F.Parent = Force; F.Attachment0 = Force; F.MaxForce = math.huge
			F.RelativeTo = Enum.ActuatorRelativeTo.World; F.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			
			--Update Velocity
			if Run then Run:Disconnect() end
			Run = RunService.PostSimulation:Connect(function()
				F.VectorVelocity = (Humanoid.MoveDirection * Vector3.new(1, 0, 1)) * Humanoid.WalkSpeed + Vector3.new(0, Power, 0)
			end)
			
			--End Rocket
			task.delay(PowerupDuration, function()
				RocketsPowerup:Trigger(false, RocketModel)
			end)
			
		else
			
			--Cleanup
			if Run then Run:Disconnect() end
			if Force then Force:Destroy() end
			if Effect then Effect:Destroy() end
			Sounds.PowerUps["Rocket"]:Stop()
		end
	end
end
RocketsPowerup.StateChanged:Connect(StateChanged)

--- Respawned ---

local function Respawned(newChar: Model): ()
	Character = newChar
	Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	RootPart = Humanoid.RootPart :: BasePart
end
Player.CharacterAdded:Connect(Respawned)