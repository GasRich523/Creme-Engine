--Cleanup pending

--[[
Note:
Remember to enable the initial Spawn so it doesn't snap on join.
--]]

----- Services -----

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")

local GameplayFolder = workspace:WaitForChild("Gameplay")
local Checkpoints = GameplayFolder:WaitForChild("Checkpoints")
local InitialSpawn = Checkpoints:WaitForChild("Spawn")
local RespawnLocation = InitialSpawn

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")

local CheckpointSound = Sounds.Other:WaitForChild("Checkpoint")

local EnabledSize = Vector3.new(0.2, 7, 7)
local DisabledSize = Vector3.new(0.2, 5, 5)
local Range = 15
local OnRange = false
local LastCheckpoint = RespawnLocation
local CheckpointTweenIn = nil
local CheckpointTweenIn2 = nil
local CheckpointTweenOut = nil
local CheckpointTweenOut2 = nil

----- Code -----

--Spawn on join
if (not RunService:IsStudio()) or ((RootPart.Position - InitialSpawn.Position).Magnitude < 15) then --Avoids messing up with the "Play Here" feature
	local FixedCFrame = CFrame.new(RespawnLocation.Position + Vector3.new(0, 5, 0), RespawnLocation.CFrame.LookVector)
	Character:PivotTo(FixedCFrame)
end

-- Checkpoints --

--Checkpoint Behaviour
for _, Checkpoint in Checkpoints:GetDescendants() do
	if Checkpoint:IsA("SpawnLocation") then
		
		--Vars
		local Texture = Checkpoint:WaitForChild("SpawnTexture")
		Checkpoint.Enabled = false
		Checkpoint.Size = if Checkpoint == RespawnLocation then EnabledSize else DisabledSize
		
		--Initial Appearence
		if Checkpoint.Name == "Spawn" then
			Texture.Color3 = Color3.fromRGB(255, 255, 255)
			Checkpoint.Size = EnabledSize
			
		else
			Texture.Color3 = Color3.fromRGB(0, 0, 0)
			Checkpoint.Size = DisabledSize
		end
		
		-- On Range --
		
		--Entered checkpoint range
		RunService.Heartbeat:Connect(function()
			if not OnRange and Checkpoint ~= RespawnLocation and (Checkpoint.Position - RootPart.Position).Magnitude <= Range then
				OnRange = true --Debounce
				RespawnLocation = Checkpoint --Update checkpoint
				
				--In Effect
				if CheckpointTweenIn then CheckpointTweenIn:Pause(); CheckpointTweenIn:Destroy() end
				if CheckpointTweenIn2 then CheckpointTweenIn2:Pause(); CheckpointTweenIn2:Destroy() end
				CheckpointTweenIn = TweenService:Create(Texture, TweenInfo.new(0.8), {Color3 = Color3.fromRGB(255, 255, 255)})
				CheckpointTweenIn2 = TweenService:Create(Checkpoint, TweenInfo.new(0.8), {Size = EnabledSize})
				CheckpointTweenIn:Play()
				CheckpointTweenIn2:Play()
				
				--Out Effect
				local LastTexture = LastCheckpoint:WaitForChild("SpawnTexture")
				if CheckpointTweenOut then CheckpointTweenOut:Pause(); CheckpointTweenOut:Destroy() end
				if CheckpointTweenOut2 then CheckpointTweenOut2:Pause(); CheckpointTweenOut2:Destroy() end
				CheckpointTweenOut = TweenService:Create(LastTexture, TweenInfo.new(0.5), {Color3 = Color3.fromRGB(0, 0, 0)})
				CheckpointTweenOut2 = TweenService:Create(LastCheckpoint, TweenInfo.new(0.5), {Size = DisabledSize})
				CheckpointTweenOut:Play()
				CheckpointTweenOut2:Play()
				
				CheckpointSound:Play() --Sound
				LastCheckpoint = RespawnLocation --Update last checkpoint
				
			--Left checkpoint range
			elseif OnRange and Checkpoint == LastCheckpoint and (Checkpoint.Position - RootPart.Position).Magnitude <= Range then
				OnRange = false --Confirm we left the range of the checkpoint
			end
		end)
	end
end

-- Respawning --

local function Respawned(UpdateChar)
	Character = UpdateChar
	RootPart = Character:WaitForChild("HumanoidRootPart")
	
	--Respawn
	local FixedCFrame = CFrame.new(RespawnLocation.Position + Vector3.new(0, 5, 0), RespawnLocation.CFrame.LookVector)
	Character:PivotTo(FixedCFrame)
end
Player.CharacterAdded:Connect(Respawned)